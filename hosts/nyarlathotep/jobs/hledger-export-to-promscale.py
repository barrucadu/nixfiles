#!/usr/bin/env python3

import calendar
import csv
import datetime
import io
import os
import subprocess
import sys

from decimal import Decimal


DRY_RUN = "--dry-run" in sys.argv

if not DRY_RUN:
    import requests

    PROMSCALE_URI = os.environ["PROMSCALE_URI"]

DOB = datetime.datetime(1991, 9, 9)


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


def convert_samples(samples):
    """Turn `[timestamp, float or int or decimal]` to `[timestamp, float or int]`"""

    return [
        [timestamp, value if isinstance(value, int) else float(value)]
        for timestamp, value in samples
    ]


def preprocess_group_credits_debits(postings):
    """Group postings by date and work out the total debit / credit for
    each account.  This is then used to simplify other metrics.

    Accounts are projected forwards and backwards in time.

    Postings are applied to an account and all of its superaccounts.
    """

    key = lambda account, currency: (("account", account), ("currency", currency))
    all_keys = set()

    # credits_debits_by_date :: date => key => {credit, debit}
    credits_debits_by_date = {}
    for posting in postings:
        currency = posting["commodity"]
        credit = Decimal(posting["credit"] or "0")
        debit = Decimal(posting["debit"] or "0")

        if currency == "£":
            currency = "GBP"

        credits_debits = credits_debits_by_date.get(posting["date"], {})
        account = None
        for segment in posting["account"].split(":"):
            if account is None:
                account = segment
            else:
                account = f"{account}:{segment}"

            k = key(account, currency)
            all_keys.add(k)

            old = credits_debits.get(k, {"credit": 0, "debit": 0})
            credits_debits[k] = {
                "credit": old["credit"] + credit,
                "debit": old["debit"] + debit,
            }
        credits_debits_by_date[posting["date"]] = credits_debits

    # Project accounts through all time
    for timestamp in credits_debits_by_date.keys():
        credits_debits = credits_debits_by_date[timestamp]
        for k in all_keys:
            credits_debits[k] = credits_debits.get(k, {"credit": 0, "debit": 0})
        credits_debits_by_date[timestamp] = credits_debits

    return credits_debits_by_date


def metric_hledger_fx_rate(gbp_fx_rates, credits_debits):
    """`hledger_fx_rate{currency="xxx", target_currency="xxx"}`

    - Every currency has an exchange rate of 1 with itself.

    - Every currency has an exchange rate from GBP to itself at
    1/rate.

    - Every pair of currencies have exchange rates converting both
    ways (via GBP).

    Exchange rates are projected forwards if there are credits /
    debits in a gap.
    """

    key = lambda currency, target_currency: (
        ("currency", currency),
        ("target_currency", target_currency),
    )

    all_timestamps = {date_to_timestamp(date): True for date in credits_debits.keys()}

    # gbp_fx_rates_by_timestamp :: timestamp => currency => gbp_exchange_rate
    gbp_fx_rates_by_timestamp = {}
    for price in gbp_fx_rates:
        _, date, from_currency, gbp_exchange_rate = price.split()
        timestamp = date_to_timestamp(date)
        all_timestamps[timestamp] = True
        gbp_exchange_rate = Decimal(gbp_exchange_rate[1:])

        new_rates = gbp_fx_rates_by_timestamp.get(timestamp, {})
        new_rates[from_currency] = gbp_exchange_rate
        gbp_fx_rates_by_timestamp[timestamp] = new_rates

    # fx_rates_by_timestamp :: timestamp => key => exchange_rate
    fx_rates_by_timestamp = {}
    gbp_fx_rates = {}
    for timestamp in sorted(all_timestamps.keys()):
        gbp_fx_rates = gbp_fx_rates_by_timestamp.get(timestamp, gbp_fx_rates)
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


def metric_hledger_balance(credits_debits):
    """`hledger_balance{account="xxx", currency="xxx"}`

    Accounts are propagated forward in time: if an account is seen at
    time T, then its balance will also be reported at time T+1, T+2,
    etc.
    """

    # deltas_by_timestamp :: timestamp => key => delta
    deltas_by_timestamp = {}
    for date, kcds in credits_debits.items():
        timestamp = date_to_timestamp(date)
        deltas_by_timestamp[timestamp] = {
            key: cd["debit"] - cd["credit"] for key, cd in kcds.items()
        }

    return pivot(running_totals(deltas_by_timestamp))


def metric_hledger_monthly_credits_debits(credits_debits, field):
    """`hledger_monthly_xxx{account="xxx", currency="xxx"}`

    Like `hledger_balance` but only sums the credits or debits (these
    are two separate metrics).  These are also grouped by calendar
    month, with all the transactions taking effect at midnight (UTC)
    on the 1st.

    This drops the last calendar month, so only complete months are
    present.
    """

    # deltas_by_timestamp :: timestamp => key => delta
    deltas_by_timestamp = {}
    for date, kcds in credits_debits.items():
        parsed = datetime.datetime.strptime(date, "%Y-%m-%d")
        timestamp = calendar.timegm(parsed.replace(day=1).timetuple()) * 1000

        deltas = deltas_by_timestamp.get(timestamp, {})
        for key, cd in kcds.items():
            deltas[key] = deltas.get(key, 0) + cd[field]
        deltas_by_timestamp[timestamp] = deltas

    del deltas_by_timestamp[max(deltas_by_timestamp.keys())]

    return pivot(deltas_by_timestamp)


def metric_hledger_age_of_money(credits_debits):
    """`hledger_age_of_money{account="xxx", currency="xxx"}`

    Gives the age (in days) of the oldest unit of money in that
    account.  Age is calculated by taking the net change of every day,
    if it's positive putting it in a new bucket, and if it's negative
    taking it from the oldest bucket.  The age is then the age of the
    oldest nonempty bucket.
    """

    # deltas_by_timestamp :: timestamp => key => delta
    deltas_by_timestamp = {}
    for date, kcds in credits_debits.items():
        timestamp = date_to_timestamp(date)
        deltas_by_timestamp[timestamp] = {
            key: cd["debit"] - cd["credit"] for key, cd in kcds.items()
        }

    # ages_by_timestamp :: timestamp => key => days
    ages_by_timestamp = {}
    buckets_by_key = {}
    ages = {}
    for timestamp in sorted(deltas_by_timestamp.keys()):
        for key, delta in deltas_by_timestamp[timestamp].items():
            ages[key] = ages.get(key, 0)
            buckets = buckets_by_key.get(key, [])
            if delta > 0:
                if len(buckets) == 0:
                    buckets = [(timestamp, delta)]
                else:
                    _, latest_value = buckets[-1]
                    buckets.append((timestamp, latest_value + delta))
            elif delta < 0:
                buckets = [
                    (timestamp, value + delta)
                    for timestamp, value in buckets
                    if value > -delta
                ]
            buckets_by_key[key] = buckets
        for key in list(ages.keys()):
            buckets = buckets_by_key[key]
            if len(buckets) == 0:
                ages[key] = 0
            else:
                first_timestamp, _ = buckets[0]
                ages[key] = int((timestamp - first_timestamp) / 86400000)
        ages_by_timestamp[timestamp] = {k: v for k, v in ages.items()}

    return pivot(ages_by_timestamp)


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


def metric_quantified_self_age(credits_debits):
    """`quantified_self_age{unit="{days|years}"}`"""

    # ages_by_timestamp :: timestamp => key => int
    ages_by_timestamp = {}
    for datestr in sorted(credits_debits.keys()):
        date = datetime.datetime.strptime(datestr, "%Y-%m-%d")
        timestamp = calendar.timegm(date.timetuple()) * 1000

        days = (date - DOB).days
        years = date.year - DOB.year
        if (date.month, date.day) < (DOB.month, DOB.day):
            years -= 1

        ages_by_timestamp[timestamp] = {
            (("unit", "days"),): days,
            (("unit", "years"),): years,
        }

    return pivot(ages_by_timestamp)


raw_prices = hledger_command(["prices"]).splitlines()
raw_postings = list(
    csv.DictReader(io.StringIO(hledger_command(["print", "-O", "csv"])))
)
credits_debits = preprocess_group_credits_debits(raw_postings)

metrics = {
    "hledger_fx_rate": metric_hledger_fx_rate(raw_prices, credits_debits),
    "hledger_balance": metric_hledger_balance(credits_debits),
    "hledger_monthly_increase": metric_hledger_monthly_credits_debits(
        credits_debits, "debit"
    ),
    "hledger_monthly_decrease": metric_hledger_monthly_credits_debits(
        credits_debits, "credit"
    ),
    "hledger_age_of_money": metric_hledger_age_of_money(credits_debits),
    "hledger_transactions_total": metric_hledger_transactions_total(raw_postings),
    "quantified_self_age": metric_quantified_self_age(credits_debits),
}

for name, values in metrics.items():
    if not DRY_RUN:
        requests.post(f"{PROMSCALE_URI}/delete_series?match[]={name}")

    for labels_tuples, samples in values.items():
        print(f"Uploading {name} {labels_tuples} ({len(samples)} samples)")

        labels = dict(labels_tuples)
        labels["__name__"] = name
        json = {"labels": labels, "samples": convert_samples(samples)}

        if DRY_RUN:
            print(json)
        else:
            requests.post(f"{PROMSCALE_URI}/write", json=json).raise_for_status()
