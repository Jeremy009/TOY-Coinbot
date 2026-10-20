from coinbot import BITVAVO

if BITVAVO.getRemainingLimit() > 0:
    response = BITVAVO.markets({"market": "BTC-EUR"})
    print(response)

if BITVAVO.getRemainingLimit() > 0:
    response = BITVAVO.assets({"symbol": "BTC"})
    print(response)
