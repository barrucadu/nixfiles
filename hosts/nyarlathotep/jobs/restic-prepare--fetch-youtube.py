#!/usr/bin/env python3

"""Youtube "backup" script - generates a script to download videos."""

import os
import shlex

SOURCE_DIR = "/mnt/nas/misc/youtube"
VIDEO_URL = "https://www.youtube.com/watch?v="

print("#!/bin/sh")
print("")

for dirpath, dirnames, filenames in os.walk(SOURCE_DIR, topdown=True):
    for dirname in dirnames:
        print(f"mkdir {shlex.quote(os.path.join(dirpath, dirname))}")
    for filename in filenames:
        # filenames are of the form "title [id].ext"
        name_pattern = filename.split("[")[-2] + "[%(id)s].%(ext)s"
        url = VIDEO_URL + filename.split("[")[-1].split("]")[0]
        print(
            f"yt-dlp -P {shlex.quote(dirpath)} -o {shlex.quote(name_pattern)} {shlex.quote(url)}",
        )
