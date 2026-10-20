from coinbot import BITVAVO
import numpy as np
import datetime

# Deposits
deposits = BITVAVO.depositHistory({})
total_deposit = 0.0
print("--------------DEPOSITS--------------")
for d in deposits:
    total_deposit += float(d["amount"])-float(d["fee"])
    print("{} {} : -{} {}".format("V" if d["status"] else "X", datetime.datetime.fromtimestamp(d["timestamp"] / 1000.0), float(d["amount"])-float(d["fee"]), d["symbol"]))
print("------------------------------------")
print("      TOTAL DEPOSITED = -{} EUR".format(total_deposit))
print()
print()

# Withdrawals
print("------------WITHDRAWALS-------------")
withdrawals = BITVAVO.withdrawalHistory({})
total_withdrawn = 0.0
for w in withdrawals:
    total_withdrawn += float(w["amount"])-float(w["fee"])
    print("{} {} : +{} {}".format("V" if w["status"] else "X", datetime.datetime.fromtimestamp(w["timestamp"] / 1000.0), float(w["amount"])-float(w["fee"]), w["symbol"]))
print("------------------------------------")
print("      TOTAL WITHDRAWN = +{} EUR".format(total_withdrawn))
print()
print()

# Balance
print("--------------BALANCE---------------")
print("        NET CASH FLOW = {} EUR".format(total_deposit-total_withdrawn))
print()
print()
