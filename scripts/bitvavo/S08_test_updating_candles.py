from coinbot import BITVAVO
import time


def error_callback(error):
    print("Handle error here", error)


def success_callback(response):
    print(response)
    print(BITVAVO.getRemainingLimit())
    print()


websocket = BITVAVO.newWebsocket()
websocket.setErrorCallback(error_callback)
websocket.subscriptionCandles('BTC-EUR', '1m', success_callback)

try:
    while BITVAVO.getRemainingLimit() > 0:
        time.sleep(0.5)
except KeyboardInterrupt:
    websocket.closeSocket()

