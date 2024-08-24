#!/usr/bin/env python3

"""Torrent "backup" script - generates a script to create the directory
hierarchy and hardlink files.
"""

import os
import shlex
import sys

# Directories to link
MEDIA_DIRS = ["/mnt/nas/anime", "/mnt/nas/movies", "/mnt/nas/tv"]

# Where torrent files are downloaded to
TORRENT_FILES_DIR = "/mnt/nas/torrents/files"

# Where .torrent files are stored
TORRENT_WATCH_DIR = "/mnt/nas/torrents/watch"

# Only list unlinked files, don't generate a linking script
CHECK_ONLY = "--check" in sys.argv


def print_cmd(cmd):
    """Print a command, if not in checking mode."""

    if not CHECK_ONLY:
        print(cmd)


def file_ref(fpath):
    """Return a unique reference to the file, consistent across hardlinks."""

    info = os.stat(fpath)
    return (info.st_dev, info.st_ino)


def find_inodes(base):
    """Return the set of inodes under the given base directory."""

    inodes = dict()
    for root, _, files in os.walk(base):
        for fname in files:
            fpath = os.path.join(root, fname)
            inodes[file_ref(fpath)] = fpath
    return inodes


def traverse(base, inodes):
    """Print out `mkdir` and `ln` commands to rebuild the directory / file
    hierarchy under `base`, linking files to `inodes`.
    """

    for root, _, files in os.walk(base):
        print_cmd(f"mkdir {shlex.quote(root)}")
        for fname in files:
            fpath = os.path.join(root, fname)
            ref = file_ref(fpath)
            if ref in inodes:
                source_file = inodes[ref]
                print_cmd(f"ln {shlex.quote(source_file)} {shlex.quote(fpath)}")
            elif os.path.splitext(fpath)[-1] == ".torrent":
                source_file = os.path.join(TORRENT_WATCH_DIR, fname)
                print_cmd(f"cp {shlex.quote(source_file)} {shlex.quote(fpath)}")
            else:
                print(f"Unknown path {fpath}", file=sys.stderr)


inodes = find_inodes(TORRENT_FILES_DIR)
for media_dir in MEDIA_DIRS:
    traverse(media_dir, inodes)
