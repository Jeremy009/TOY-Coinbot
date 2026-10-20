from coinbot import BITVAVO

balance = BITVAVO.balance({})
total_balance = 0.0
print("--------------------WALLET---------------------")

for b in balance:
    symbol = b["symbol"]
    if symbol == "EUR":
        amount_in_eur = float(b["available"])
        print(symbol, "\t", amount_in_eur, "\t", "1.00", "\t", round(amount_in_eur, 2), " EUR")
    else:
        amount_in_coins = float(b["available"])
        price = float(BITVAVO.tickerPrice({"market": symbol + "-EUR"})["price"])
        amount_in_eur = amount_in_coins * price
        total_balance += amount_in_eur
        print(symbol, "\t", amount_in_coins, "\t", price, "\t", round(amount_in_eur, 2), " EUR")
print("------------------------------------------------")
print("               TOTAL WALLET VALUE = +{} EUR".format(round(total_balance, 2)))