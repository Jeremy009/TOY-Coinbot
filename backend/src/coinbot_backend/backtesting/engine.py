"""Backtesting engine for evaluating trading strategies on historical data."""

import logging
from datetime import datetime, timedelta
from typing import Optional

import numpy as np
from tqdm import tqdm

from coinbot_backend.backtesting.models import (
    BacktestMetrics,
    BacktestPosition,
    BacktestResults,
    BacktestSignal,
    BacktestTrade,
)
from coinbot_backend.core.constants import TIME_RESOLUTIONS
from coinbot_backend.models.candles import OHLCVCandles
from coinbot_backend.models.trading import Signal
from coinbot_backend.services.bitvavo_client import BitvavoClient
from coinbot_backend.services.trading_strategies import strategy_ema_crossover as strategy
from coinbot_backend.core.constants import TIME_SPANS

logger = logging.getLogger(__name__)


class BacktestEngine:
    """Engine for backtesting trading strategies on historical data."""

    def __init__(
        self,
        client: BitvavoClient,
        initial_balance: float = 1000.0,
        fee_rate: float = 0.0030,
        evaluation_interval_hours: int = 1,
        strategy_window_span: str = "1m",
        entry_min_confidence: float = 0.60,
        exit_min_confidence: float = 0.65,
        trailing_stop_loss_pct: float = 4.0,
        apply_prefilters: bool = False,
        min_growth_24h: float = -10.0,
        volume_limit: float = 1_000_000.0,
    ):
        """Initialize backtesting engine with configuration."""
        self.client = client
        self.initial_balance = initial_balance
        self.fee_rate = fee_rate
        self.evaluation_interval_hours = evaluation_interval_hours
        self.strategy_window_span = strategy_window_span
        self.entry_min_confidence = entry_min_confidence
        self.exit_min_confidence = exit_min_confidence
        self.trailing_stop_loss_pct = trailing_stop_loss_pct
        self.apply_prefilters = apply_prefilters
        self.min_growth_24h = min_growth_24h
        self.volume_limit = volume_limit

    def run_backtest(
        self, symbol: str, time_resolution: str = "1h", time_span: str = "5y"
    ) -> BacktestResults:
        """
        Run complete backtesting simulation.

        Walks forward through historical data, evaluating the strategy at regular intervals
        and simulating trades based on the same logic as the live bot.
        """
        logger.info(f"Starting backtest for {symbol} over {time_span} at {time_resolution} resolution")

        # Fetch full historical data
        logger.info("Fetching historical candle data...")
        candles = self.client.get_candles(symbol, time_resolution, time_span, verbose=True)

        if candles.num_candles == 0:
            raise ValueError(f"No candle data available for {symbol}")

        logger.info(f"Loaded {candles.num_candles} candles from {candles.timelabels[0]} to {candles.timelabels[-1]}")

        # Calculate rolling 24h metrics for pre-filtering
        growth_24h, volume_24h = self._calculate_rolling_24h_metrics(candles, time_resolution)

        # Calculate evaluation interval in candles
        resolution_seconds = TIME_RESOLUTIONS[time_resolution]
        evaluation_interval_candles = max(1, int((self.evaluation_interval_hours * 3600) / resolution_seconds))

        logger.info(f"Evaluating strategy every {evaluation_interval_candles} candles ({self.evaluation_interval_hours}h)")

        # Calculate strategy window size in candles (e.g., 1 month at 1h = 720 candles)
        strategy_window_seconds = TIME_SPANS[self.strategy_window_span]
        strategy_window_candles = int(strategy_window_seconds / resolution_seconds)

        logger.info(f"Strategy window: {strategy_window_candles} candles ({self.strategy_window_span})")

        # Initialize state
        balance = self.initial_balance
        position: Optional[BacktestPosition] = None
        signals: list[BacktestSignal] = []
        trades: list[BacktestTrade] = []

        # Start evaluation after we have enough data for strategy window
        start_idx = strategy_window_candles

        # Check if we have enough data
        if start_idx >= candles.num_candles:
            logger.error(
                f"Insufficient data for backtesting. Need at least {strategy_window_candles} candles "
                f"for strategy window ({self.strategy_window_span}), but only have {candles.num_candles}. "
                f"Try a shorter time span or different resolution."
            )
            raise ValueError(
                f"Need at least {strategy_window_candles} candles, but only have {candles.num_candles}"
            )

        # Walk forward through time
        logger.info("Running backtest simulation...")
        for i in tqdm(range(start_idx, candles.num_candles, evaluation_interval_candles), desc="Backtesting"):
            current_price = candles.close_positions[i]
            current_datetime = candles.timelabels[i]

            # Check pre-filters if enabled
            if self.apply_prefilters and not self._passes_prefilter(i, growth_24h, volume_24h):
                # Record HOLD signal due to pre-filter failure
                signals.append(
                    BacktestSignal(
                        datetime=current_datetime,
                        signal=Signal.HOLD,
                        confidence=0.0,
                        reason="Failed pre-filter (24h growth or volume)",
                        price=current_price,
                    )
                )
                continue

            # Extract rolling window for strategy evaluation
            window_start = i - strategy_window_candles
            window_end = i
            strategy_candles = self._extract_candle_window(candles, window_start, window_end)

            # Evaluate position or entry
            if position is not None:
                # We have an open position - check for exit
                trade, signal = self._evaluate_position(
                    position, current_price, current_datetime, strategy_candles, balance
                )

                if signal:
                    signals.append(signal)

                if trade:
                    trades.append(trade)
                    balance = trade.total_received
                    position = None
                    logger.debug(
                        f"SELL at {current_datetime}: {trade.amount:.4f} @ €{trade.exit_price:.2f} "
                        f"P/L: €{trade.profit_loss:.2f} ({trade.profit_loss_pct:.1f}%)"
                    )
                else:
                    # Update ATH if still holding
                    position.ath = max(position.ath, current_price)
            else:
                # No position - check for entry
                new_position, signal = self._evaluate_entry(current_price, current_datetime, strategy_candles, balance)

                signals.append(signal)

                if new_position:
                    position = new_position
                    balance = 0.0  # All capital deployed
                    logger.debug(
                        f"BUY at {current_datetime}: {position.amount:.4f} @ €{position.entry_price:.2f} "
                        f"Cost: €{position.total_cost:.2f}"
                    )

        # Calculate final balance (including open position value)
        final_balance = balance
        if position is not None:
            final_price = candles.close_positions[-1]
            position_value = position.amount * final_price
            exit_fee = position_value * self.fee_rate
            final_balance = position_value - exit_fee
            logger.info(
                f"Position still open at end: {position.amount:.4f} @ €{final_price:.2f} "
                f"(unrealized value: €{final_balance:.2f})"
            )

        # Calculate metrics
        if start_idx < len(candles.timelabels):
            total_duration = candles.timelabels[-1] - candles.timelabels[start_idx]
        else:
            total_duration = timedelta(0)
        metrics = self._calculate_metrics(trades, signals, total_duration, final_balance)

        logger.info(f"Backtest complete: {len(trades)} trades, {len(signals)} evaluations")
        logger.info(f"Final balance: €{final_balance:.2f} (P/L: €{metrics.total_profit_loss:.2f}, "
                    f"{metrics.total_profit_loss_pct:.1f}%)")

        return BacktestResults(
            symbol=symbol,
            time_resolution=time_resolution,
            time_span=time_span,
            start_datetime=candles.timelabels[start_idx],
            end_datetime=candles.timelabels[-1],
            total_candles=candles.num_candles,
            num_evaluations=len(signals),
            signals=signals,
            trades=trades,
            metrics=metrics,
            current_position=position,
        )

    def _calculate_rolling_24h_metrics(
        self, candles: OHLCVCandles, time_resolution: str
    ) -> tuple[list[float], list[float]]:
        """Calculate 24h growth and volume for each candle."""
        resolution_seconds = TIME_RESOLUTIONS[time_resolution]
        candles_in_24h = int(24 * 3600 / resolution_seconds)

        growth_24h = []
        volume_24h = []

        for i in range(candles.num_candles):
            if i < candles_in_24h:
                # Not enough historical data
                growth_24h.append(0.0)
                volume_24h.append(0.0)
            else:
                # Calculate 24h growth
                price_24h_ago = candles.close_positions[i - candles_in_24h]
                current_price = candles.close_positions[i]
                growth = ((current_price - price_24h_ago) / price_24h_ago) * 100

                # Calculate 24h volume (sum of volumes in last 24h)
                volume_sum = sum(candles.volumes[i - candles_in_24h + 1 : i + 1])

                growth_24h.append(growth)
                volume_24h.append(volume_sum)

        return growth_24h, volume_24h

    def _passes_prefilter(
        self, candle_idx: int, growth_24h: list[float], volume_24h: list[float]
    ) -> bool:
        """Check if symbol passes pre-filtering at this point."""
        return growth_24h[candle_idx] >= self.min_growth_24h and volume_24h[candle_idx] >= self.volume_limit

    def _extract_candle_window(
        self, candles: OHLCVCandles, start_idx: int, end_idx: int
    ) -> OHLCVCandles:
        """Extract a window of candles for strategy evaluation."""
        return OHLCVCandles(
            symbol=candles.symbol,
            timestamps=candles.timestamps[start_idx:end_idx],
            time_resolution=candles.time_resolution,
            opening_positions=candles.opening_positions[start_idx:end_idx],
            high_positions=candles.high_positions[start_idx:end_idx],
            low_positions=candles.low_positions[start_idx:end_idx],
            close_positions=candles.close_positions[start_idx:end_idx],
            volumes=candles.volumes[start_idx:end_idx],
            order="older-to-newer",
        )

    def _evaluate_position(
        self,
        position: BacktestPosition,
        current_price: float,
        current_datetime: datetime,
        strategy_candles: OHLCVCandles,
        current_balance: float,
    ) -> tuple[Optional[BacktestTrade], Optional[BacktestSignal]]:
        """
        Evaluate existing position for exit.

        Returns: (trade if exited, signal generated)
        """
        # Check trailing stop-loss FIRST (highest priority, matches live bot)
        stop_loss_threshold = position.ath * (1 - self.trailing_stop_loss_pct / 100)

        if current_price < stop_loss_threshold:
            # Triggered stop-loss - exit immediately
            return self._execute_exit(
                position, current_price, current_datetime, "Trailing stop-loss triggered"
            ), None

        # Run strategy analysis
        trade_signal = strategy(strategy_candles)

        # Record the signal
        signal = BacktestSignal(
            datetime=current_datetime,
            signal=trade_signal.signal,
            confidence=trade_signal.confidence,
            reason=trade_signal.reason,
            price=current_price,
        )

        # Check exit criteria
        if trade_signal.signal in [Signal.SELL, Signal.STRONG_SELL] and trade_signal.confidence >= self.exit_min_confidence:
            # Exit position
            return self._execute_exit(position, current_price, current_datetime, trade_signal.reason), signal

        # Hold position
        return None, signal

    def _evaluate_entry(
        self, current_price: float, current_datetime: datetime, strategy_candles: OHLCVCandles, current_balance: float
    ) -> tuple[Optional[BacktestPosition], BacktestSignal]:
        """
        Evaluate entry opportunity.

        Returns: (position if entered, signal generated)
        """
        # Run strategy analysis
        trade_signal = strategy(strategy_candles)

        # Record the signal
        signal = BacktestSignal(
            datetime=current_datetime,
            signal=trade_signal.signal,
            confidence=trade_signal.confidence,
            reason=trade_signal.reason,
            price=current_price,
        )

        # Check entry criteria
        if (
            trade_signal.signal in [Signal.BUY, Signal.STRONG_BUY]
            and trade_signal.confidence >= self.entry_min_confidence
            and current_balance > 0
        ):
            # Enter position - use 100% of balance (single asset backtest)
            entry_fee = current_balance * self.fee_rate
            amount_after_fee = (current_balance - entry_fee) / current_price

            position = BacktestPosition(
                entry_datetime=current_datetime,
                entry_price=current_price,
                amount=amount_after_fee,
                total_cost=current_balance,
                ath=current_price,  # Initialize ATH to entry price
                entry_reason=trade_signal.reason,
            )

            return position, signal

        # No entry
        return None, signal

    def _execute_exit(
        self, position: BacktestPosition, exit_price: float, exit_datetime: datetime, exit_reason: str
    ) -> BacktestTrade:
        """Execute exit from position and create trade record."""
        # Calculate exit proceeds
        gross_proceeds = position.amount * exit_price
        exit_fee = gross_proceeds * self.fee_rate
        net_proceeds = gross_proceeds - exit_fee

        # Calculate entry fee (reconstruct from total_cost)
        entry_fee = position.total_cost - (position.amount * position.entry_price)

        # Calculate profit/loss
        profit_loss = net_proceeds - position.total_cost
        profit_loss_pct = (profit_loss / position.total_cost) * 100

        # Calculate hold duration
        hold_duration = exit_datetime - position.entry_datetime

        # Calculate max drawdown during hold
        max_drawdown_pct = ((position.ath - exit_price) / position.ath) * 100 if position.ath > 0 else 0.0

        return BacktestTrade(
            entry_datetime=position.entry_datetime,
            exit_datetime=exit_datetime,
            entry_price=position.entry_price,
            exit_price=exit_price,
            amount=position.amount,
            entry_fee=entry_fee,
            exit_fee=exit_fee,
            total_cost=position.total_cost,
            total_received=net_proceeds,
            profit_loss=profit_loss,
            profit_loss_pct=profit_loss_pct,
            hold_duration=hold_duration,
            entry_reason=position.entry_reason,
            exit_reason=exit_reason,
            max_price=position.ath,
            max_drawdown_pct=max_drawdown_pct,
        )

    def _calculate_metrics(
        self,
        trades: list[BacktestTrade],
        signals: list[BacktestSignal],
        total_duration: timedelta,
        final_balance: float,
    ) -> BacktestMetrics:
        """Calculate comprehensive performance metrics."""
        num_trades = len(trades)

        if num_trades == 0:
            # No trades executed
            return BacktestMetrics(
                initial_balance=self.initial_balance,
                final_balance=final_balance,
                total_profit_loss=final_balance - self.initial_balance,
                total_profit_loss_pct=((final_balance - self.initial_balance) / self.initial_balance) * 100,
                num_trades=0,
                num_winning_trades=0,
                num_losing_trades=0,
                win_rate=0.0,
                avg_profit_per_trade=0.0,
                avg_profit_per_winning_trade=0.0,
                avg_loss_per_losing_trade=0.0,
                largest_win=0.0,
                largest_loss=0.0,
                max_drawdown=0.0,
                total_fees_paid=0.0,
                avg_hold_duration=timedelta(0),
                total_exposure_time=timedelta(0),
                exposure_pct=0.0,
                sharpe_ratio=None,
            )

        # Calculate basic metrics
        winning_trades = [t for t in trades if t.profit_loss > 0]
        losing_trades = [t for t in trades if t.profit_loss <= 0]

        num_winning_trades = len(winning_trades)
        num_losing_trades = len(losing_trades)
        win_rate = num_winning_trades / num_trades if num_trades > 0 else 0.0

        # Profit/loss metrics
        total_profit_loss = final_balance - self.initial_balance
        total_profit_loss_pct = (total_profit_loss / self.initial_balance) * 100

        avg_profit_per_trade = sum(t.profit_loss for t in trades) / num_trades
        avg_profit_per_winning_trade = (
            sum(t.profit_loss for t in winning_trades) / num_winning_trades if num_winning_trades > 0 else 0.0
        )
        avg_loss_per_losing_trade = (
            sum(t.profit_loss for t in losing_trades) / num_losing_trades if num_losing_trades > 0 else 0.0
        )

        largest_win = max((t.profit_loss for t in trades), default=0.0)
        largest_loss = min((t.profit_loss for t in trades), default=0.0)

        # Fee metrics
        total_fees_paid = sum(t.entry_fee + t.exit_fee for t in trades)

        # Time metrics
        avg_hold_duration = timedelta(seconds=sum(t.hold_duration.total_seconds() for t in trades) / num_trades)
        total_exposure_time = timedelta(seconds=sum(t.hold_duration.total_seconds() for t in trades))
        exposure_pct = total_exposure_time / total_duration if total_duration.total_seconds() > 0 else 0.0

        # Drawdown calculation
        balance_history = [self.initial_balance]
        for trade in trades:
            balance_history.append(balance_history[-1] + trade.profit_loss)

        peak_balance = self.initial_balance
        max_drawdown = 0.0
        for balance in balance_history:
            if balance > peak_balance:
                peak_balance = balance
            drawdown = ((peak_balance - balance) / peak_balance) * 100 if peak_balance > 0 else 0.0
            max_drawdown = max(max_drawdown, drawdown)

        # Sharpe ratio calculation (annualized)
        if num_trades >= 2:
            returns = [t.profit_loss_pct / 100 for t in trades]
            avg_return = float(np.mean(returns))
            std_return = float(np.std(returns))
            if std_return > 0:
                # Annualize assuming average hold duration
                avg_hold_days = avg_hold_duration.total_seconds() / (24 * 3600)
                if avg_hold_days > 0:
                    periods_per_year = 365 / avg_hold_days
                    sharpe_ratio = (avg_return * np.sqrt(periods_per_year)) / std_return
                else:
                    sharpe_ratio = None
            else:
                sharpe_ratio = None
        else:
            sharpe_ratio = None

        return BacktestMetrics(
            initial_balance=self.initial_balance,
            final_balance=final_balance,
            total_profit_loss=total_profit_loss,
            total_profit_loss_pct=total_profit_loss_pct,
            num_trades=num_trades,
            num_winning_trades=num_winning_trades,
            num_losing_trades=num_losing_trades,
            win_rate=win_rate,
            avg_profit_per_trade=avg_profit_per_trade,
            avg_profit_per_winning_trade=avg_profit_per_winning_trade,
            avg_loss_per_losing_trade=avg_loss_per_losing_trade,
            largest_win=largest_win,
            largest_loss=largest_loss,
            max_drawdown=max_drawdown,
            total_fees_paid=total_fees_paid,
            avg_hold_duration=avg_hold_duration,
            total_exposure_time=total_exposure_time,
            exposure_pct=exposure_pct,
            sharpe_ratio=sharpe_ratio,
        )
