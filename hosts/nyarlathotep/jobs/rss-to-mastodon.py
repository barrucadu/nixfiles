#!/usr/bin/env python3

"""RSS-to-Mastodon (or Pleroma)

Requires the API_KEY environment variable to be set.

Usage:
  rss-to-mastodon [--dry-run] -d <domain> -f <feed-url> -l <history-file> [-e <entries>] [-v <visibility>]

Options:
  --dry-run          just print what would be published
  -d <domain>        api domain
  -f <feed-url>      rss feed URL
  -l <history-file>  file to log feed item IDs to (to prevent double-posting)
  -e <entries>       maximum number of entries to post [default: 1]
  -v <visibility>    visibility of entries [default: public]
"""

import docopt
import feedparser
import html.parser
import http.client
import os
import pathlib
import requests
import sys
import time

args = docopt.docopt(__doc__)
dry_run = args["--dry-run"]
api_domain = args["-d"]
feed_url = args["-f"]
history_file = pathlib.Path(args["-l"])
entries = int(args["-e"])
visibility = args["-v"]

if not dry_run:
    api_token = os.getenv("API_KEY")
    if api_token is None:
        print("missing API key", file=sys.stderr)
        sys.exit(1)

attempts = 0
feed = None
while attempts < 5:
    # tumblr seems to often just drop connections with the default feedparser
    # user agent, so let's pretend to be curl
    try:
        feed = feedparser.parse(feed_url, agent="curl/7.54.1")
        break
    except http.client.RemoteDisconnected:
        print(f"failed to download feed - attempt {attempts}", file=sys.stderr)
        attempts += 1
        time.sleep(2)

if feed is None:
    print("could not download feed", file=sys.stderr)
    sys.exit(1)

# will crash if the file doesn't exist - but that's probably a good failsafe to
# prevent the same post being spammed if the log file gets accidentally deleted
history = history_file.read_text().split()
items = [entry for entry in feed["items"][:entries] if entry["id"] not in history]

# if there are multiple items, post the older ones first
for item in reversed(items):
    # handle entities
    title = html.parser.unescape(item["title"])

    print(item["id"])
    print(title)
    print()

    if dry_run:
        continue

    requests.post(
        f"{api_domain}/api/v1/statuses",
        headers={
            "Authorization": f"Bearer {api_token}",
            "Idempotency-Key": item["id"],
        },
        json={
            "status": title,
            "visibility": visibility,
        },
    ).raise_for_status()

    # yes, this is inefficient - but the file will have a few hundred entries in
    # it at most
    history.append(item["id"])
    history_file.write_text("\n".join(history))
