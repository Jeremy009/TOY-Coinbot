""" Regenerates docs/images/main-window.png.

Opens the main window with a fake exchange client that serves fictional data, so no Bitvavo account or network
connection is needed, and saves a screenshot of the window. Run it from the repository root:

    python tools/screenshots/take_screenshot.py
"""
import sys
from pathlib import Path
from types import SimpleNamespace

import numpy as np
from PyQt5 import QtCore
from PyQt5.QtCore import QThreadPool, QTimer
from PyQt5.QtWidgets import QApplication

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from coinbot import TIME_RESOLUTIONS, TIME_SPANS  # noqa: E402
from coinbot.frontend.controller import CoinbotController  # noqa: E402
from coinbot.frontend.stylesheet import STYLE_SHEET  # noqa: E402
from coinbot.frontend.view import CoinbotView  # noqa: E402

# Symbol: (price in EUR, amount owned, 24h change in percent)
HOLDINGS = {
    "BTC": (32_410.55, 0.0421, 2.31),
    "ETH": (1_745.20, 0.85, -1.12),
    "SOL": (38.74, 12.5, 4.87),
    "ADA": (0.3214, 1800.0, -0.64),
    "LINK": (12.52, 40.0, 1.95),
}


class FakeBitvavoClient:
    """ Answers the calls the controller makes with fictional data. """

    available_symbols = sorted(["EUR", "XRP", "DOT", "DOGE", "AVAX", *HOLDINGS])

    def get_remaining_limit(self):
        return 1000

    def get_available_symbols(self):
        return list(self.available_symbols)

    def get_available_funds(self):
        return 1250.37

    def get_total_wallet_balance(self):
        return self.get_available_funds() + sum(p * a for p, a, _ in HOLDINGS.values())

    def get_total_deposited(self):
        return 4500.00

    def get_total_withdrawn(self):
        return 250.00

    def get_total_gains(self):
        return self.get_total_wallet_balance() + self.get_total_withdrawn() - self.get_total_deposited()

    def get_owned_symbols(self):
        return ["EUR", *HOLDINGS]

    def get_symbol_price(self, symbol):
        return HOLDINGS[symbol][0]

    def get_symbol_owned_amount(self, symbol):
        return HOLDINGS[symbol][1]

    def get_symbol_24h_percentual_change(self, symbol):
        return HOLDINGS[symbol][2]

    def get_candles(self, symbol, time_resolution, time_span):
        num_candles = max(TIME_SPANS[time_span] // TIME_RESOLUTIONS[time_resolution], 2)
        rng = np.random.default_rng(7)
        walk = np.exp(np.cumsum(rng.normal(0.0015, 0.012, num_candles)))
        closes = HOLDINGS.get(symbol, (100.0,))[0] * walk / walk[-1]  # end at the current price
        times = np.arange(num_candles) * TIME_RESOLUTIONS[time_resolution] * 1000
        return SimpleNamespace(timestamps=list(times), high_positions=list(closes * 1.004),
                               low_positions=list(closes * 0.996), close_positions=list(closes))


if __name__ == "__main__":
    QApplication.setAttribute(QtCore.Qt.AA_EnableHighDpiScaling, True)
    QApplication.setAttribute(QtCore.Qt.AA_UseHighDpiPixmaps, True)
    app = QApplication([])
    app.setStyleSheet(STYLE_SHEET)

    controller = CoinbotController(FakeBitvavoClient())
    view = CoinbotView(controller=controller)
    controller.main_view = view.main_widget
    controller.configure_main_view()
    selectors = view.main_widget
    selectors.price_symbol_selector.setCurrentText("BTC")
    selectors.price_resolution_selector.setCurrentText("4h")
    selectors.price_period_selector.setCurrentText("2m")
    controller.update_main_view()
    view.show()

    def save():
        QThreadPool.globalInstance().waitForDone()
        app.processEvents()
        out = ROOT / "docs" / "images" / "main-window.png"
        view.grab().save(str(out))
        print(f"Saved {out}")
        app.quit()

    QTimer.singleShot(3000, save)
    app.exec()
