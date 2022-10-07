#!/usr/bin/env python3

"""MAGICAL BACKUP SCRIPT!

Copies directory structure, hardlink mapping, and un-hardlinked files.
As I only use hardlinks for torrents, this makes sense.
"""

import os
import shlex
import shutil
import sys

# Directory to generate the backup in.
TARGET = os.getcwd()

# Directories to back up.
BACKUP_DIRS = ["/mnt/nas"]

# Directories to mkdir, and then skip all children.  Do not end with a
# trailing "/".
SKIP_DIRS = ["/mnt/nas/images", "/mnt/nas/misc", "/mnt/nas/music"]

# Files to skip.
SKIP_FILES = []

# Where rtorrent downloads its files to.  End with a trailing "/".
TORRENT_FILES_DIR = "/mnt/nas/torrents/files/"


def sizeof(num, suffix='B'):
    """Turn a number of bytes into a human-friendly filesize.
    """

    for unit in ["", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi"]:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, "Yi", suffix)


def traverse(base, dirs, matches, stats, skip_dirs=[], skip_files=[]):
    """Traverse a directory hierarchy, recording directory names and
    file/inode mappings.

    Does not return anything, mutates 'dirs' (a list), 'matches' (a
    dict), and 'stats' (a dict).
    """

    for root, _, files in os.walk(base):
        skip = False
        for d in skip_dirs:
            skip = skip or f"{d}/" in root
        if skip:
            continue

        dirs.append(root)

        if root in skip_dirs:
            continue

        for fname in files:
            path = f"{root}/{fname}"

            if path in skip_files:
                continue

            try:
                info = os.stat(path)
                k = (info.st_dev, info.st_ino)
                sofar = matches.get(k, set())
                sofar.add(path)
                matches[k] = sofar
                stats[path] = info
            except FileNotFoundError:
                print(f"File {path} disappeared while being inspected")


def guesstimate_needed_space(matches, stats, target_dev=None):
    """Estimate how much free space is needed for the backup.

    Space to copy everything which can't be hardlinked * 4/3 for
    wiggle room.
    """

    copy_size = 0
    total_size = 0
    for match in matches.values():
        if len(match) == 1:
            path = match.copy().pop()
            if TORRENT_FILES_DIR in path:
                continue
            total_size += stats[path].st_size
            if not stats[path].st_dev == target_dev:
                copy_size += stats[path].st_size
    return total_size, int(copy_size * 4/3)


# traverse directories to find files
dirs = []
matches = {}
stats = {}
for to_backup in BACKUP_DIRS:
    traverse(to_backup, dirs, matches, stats, skip_dirs=SKIP_DIRS, skip_files=SKIP_FILES)

# check for free space
target_dev = os.stat(TARGET).st_dev
statvfs = os.statvfs(TARGET)
free_size = statvfs.f_frsize * statvfs.f_bavail
total_size, needed_size = guesstimate_needed_space(matches, stats, target_dev)
if free_size < needed_size:
    print("Not enough free space on device (needed {}, got {}), aborting...".format(sizeof(needed_size), sizeof(free_size)))
    sys.exit(2)

# create directory hierarchy
for root in dirs:
    os.makedirs(f"{TARGET}/{root}", exist_ok=True)

# copy files & generate hardlink script
progress = 0
with open(f"{TARGET}/make-hardlinks.sh", "w") as f:
    print("#!/bin/sh", file=f)
    print("", file=f)

    for match in matches.values():
        percentage = '[{:8.4f}%]'.format(progress / total_size * 100)
        if len(match) == 1:
            path = match.pop()
            # don't copy across unlinked torrent files
            if TORRENT_FILES_DIR in path:
                continue
            copy = os.link if stats[path].st_dev == target_dev else shutil.copy2
            print(f"{percentage} Copying {path}")
            copy(path, f"{TARGET}/{path}")
            progress += stats[path].st_size
        else:
            # if one of the files is in TORRENT_FILES_DIR, we want to
            # link to that; otherwise it doesn't matter.
            for target in match:
                if TORRENT_FILES_DIR in target:
                    break
            for link_name in match:
                if target == link_name:
                    continue
                print(f"{percentage} Linking {link_name}")
                print("ln {} {}".format(shlex.quote(target), shlex.quote(link_name)), file=f)
