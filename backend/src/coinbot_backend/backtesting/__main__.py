"""
Backtesting module for Coinbot trading bot.

Usage:
    cd backend && uv run python -m coinbot_backend.backtesting BTC
    cd backend && uv run python -m coinbot_backend.backtesting ETH --resolution 1h --span 5y
    cd backend && uv run python -m coinbot_backend.backtesting LINK --initial-balance 5000 --show
    cd backend && uv run python -m coinbot_backend.backtesting BTC --no-prefilter --save btc_backtest.png
"""

import argparse
import logging
import sys
from datetime import timedelta

from coinbot_backend.backtesting.engine import BacktestEngine
from coinbot_backend.config import settings
from coinbot_backend.services.bitvavo_client import get_bitvavo_client
from coinbot_backend.models.trading import Signal

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)


def format_timedelta(td: timedelta) -> str:
    """Format timedelta as human-readable string."""
    total_seconds = int(td.total_seconds())
    days = total_seconds // (24 * 3600)
    hours = (total_seconds % (24 * 3600)) // 3600
    minutes = (total_seconds % 3600) // 60

    if days > 0:
        return f"{days}d {hours}h {minutes}m"
    elif hours > 0:
        return f"{hours}h {minutes}m"
    else:
        return f"{minutes}m"


def print_results_summary(results):
    """Print formatted backtest results to console."""
    print("\n" + "=" * 80)
    print(f"BACKTEST RESULTS: {results.symbol}")
    print("=" * 80)

    print(f"\nTime Period: {results.start_datetime} to {results.end_datetime}")
    print(f"Resolution: {results.time_resolution}, Span: {results.time_span}")
    print(f"Total Candles: {results.total_candles:,}, Evaluations: {results.num_evaluations:,}")

    print("\n" + "-" * 80)
    print("PERFORMANCE METRICS")
    print("-" * 80)

    m = results.metrics
    print(f"Initial Balance:     €{m.initial_balance:,.2f}")
    print(f"Final Balance:       €{m.final_balance:,.2f}")
    print(f"Total Profit/Loss:   €{m.total_profit_loss:,.2f} ({m.total_profit_loss_pct:+.2f}%)")
    print(f"Total Fees Paid:     €{m.total_fees_paid:,.2f}")

    print(f"\nTrades Executed:     {m.num_trades}")
    print(f"Winning Trades:      {m.num_winning_trades} ({m.win_rate * 100:.1f}%)")
    print(f"Losing Trades:       {m.num_losing_trades}")

    if m.num_trades > 0:
        print(f"\nAvg Profit/Trade:    €{m.avg_profit_per_trade:,.2f}")
        if m.num_winning_trades > 0:
            print(f"Avg Winning Trade:   €{m.avg_profit_per_winning_trade:,.2f}")
        if m.num_losing_trades > 0:
            print(f"Avg Losing Trade:    €{m.avg_loss_per_losing_trade:,.2f}")

        print(f"\nLargest Win:         €{m.largest_win:,.2f}")
        print(f"Largest Loss:        €{m.largest_loss:,.2f}")
        print(f"Max Drawdown:        {m.max_drawdown:.2f}%")

        print(f"\nAvg Hold Duration:   {format_timedelta(m.avg_hold_duration)}")
        print(f"Total Exposure:      {format_timedelta(m.total_exposure_time)} ({m.exposure_pct * 100:.1f}% of time)")

        if m.sharpe_ratio is not None:
            print(f"Sharpe Ratio:        {m.sharpe_ratio:.2f}")

    print("\n" + "-" * 80)
    print("SIGNAL DISTRIBUTION")
    print("-" * 80)


    signal_counts = {}
    for signal in results.signals:
        signal_counts[signal.signal] = signal_counts.get(signal.signal, 0) + 1

    for signal_type in [Signal.STRONG_BUY, Signal.BUY, Signal.HOLD, Signal.SELL, Signal.STRONG_SELL]:
        count = signal_counts.get(signal_type, 0)
        pct = (count / len(results.signals)) * 100 if results.signals else 0
        print(f"{signal_type.value.upper():15s}: {count:4d} ({pct:5.1f}%)")

    if results.trades:
        print("\n" + "-" * 80)
        print("TRADE HISTORY")
        print("-" * 80)
        print(
            f"{'#':<4} {'Entry Date':<20} {'Exit Date':<20} {'Entry €':<10} {'Exit €':<10} {'P/L €':<12} {'P/L %':<8} {'Duration'}"
        )
        print("-" * 80)

        for idx, trade in enumerate(results.trades, 1):
            entry_date = trade.entry_datetime.strftime("%Y-%m-%d %H:%M")
            exit_date = trade.exit_datetime.strftime("%Y-%m-%d %H:%M")
            pl_color = "+" if trade.profit_loss >= 0 else ""
            duration = format_timedelta(trade.hold_duration)

            print(
                f"{idx:<4} {entry_date:<20} {exit_date:<20} "
                f"{trade.entry_price:<10.2f} {trade.exit_price:<10.2f} "
                f"{pl_color}{trade.profit_loss:<12.2f} {pl_color}{trade.profit_loss_pct:<8.1f} {duration}"
            )

    if results.current_position:
        print("\n" + "-" * 80)
        print("OPEN POSITION (Unrealized)")
        print("-" * 80)
        pos = results.current_position
        entry_date = pos.entry_datetime.strftime("%Y-%m-%d %H:%M")
        print(f"Entry Date:   {entry_date}")
        print(f"Entry Price:  €{pos.entry_price:.2f}")
        print(f"Amount:       {pos.amount:.6f}")
        print(f"Total Cost:   €{pos.total_cost:.2f}")
        print(f"ATH:          €{pos.ath:.2f}")
        print(f"Entry Reason: {pos.entry_reason}")

    print("\n" + "=" * 80 + "\n")


def main():
    """Main entry point for backtesting CLI."""
    parser = argparse.ArgumentParser(
        description="Backtest Coinbot trading strategies on historical data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s BTC
  %(prog)s ETH --resolution 1h --span 5y
  %(prog)s LINK --initial-balance 5000 --show
  %(prog)s BTC --no-prefilter --save btc_backtest.png
        """,
    )

    parser.add_argument("symbol", help="Trading symbol (e.g., BTC, ETH, LINK)")

    parser.add_argument(
        "--resolution",
        default=settings.backtest_default_time_resolution,
        help=f"Time resolution (default: {settings.backtest_default_time_resolution})",
    )

    parser.add_argument(
        "--span",
        default=settings.backtest_default_time_span,
        help=f"Time span to backtest (default: {settings.backtest_default_time_span})",
    )

    parser.add_argument(
        "--initial-balance",
        type=float,
        default=settings.backtest_default_initial_balance,
        help=f"Starting EUR balance (default: {settings.backtest_default_initial_balance})",
    )

    parser.add_argument(
        "--fee-rate",
        type=float,
        default=settings.bot_dry_run_fee_rate,
        help=f"Fee rate as decimal (default: {settings.bot_dry_run_fee_rate})",
    )

    parser.add_argument(
        "--evaluation-interval",
        type=int,
        default=settings.backtest_evaluation_interval_hours,
        help=f"Hours between evaluations (default: {settings.backtest_evaluation_interval_hours})",
    )

    parser.add_argument(
        "--entry-confidence",
        type=float,
        default=settings.bot_entry_min_confidence,
        help=f"Minimum confidence for entry (default: {settings.bot_entry_min_confidence})",
    )

    parser.add_argument(
        "--exit-confidence",
        type=float,
        default=settings.bot_exit_min_confidence,
        help=f"Minimum confidence for exit (default: {settings.bot_exit_min_confidence})",
    )

    parser.add_argument(
        "--stop-loss",
        type=float,
        default=settings.bot_trailing_stop_loss_pct,
        help=f"Trailing stop-loss percentage (default: {settings.bot_trailing_stop_loss_pct})",
    )

    parser.add_argument(
        "--no-prefilter",
        action="store_true",
        help="Disable pre-filtering (24h growth/volume checks)",
    )

    parser.add_argument(
        "--show",
        action="store_true",
        help="Show interactive chart (requires display)",
    )

    parser.add_argument(
        "--save",
        metavar="PATH",
        help="Save chart to file path",
    )

    args = parser.parse_args()

    # Validate symbol
    symbol = args.symbol.upper()

    try:
        # Initialize client and engine
        logger.info("Initializing Bitvavo client...")
        client = get_bitvavo_client()

        if symbol not in client.available_symbols:
            logger.error(f"Symbol {symbol} not available on Bitvavo")
            logger.info(f"Available symbols: {', '.join(sorted(client.available_symbols)[:20])}...")
            sys.exit(1)

        logger.info("Initializing backtesting engine...")
        engine = BacktestEngine(
            client=client,
            initial_balance=args.initial_balance,
            fee_rate=args.fee_rate,
            evaluation_interval_hours=args.evaluation_interval,
            entry_min_confidence=args.entry_confidence,
            exit_min_confidence=args.exit_confidence,
            trailing_stop_loss_pct=args.stop_loss,
            apply_prefilters=not args.no_prefilter,
            min_growth_24h=settings.bot_min_growth_24h,
            volume_limit=settings.bot_volume_limit,
        )

        # Run backtest
        logger.info(f"Running backtest for {symbol}...")
        results = engine.run_backtest(symbol, args.resolution, args.span)

        # Print results
        print_results_summary(results)

        # Generate visualization if requested
        if args.show or args.save:
            logger.info("Generating backtesting chart...")
            from coinbot_backend.backtesting.plot import plot_backtesting_results

            # Fetch candles for visualization
            candles = client.get_candles(symbol, args.resolution, args.span, verbose=False)

            plot_backtesting_results(
                candles=candles,
                results=results,
                show=args.show,
                save_path=args.save,
            )

            if args.save:
                logger.info(f"Chart saved to: {args.save}")
            if args.show:
                logger.info("Displaying interactive chart...")

    except KeyboardInterrupt:
        logger.info("\nBacktest interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.exception(f"Backtest failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
