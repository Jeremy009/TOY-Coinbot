"""Backtesting data models for strategy evaluation on historical data."""

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

from pydantic import BaseModel, Field

from coinbot_backend.models.trading import Signal


@dataclass
class BacktestSignal:
    """Signal generated during backtesting at a specific time."""

    datetime: datetime
    signal: Signal
    confidence: float
    reason: str
    price: float


@dataclass
class BacktestTrade:
    """Completed trade during backtesting."""

    entry_datetime: datetime
    exit_datetime: datetime
    entry_price: float
    exit_price: float
    amount: float
    entry_fee: float
    exit_fee: float
    total_cost: float
    total_received: float
    profit_loss: float
    profit_loss_pct: float
    hold_duration: timedelta
    entry_reason: str
    exit_reason: str
    max_price: float
    max_drawdown_pct: float


@dataclass
class BacktestPosition:
    """Currently open position during backtesting."""

    entry_datetime: datetime
    entry_price: float
    amount: float
    total_cost: float
    ath: float
    entry_reason: str


class BacktestMetrics(BaseModel):
    """Performance metrics from backtesting."""

    initial_balance: float = Field(..., description="Starting EUR balance")
    final_balance: float = Field(..., description="Ending EUR balance (including open position value)")
    total_profit_loss: float = Field(..., description="Total profit/loss in EUR")
    total_profit_loss_pct: float = Field(..., description="Total return percentage")
    num_trades: int = Field(..., description="Total number of completed trades")
    num_winning_trades: int = Field(..., description="Number of profitable trades")
    num_losing_trades: int = Field(..., description="Number of losing trades")
    win_rate: float = Field(..., description="Percentage of winning trades (0.0 to 1.0)")
    avg_profit_per_trade: float = Field(..., description="Average profit/loss per trade (EUR)")
    avg_profit_per_winning_trade: float = Field(..., description="Average profit from winning trades (EUR)")
    avg_loss_per_losing_trade: float = Field(..., description="Average loss from losing trades (EUR)")
    largest_win: float = Field(..., description="Largest single trade profit (EUR)")
    largest_loss: float = Field(..., description="Largest single trade loss (EUR)")
    max_drawdown: float = Field(..., description="Maximum percentage drop from peak balance")
    total_fees_paid: float = Field(..., description="Total fees paid across all trades (EUR)")
    avg_hold_duration: timedelta = Field(..., description="Average time positions were held")
    total_exposure_time: timedelta = Field(..., description="Total time capital was deployed")
    exposure_pct: float = Field(..., description="Percentage of time in positions (0.0 to 1.0)")
    sharpe_ratio: Optional[float] = Field(None, description="Risk-adjusted return metric")


class BacktestResults(BaseModel):
    """Complete backtesting results for a symbol."""

    symbol: str = Field(..., description="Trading symbol (e.g., 'BTC', 'ETH')")
    time_resolution: str = Field(..., description="Candle time resolution (e.g., '1h', '4h')")
    time_span: str = Field(..., description="Time span backtested (e.g., '5y', '1m')")
    start_datetime: datetime = Field(..., description="First candle timestamp")
    end_datetime: datetime = Field(..., description="Last candle timestamp")
    total_candles: int = Field(..., description="Total number of candles analyzed")
    num_evaluations: int = Field(..., description="Number of strategy evaluations performed")
    signals: list[BacktestSignal] = Field(..., description="All signals generated during backtest")
    trades: list[BacktestTrade] = Field(..., description="All completed trades")
    metrics: BacktestMetrics = Field(..., description="Performance metrics")
    current_position: Optional[BacktestPosition] = Field(None, description="Open position if still held")

    class Config:
        arbitrary_types_allowed = True
