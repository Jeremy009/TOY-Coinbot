import logging

import numpy as np

from coinbot import LOG_MSG_FORMAT, LOG_TIME_FORMAT, BITVAVO
from coinbot.backend.clients import BitvavoClient

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
stream_handler = logging.StreamHandler()
stream_handler.setFormatter(logging.Formatter(LOG_MSG_FORMAT, LOG_TIME_FORMAT))
logger.addHandler(stream_handler)

client = BitvavoClient(BITVAVO)

symbol, amount_in_euro = "ARK", "10.0"

response = client.buy(symbol, amount_in_euro)
if "error" in response.keys():
    logger.error("Failed to buy {} because {}".format(symbol, response["error"].lower()))
else:
    logger.info("Bought {} {} for {} EUR at a rate of {} EUR/{} (fee: {} {})".format(
        response["filledAmount"],
        response["market"].replace("-EUR", ""),
        np.round(float(response["filledAmountQuote"]), 2),
        np.round(float(response["filledAmountQuote"]) / float(response["filledAmount"]), 2),
        response["market"].replace("-EUR", ""),
        response["feePaid"],
        response["feeCurrency"],
    ))
