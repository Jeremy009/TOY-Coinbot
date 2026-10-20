import pickle
from multiprocessing import Pool
from pathlib import Path
import numpy as np
from tqdm import tqdm

from coinbot.backend.indicators import macd_indicator
from coinbot.backend.signals import macd_signal, TradebotAction

DATA_FOLDER = Path(__file__).resolve().parents[2] / "data"
WORK = False
ANALYSE = True


def work(args):
    symbol = args[0]
    time_resolution = args[1]
    sw = args[2]
    lw = args[3]
    ss = args[4]

    candles_file = DATA_FOLDER.joinpath(symbol, "{}.pkl".format(time_resolution))
    with open(candles_file, 'rb') as open_file:
        candles = pickle.load(open_file)
    macd_candles = macd_indicator(candles, short_period=sw, long_period=lw, signal_period=ss)
    num_candles = len(candles)

    # Run a simulation
    num_euro = 100
    num_coins = 0
    for i in tqdm(range(num_candles), desc="{} @ {}".format(symbol, time_resolution), leave=False, disable=True):
        if i < 5:
            continue
        trunc_cand = macd_candles.iloc[i - 5:i]
        current_value = ((trunc_cand["low"] + trunc_cand["high"] + trunc_cand["close"]) / 3).tail(1).item()
        macd_sig = macd_signal(trunc_cand)

        if macd_sig == TradebotAction.BUY:
            if num_euro > 0.0:
                num_euro = 0.9985 * num_euro
                num_coins = 1 / current_value * num_euro
                num_euro = 0.0
        elif macd_sig == TradebotAction.SELL:
            if num_coins > 0.0:
                num_euro = current_value * num_coins * 0.9975
                num_coins = 0.0
        else:
            pass

    num_euro = current_value * num_coins * 0.9975 if num_coins > 0.0 else num_euro
    print("{} 5 years MACD({}, short={}, long={}, signal={}) performance evaluation: {}".format(symbol, time_resolution, sw, lw, ss, num_euro))


def analyse():
    results = {}
    with open(str(DATA_FOLDER.joinpath("results.txt")), "r") as res_file:
        for line in res_file.readlines():
            symbol = line.split(" ")[0]
            strategy = line.split("MACD(")[1].split(")")[0]
            result = line.split(" ")[-1]
            if strategy not in results.keys():
                results[strategy] = {"symbols": [], "results": []}
            results[strategy]["symbols"].append(symbol)
            results[strategy]["results"].append(float(result.replace("\n", "")))

    new_res = []
    for strategy in results.keys():
        new_res.append((np.sum(results[strategy]["results"]), np.min(results[strategy]["results"]), strategy))
    new_res.sort()

    for nr in new_res:
        print(nr[2])
        print(nr[0])
        print(nr[1])
        print()
        print()


if __name__ == "__main__":
    if WORK:
        args = []
        for s in ['ADA', 'AVAX', 'BTC', 'CRV', 'DOGE', 'ETH', 'LUNA', 'LUNA2', 'SHIB', 'SOL', 'UNI', 'VET', 'VTHO', 'XRP']:
            for tr in ["6h", "8h"]:
                for ll in [36, 39, 42]:
                    for ss in [9, 11, 13]:
                        args.append((s, tr, 12, ll, ss))
        pool = Pool(12)
        pool.map(work, tuple(args))
        pool.close()
        pool.join()

    if ANALYSE:
        analyse()
