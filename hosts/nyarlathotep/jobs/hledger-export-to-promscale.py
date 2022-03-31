#!/usr/bin/env python3

import calendar
import csv
import datetime
import io
import os
import subprocess
import sys


DRY_RUN = "--dry-run" in sys.argv

if not DRY_RUN:
    import requests

    PROMSCALE_URI = os.environ["PROMSCALE_URI"]


def hledger_command(args):
    """Run a hledger command, throw an error if it fails, and return the
    stdout.
    """

    real_args = ["hledger"]
    real_args.extend(args)

    proc = subprocess.run(real_args, check=True, capture_output=True)
    return proc.stdout.decode("utf-8")


def date_to_timestamp(date):
    """Turn `YYYY-MM-DD` into a UNIX timestamp at millisecond resolution,
    at midnight UTC.
    """

    parsed = datetime.datetime.strptime(date, "%Y-%m-%d")
    return calendar.timegm(parsed.timetuple()) * 1000


def running_totals(deltas_by_timestamp):
    """Turn `timestamp => key => delta` to `timestamp => key => total` by
    summing deltas in order.
    """

    current = {}
    out = {}
    for timestamp in sorted(deltas_by_timestamp.keys()):
        for k, delta in deltas_by_timestamp[timestamp].items():
            current[k] = current.get(k, 0) + delta
        out[timestamp] = {k: v for k, v in current.items()}
    return out


def pivot(samples_by_timestamp):
    """Turn `timestamp => key => value` to `key => [timestamp, value]`"""

    pivoted = {}
    for timestamp, kvs in samples_by_timestamp.items():
        for k, v in kvs.items():
            samples = pivoted.get(k, [])
            samples.append([timestamp, v])
            pivoted[k] = samples
    return pivoted


def metric_hledger_fx_rate(gbp_fx_rates):
    """`hledger_fx_rate{currency="xxx", target_currency="xxx"}`

    - Every currency has an exchange rate of 1 with itself.

    - Every currency has an exchange rate from GBP to itself at
    1/rate.

    - Every pair of currencies have exchange rates converting both
    ways (via GBP).
    """

    key = lambda currency, target_currency: (
        ("currency", currency),
        ("target_currency", target_currency),
    )

    # gbp_fx_rates_by_timestamp :: timestamp => currency => gbp_exchange_rate
    gbp_fx_rates_by_timestamp = {}
    for price in gbp_fx_rates:
        _, date, from_currency, gbp_exchange_rate = price.split()
        timestamp = date_to_timestamp(date)
        gbp_exchange_rate = float(gbp_exchange_rate[1:])

        new_rates = gbp_fx_rates_by_timestamp.get(timestamp, {})
        new_rates[from_currency] = gbp_exchange_rate
        gbp_fx_rates_by_timestamp[timestamp] = new_rates

    # fx_rates_by_timestamp :: timestamp => key => exchange_rate
    fx_rates_by_timestamp = {}
    for timestamp, gbp_fx_rates in gbp_fx_rates_by_timestamp.items():
        fx_rates = {key("GBP", "GBP"): 1}
        for currency, fx in gbp_fx_rates.items():
            fx_rates[key(currency, currency)] = 1
            fx_rates[key(currency, "GBP")] = fx
            fx_rates[key("GBP", currency)] = 1 / fx
        for currency, from_fx in gbp_fx_rates.items():
            for target_currency, to_fx in gbp_fx_rates.items():
                fx_rates[key(currency, target_currency)] = from_fx / to_fx
        fx_rates_by_timestamp[timestamp] = fx_rates

    return pivot(fx_rates_by_timestamp)


def metric_hledger_balance(postings):
    """`hledger_balance{account="xxx", currency="xxx"}`

    Accounts are propagated forward in time: if an account is seen at
    time T, then its balance will also be reported at time T+1, T+2,
    etc.

    Postings are applied to an account and all of its superaccounts.
    """

    key = lambda account, currency: (("account", account), ("currency", currency))

    # deltas_by_timestamp :: timestamp => key => delta
    deltas_by_timestamp = {}
    for posting in postings:
        timestamp = date_to_timestamp(posting["date"])
        currency = posting["commodity"]
        decrease = float(posting["credit"] or "0")
        increase = float(posting["debit"] or "0")

        if currency == "£":
            currency = "GBP"

        deltas = deltas_by_timestamp.get(timestamp, {})
        account = None
        for segment in posting["account"].split(":"):
            if account is None:
                account = segment
            else:
                account = f"{account}:{segment}"

            deltas[key(account, currency)] = (
                deltas.get(key(account, currency), 0) + increase - decrease
            )
        deltas_by_timestamp[timestamp] = deltas

    return pivot(running_totals(deltas_by_timestamp))


def metric_hledger_monthly_credits_debits(postings, field):
    """`hledger_monthly_xxx{account="xxx", currency="xxx"}`

    Like `hledger_balance` but only sums the credits or debits (these
    are two separate metrics).  These are also grouped by calendar
    month, with all the transactions taking effect at midnight (UTC)
    on the 1st.

    This drops the last calendar month, so only complete months are
    present.
    """

    key = lambda account, currency: (("account", account), ("currency", currency))

    # deltas_by_timestamp :: timestamp => key => delta
    deltas_by_timestamp = {}
    for posting in postings:
        parsed = datetime.datetime.strptime(posting["date"], "%Y-%m-%d")
        timestamp = calendar.timegm(parsed.replace(day=1).timetuple()) * 1000

        currency = posting["commodity"]
        delta = float(posting[field] or "0")

        if currency == "£":
            currency = "GBP"

        deltas = deltas_by_timestamp.get(timestamp, {})
        account = None
        for segment in posting["account"].split(":"):
            if account is None:
                account = segment
            else:
                account = f"{account}:{segment}"

            deltas[key(account, currency)] = (
                deltas.get(key(account, currency), 0) + delta
            )
        deltas_by_timestamp[timestamp] = deltas

    del deltas_by_timestamp[max(deltas_by_timestamp.keys())]

    return pivot(deltas_by_timestamp)


def metric_hledger_transactions_total(postings):
    """`hledger_transactions_total{status="(pending|bookkeeping|cleared)"}`"""

    TRANSACTION_STATUS_NAMES = {"": "pending", "!": "bookkeeping", "*": "cleared"}

    key = lambda status: (("status", TRANSACTION_STATUS_NAMES[status]),)

    # txnids_by_timestamp :: timestamp => key => set(txn_id)
    txnids_by_timestamp = {}
    for posting in postings:
        timestamp = date_to_timestamp(posting["date"])
        status = posting["status"]

        txnids_by_status = txnids_by_timestamp.get(timestamp, {})
        txnids = txnids_by_status.get(key(status), set())
        txnids.add(posting["txnidx"])
        txnids_by_status[key(status)] = txnids
        txnids_by_timestamp[timestamp] = txnids_by_status

    # counts_by_timestamp :: timestamp => key => int
    counts_by_timestamp = {
        ts: {k: len(ids) for k, ids in vs.items()}
        for ts, vs in txnids_by_timestamp.items()
    }

    return pivot(running_totals(counts_by_timestamp))


raw_prices = hledger_command(["prices"]).splitlines()
raw_postings = list(
    csv.DictReader(io.StringIO(hledger_command(["print", "-O", "csv"])))
)

metrics = {
    "hledger_fx_rate": metric_hledger_fx_rate(raw_prices),
    "hledger_balance": metric_hledger_balance(raw_postings),
    "hledger_monthly_increase": metric_hledger_monthly_credits_debits(
        raw_postings, "debit"
    ),
    "hledger_monthly_decrease": metric_hledger_monthly_credits_debits(
        raw_postings, "credit"
    ),
    "hledger_transactions_total": metric_hledger_transactions_total(raw_postings),
}

for name, values in metrics.items():
    if not DRY_RUN:
        requests.post(f"{PROMSCALE_URI}/delete_series?match[]={name}")

    for labels_tuples, samples in values.items():
        print(f"Uploading {labels_tuples} ({len(samples)} samples)")

        labels = dict(labels_tuples)
        labels["__name__"] = name
        json = {"labels": labels, "samples": samples}

        if DRY_RUN:
            print(json)
        else:
            requests.post(f"{PROMSCALE_URI}/write", json=json).raise_for_status()
