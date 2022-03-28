#!/usr/bin/env python3

from html.parser import HTMLParser

import os
import requests
import sys
import time

DRY_RUN = "--dry-run" in sys.argv


def get_coinbase(symbol):
    r = requests.get(
        f"https://api.coinbase.com/v2/prices/{symbol}-GBP/spot/",
        headers={"CB-VERSION": "2018-05-25"},
    )
    r.raise_for_status()
    return r.json()["data"]["amount"]


def get_financial_times(url):
    class FTPriceFinder(HTMLParser):
        def __init__(self):
            HTMLParser.__init__(self)
            self.found = None
            self.isnext = False

        def handle_data(self, data):
            if data == "Price (GBP)":
                self.isnext = True
            elif self.isnext:
                self.found = data
                self.isnext = False

    r = requests.get(url)
    r.raise_for_status()
    finder = FTPriceFinder()
    finder.feed(r.text)
    if finder.found is None:
        raise Exception("could not find price")
    else:
        return finder.found


CRYPTOCURRENCIES = ["BTC", "ETH", "LTC"]
CURRENCIES = ["EUR", "JPY", "USD"]
FUNDS = [("VANEA", "GB00B41XG308")]

DATE = time.strftime("%Y-%m-%d")

with (sys.stdout if DRY_RUN else open(os.environ["PRICE_FILE"], "a")) as f:
    print("", file=f)

    for symbol in CRYPTOCURRENCIES:
        try:
            rate = get_coinbase(symbol)
            print(f"P {DATE} {symbol} £{rate}", file=f)
        except Exception as e:
            print(f"; error processing cryptocurrency '{symbol}': {e}", file=f)

    for symbol in CURRENCIES:
        try:
            rate = get_financial_times(
                f"https://markets.ft.com/data/currencies/tearsheet/summary?s={symbol}GBP"
            )
            print(f"P {DATE} {symbol} £{rate}", file=f)
        except Exception as e:
            print(f"; error processing currency '{symbol}': {e}", file=f)

    for (symbol, isin) in FUNDS:
        try:
            rate = get_financial_times(
                f"https://markets.ft.com/data/funds/tearsheet/summary?s={isin}:GBP"
            )
            print(f"P {DATE} {symbol} £{rate}", file=f)
        except Exception as e:
            print(f"; error processing fund '{symbol}': {e}", file=f)
