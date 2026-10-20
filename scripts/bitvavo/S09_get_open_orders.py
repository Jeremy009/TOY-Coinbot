from coinbot import BITVAVO

orders = BITVAVO.ordersOpen(options={})
for order in orders:
    print(order["market"], order["amount"])
    print()
