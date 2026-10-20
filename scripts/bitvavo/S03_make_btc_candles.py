import datetime

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from coinbot import BITVAVO

# Request candles data from BITVAVO
num_candles = 150
candles = BITVAVO.candles('BTC-EUR', '15m', {"limit": num_candles})

# create figure
plt.figure()
x_left_lim = num_candles + 1
x_right_lim = 0 - 1

# Candles
plt.subplot(211)

# create DataFrame for candles
prices = pd.DataFrame({'open': np.array([float(c[1]) for c in candles]),
                       'close': np.array([float(c[4]) for c in candles]),
                       'high': np.array([float(c[2]) for c in candles]),
                       'low': np.array([float(c[3]) for c in candles]),
                       'volume': np.array([float(c[5]) for c in candles])},
                      index=[i for i, _ in enumerate(candles)])

# define width of candlestick elements
width_body = .4
width_wick = .05

# define up and down prices
up = prices[prices.close >= prices.open]
down = prices[prices.close < prices.open]

# plot up prices
plt.bar(up.index, up.close - up.open, width_body, bottom=up.open, color='green')
plt.bar(up.index, up.high - up.close, width_wick, bottom=up.close, color='green')
plt.bar(up.index, up.low - up.open, width_wick, bottom=up.open, color='green')

# plot down prices
plt.bar(down.index, down.close - down.open, width_body, bottom=down.open, color='red')
plt.bar(down.index, down.high - down.open, width_wick, bottom=down.open, color='red')
plt.bar(down.index, down.low - down.close, width_wick, bottom=down.close, color='red')
plt.gca().set_xlim(x_left_lim, x_right_lim)
plt.gca().get_xaxis().set_visible(False)

# Volume
plt.subplot(212)
plt.bar(down.index, down.volume, width_body, bottom=0, color='red')
plt.bar(up.index, up.volume, width_body, bottom=0, color='green')

# rotate x-axis tick labels
label_loc = [i for i, _ in enumerate(candles) if i % 10 == 0]
label_val = [datetime.datetime.fromtimestamp(c[0] / 1000.0) for i, c in enumerate(candles) if i % 10 == 0]
plt.gca().set_xlim(x_left_lim, x_right_lim)

plt.gca().set_xticks(label_loc)
plt.gca().set_xticklabels(label_val)
plt.xticks(rotation=90)

# display figure
plt.tight_layout()
plt.show()
