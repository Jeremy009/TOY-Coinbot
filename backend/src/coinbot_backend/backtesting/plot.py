"""
Backtesting Results Visualization

Creates comprehensive charts showing backtest results with:
- Background shading for signals (green=BUY, red=SELL, blue=HOLD)
- Trade lines connecting entry to exit points (green=profit, red=loss)
- All technical indicators (candlesticks, EMAs, Bollinger, RSI, MACD, volume)
- Performance metrics panel
"""

import io
from datetime import datetime
from typing import Optional

import matplotlib
import numpy as np
import pandas as pd

matplotlib.use("Agg")

import matplotlib.pyplot as plt
from matplotlib.figure import Figure

from coinbot_backend.backtesting.models import BacktestResults
from coinbot_backend.models.candles import OHLCVCandles
from coinbot_backend.models.trading import Signal
from coinbot_backend.services.technical_analysis_plot import (
    _format_time_axis,
    _plot_candlesticks_with_indicators,
    _plot_macd,
    _plot_rsi,
    _plot_volume,
)
from coinbot_backend.services.trading_strategies import (
    calculate_bollinger_bands,
    calculate_ema,
    calculate_macd,
    calculate_rsi,
)


def plot_backtesting_results(
    candles: OHLCVCandles,
    results: BacktestResults,
    show: bool = False,
    save_path: Optional[str] = None,
    return_bytes: bool = False,
    figsize: tuple[float, float] = (16 * 5, 10 * 5),
    skip_first_n_candles: int = 200,
) -> Figure | bytes:
    """
    Create comprehensive backtesting results chart with signal shading and trade lines.

    Visual elements:
    - Background shading: green (BUY), red (SELL), blue (HOLD)
    - Trade lines: green if profitable, red if loss
    - Technical indicators: candlesticks, EMAs, Bollinger, RSI, MACD, volume
    - Metrics panel in title
    """
    # Extract data
    df = candles.as_dataframe()
    symbol = results.symbol

    # Calculate all indicators
    close_prices = df["close"].to_numpy()
    high_prices = df["high"].to_numpy()
    low_prices = df["low"].to_numpy()

    # EMAs for price chart
    ema_12 = calculate_ema(close_prices, 12)
    ema_50 = calculate_ema(close_prices, 50)
    ema_200 = calculate_ema(close_prices, 200)

    # Bollinger Bands
    bb_upper, bb_middle, bb_lower = calculate_bollinger_bands(close_prices, 20, 2.0)

    # RSI
    rsi = calculate_rsi(close_prices, 14)

    # MACD
    macd_line, macd_signal, macd_histogram = calculate_macd(close_prices, 12, 26, 9)

    # Create title with metrics
    m = results.metrics
    title = (
        f"{symbol} - Backtest Results | {results.time_span} @ {results.time_resolution}\n"
        f"P/L: €{m.total_profit_loss:+,.2f} ({m.total_profit_loss_pct:+.1f}%) | "
        f"Trades: {m.num_trades} | Win Rate: {m.win_rate * 100:.1f}% | "
        f"Max DD: {m.max_drawdown:.1f}%"
    )

    # Skip first N candles for plotting
    if skip_first_n_candles > 0 and len(df) > skip_first_n_candles:
        df_plot = df.iloc[skip_first_n_candles:].copy()
        df_plot.reset_index(drop=True, inplace=True)

        # Slice all indicator arrays
        ema_12_plot = ema_12[skip_first_n_candles:]
        ema_50_plot = ema_50[skip_first_n_candles:]
        ema_200_plot = ema_200[skip_first_n_candles:]
        bb_upper_plot = bb_upper[skip_first_n_candles:]
        bb_middle_plot = bb_middle[skip_first_n_candles:]
        bb_lower_plot = bb_lower[skip_first_n_candles:]
        rsi_plot = rsi[skip_first_n_candles:]
        macd_line_plot = macd_line[skip_first_n_candles:]
        macd_signal_plot = macd_signal[skip_first_n_candles:]
        macd_histogram_plot = macd_histogram[skip_first_n_candles:]

        skip_offset = skip_first_n_candles
    else:
        df_plot = df
        ema_12_plot = ema_12
        ema_50_plot = ema_50
        ema_200_plot = ema_200
        bb_upper_plot = bb_upper
        bb_middle_plot = bb_middle
        bb_lower_plot = bb_lower
        rsi_plot = rsi
        macd_line_plot = macd_line
        macd_signal_plot = macd_signal
        macd_histogram_plot = macd_histogram
        skip_offset = 0

    # Create figure with subplots
    fig = plt.figure(figsize=figsize, constrained_layout=True)
    fig.suptitle(title, fontsize=14, fontweight="bold")

    # Create grid for subplots (4 rows)
    gs = fig.add_gridspec(4, 1, height_ratios=[3, 1, 1, 1], hspace=0.3)

    # 1. CANDLESTICK CHART with EMAs, Bollinger, signals, and trades
    ax1 = fig.add_subplot(gs[0])
    _plot_candlesticks_with_indicators(
        ax1, df_plot, ema_12_plot, ema_50_plot, ema_200_plot, bb_upper_plot, bb_middle_plot, bb_lower_plot
    )

    # Add signal shading to price chart
    _add_signal_shading(ax1, candles, results.signals, skip_offset)

    # Add trade lines to price chart
    _plot_trade_lines(ax1, candles, results.trades, skip_offset)

    # Disable grid on price chart
    ax1.grid(False)

    # 2. RSI with signal shading
    ax2 = fig.add_subplot(gs[1], sharex=ax1)
    _plot_rsi(ax2, df_plot.index, rsi_plot)
    _add_signal_shading(ax2, candles, results.signals, skip_offset)
    ax2.grid(False)

    # 3. MACD with signal shading
    ax3 = fig.add_subplot(gs[2], sharex=ax1)
    _plot_macd(ax3, df_plot.index, macd_line_plot, macd_signal_plot, macd_histogram_plot)
    _add_signal_shading(ax3, candles, results.signals, skip_offset)
    ax3.grid(False)

    # 4. VOLUME with signal shading
    ax4 = fig.add_subplot(gs[3], sharex=ax1)
    _plot_volume(ax4, df_plot)
    _add_signal_shading(ax4, candles, results.signals, skip_offset)
    ax4.grid(False)

    # Format x-axis (only show on bottom subplot)
    plt.setp(ax1.get_xticklabels(), visible=False)
    plt.setp(ax2.get_xticklabels(), visible=False)
    plt.setp(ax3.get_xticklabels(), visible=False)

    # Add time labels to bottom subplot (month/year on first day of month)
    _format_backtesting_time_axis(ax4, candles, skip_offset)

    # Save or return bytes
    if return_bytes:
        buf = io.BytesIO()
        fig.savefig(buf, format="png", dpi=150, bbox_inches="tight")
        buf.seek(0)
        plt.close(fig)
        return buf.read()

    if save_path:
        fig.savefig(save_path, dpi=150, bbox_inches="tight")
        print(f"Chart saved to: {save_path}")

    if show:
        plt.show()

    if not return_bytes and not show:
        plt.close(fig)

    return fig


def _add_signal_shading(ax: plt.Axes, candles: OHLCVCandles, signals: list, skip_offset: int) -> None:
    """
    Add transparent background shading for signals.

    Green (alpha=0.1) for BUY/STRONG_BUY
    Red (alpha=0.1) for SELL/STRONG_SELL
    Blue (alpha=0.05) for HOLD
    """
    if not signals:
        return

    # Group consecutive signals of same type for efficient shading
    current_signal = None
    region_start = None

    for i, signal in enumerate(signals):
        # Find the candle index for this signal's datetime
        candle_idx = None
        for j, dt in enumerate(candles.timelabels):
            if isinstance(dt, datetime) and dt >= signal.datetime:
                candle_idx = j
                break

        if candle_idx is None:
            continue

        # Adjust for skipped candles
        plot_idx = candle_idx - skip_offset
        if plot_idx < 0:
            continue

        # Determine signal type category
        if signal.signal in [Signal.BUY, Signal.STRONG_BUY]:
            signal_type = "buy"
        elif signal.signal in [Signal.SELL, Signal.STRONG_SELL]:
            signal_type = "sell"
        else:
            signal_type = "hold"

        # Check if we're starting a new region
        if signal_type != current_signal:
            # Finish previous region if exists
            if current_signal is not None and region_start is not None:
                _shade_region(ax, region_start, plot_idx, current_signal)

            # Start new region
            current_signal = signal_type
            region_start = plot_idx

    # Finish final region
    if current_signal is not None and region_start is not None:
        # Use last plot index as end
        last_plot_idx = len(candles.timestamps) - skip_offset - 1
        _shade_region(ax, region_start, last_plot_idx, current_signal)


def _shade_region(ax: plt.Axes, start_idx: int, end_idx: int, signal_type: str) -> None:
    """Shade a region based on signal type."""
    if signal_type == "buy":
        ax.axvspan(start_idx, end_idx, color="green", alpha=0.1, zorder=0)
    elif signal_type == "sell":
        ax.axvspan(start_idx, end_idx, color="red", alpha=0.1, zorder=0)
    elif signal_type == "hold":
        ax.axvspan(start_idx, end_idx, color="blue", alpha=0.05, zorder=0)


def _plot_trade_lines(ax: plt.Axes, candles: OHLCVCandles, trades: list, skip_offset: int) -> None:
    """
    Plot lines connecting entry to exit for each trade.

    Green line if profitable, red if loss.
    Add P/L percentage annotation on the line.
    """
    if not trades:
        return

    for trade in trades:
        # Find candle indices for entry and exit
        entry_idx = None
        exit_idx = None

        for i, dt in enumerate(candles.timelabels):
            if isinstance(dt, datetime):
                if entry_idx is None and dt >= trade.entry_datetime:
                    entry_idx = i
                if exit_idx is None and dt >= trade.exit_datetime:
                    exit_idx = i
                    break

        if entry_idx is None or exit_idx is None:
            continue

        # Adjust for skipped candles
        entry_plot_idx = entry_idx - skip_offset
        exit_plot_idx = exit_idx - skip_offset

        # Skip if outside plotted range
        if entry_plot_idx < 0 or exit_plot_idx < 0:
            continue

        # Determine color based on profitability
        color = "green" if trade.profit_loss >= 0 else "red"

        # Plot line connecting entry price to exit price
        ax.plot(
            [entry_plot_idx, exit_plot_idx],
            [trade.entry_price, trade.exit_price],
            color=color,
            linewidth=2,
            alpha=0.6,
            zorder=10,
        )

        # Add entry and exit markers
        ax.scatter([entry_plot_idx], [trade.entry_price], color=color, marker="o", s=50, zorder=11, alpha=0.8)
        ax.scatter([exit_plot_idx], [trade.exit_price], color=color, marker="x", s=80, zorder=11, alpha=0.8)

        # Add P/L annotation at midpoint
        mid_idx = (entry_plot_idx + exit_plot_idx) / 2
        mid_price = (trade.entry_price + trade.exit_price) / 2
        annotation_y = mid_price * 1.02  # Slightly above midpoint

        # Only add annotation if there's enough space (trade duration > 10 candles)
        if exit_plot_idx - entry_plot_idx > 10:
            ax.annotate(
                f"{trade.profit_loss_pct:+.1f}%",
                xy=(mid_idx, annotation_y),
                fontsize=7,
                color=color,
                weight="bold",
                ha="center",
                bbox=dict(boxstyle="round,pad=0.3", facecolor="white", edgecolor=color, alpha=0.7),
                zorder=12,
            )


def _format_backtesting_time_axis(ax: plt.Axes, candles: OHLCVCandles, skip_offset: int = 0) -> None:
    """Format the x-axis with month/year labels only on the first day of each month."""
    # Find indices where it's the first day of a month
    label_indices = []
    label_values = []

    if hasattr(candles, "timelabels") and candles.timelabels:
        seen_months = set()
        for i, dt in enumerate(candles.timelabels):
            if isinstance(dt, datetime):
                # Create unique month identifier
                month_key = (dt.year, dt.month)
                # Only add label on first occurrence of each month
                if month_key not in seen_months and dt.day == 1:
                    seen_months.add(month_key)
                    # Adjust index for skipped candles
                    plot_index = i - skip_offset
                    if plot_index >= 0:  # Only include if within plotted range
                        label_indices.append(plot_index)
                        # Format as "MMM YYYY" (e.g., "Jan 2025")
                        label_values.append(dt.strftime("%b %Y"))

    # If no labels found or too few, fallback to evenly spaced labels
    if len(label_indices) < 3:
        num_plotted_candles = len(candles.timestamps) - skip_offset
        # Try to show about 10-15 labels
        mod = max(1, num_plotted_candles // 12)
        label_indices = [i for i in range(0, num_plotted_candles, mod)]
        label_values = []
        for i in label_indices:
            original_index = i + skip_offset
            if original_index < len(candles.timelabels):
                dt = candles.timelabels[original_index]
                if isinstance(dt, datetime):
                    label_values.append(dt.strftime("%b %Y"))
                else:
                    label_values.append(str(dt))

    ax.set_xticks(label_indices)
    ax.set_xticklabels(label_values, rotation=45, ha="right")
