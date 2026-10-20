from coinbot import BITVAVO

response = BITVAVO.time()
print(response)
limit = BITVAVO.getRemainingLimit()
print(limit)
