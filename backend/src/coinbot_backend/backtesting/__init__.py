"""Backtesting module for evaluating trading strategies on historical data."""

from coinbot_backend.backtesting.engine import BacktestEngine
from coinbot_backend.backtesting.models import (
    BacktestMetrics,
    BacktestPosition,
    BacktestResults,
    BacktestSignal,
    BacktestTrade,
)
from coinbot_backend.backtesting.plot import plot_backtesting_results

__all__ = [
    "BacktestEngine",
    "BacktestSignal",
    "BacktestTrade",
    "BacktestPosition",
    "BacktestMetrics",
    "BacktestResults",
    "plot_backtesting_results",
]
