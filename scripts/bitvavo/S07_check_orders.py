from coinbot import BITVAVO

orders = BITVAVO.getOrders(market="BTC-EUR", options={})
for order in orders:
    for key in order:
        print(key, order[key])
    print()
    print()
    print()