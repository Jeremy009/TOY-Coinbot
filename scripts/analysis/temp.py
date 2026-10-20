import random

from coinbot import BITVAVO
from coinbot.backend.clients import BitvavoClient
from coinbot.backend.indicators import macd_indicator, macd_indicator
from coinbot.backend.signals import macd_signal, TradebotAction
VERBOSE = True


def get_sorted_symbols(bitvavo_client: BitvavoClient):
    # Get all symbols that are being traded on the exchange
    all_symbols = bitvavo_client.get_available_symbols()
    # random.shuffle(all_symbols)
    # all_symbols = all_symbols[:50]
    bc_str = "removed from consideration because"

    # Determine strength metrics
    volumes = []
    for symbol in all_symbols:
        try:
            candles = bitvavo_client.get_candles(symbol, time_resolution="1d", time_span="1d")
            volume_24_h = candles.volumes[-1]
            volumes.append(volume_24_h)
            print(symbol, volume_24_h)
        except:
            pass
    import matplotlib.pyplot as plt
    plt.hist(volumes)
    plt.show()



if __name__ == "__main__":
    # Set up the Bitvavo client
    bitvavo_client = BitvavoClient(BITVAVO)

    # Get all sorted symbols
    sorted_symbols = get_sorted_symbols(bitvavo_client)
