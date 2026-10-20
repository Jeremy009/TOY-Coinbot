from pathlib import Path

from coinbot import BITVAVO
from coinbot.backend.clients import BitvavoClient
from coinbot import TIME_RESOLUTIONS

bitvavo_client = BitvavoClient(BITVAVO)
DATA_FOLDER = Path(__file__).resolve().parents[2] / "data"

# Download data locally
symbols = [s for s in bitvavo_client.get_owned_symbols() if s.find("EUR") == -1]
print("Symbols to download ({}): {}".format(len(symbols), symbols))

for time_resolution in TIME_RESOLUTIONS.keys():
    for symbol in symbols:
        if not DATA_FOLDER.joinpath(symbol).is_dir():
            DATA_FOLDER.joinpath(symbol).mkdir()
        candles = bitvavo_client.get_candles(symbol, time_resolution, time_span="5y", verbose=True)
        pandas_candles = candles.as_dataframe()
        pandas_candles.to_pickle(DATA_FOLDER.joinpath(symbol, time_resolution + ".pkl"))
