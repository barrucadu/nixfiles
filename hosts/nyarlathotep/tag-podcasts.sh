#!/usr/bin/env bash

for mp3file in */in/*.mp3; do
  dir="$(echo "$mp3file" | sed 's:/in/.*::')"
  f="$(basename "$mp3file")"

  artist="$(echo "$dir" | sed 's: - .*::')"
  album="$(echo "$dir" | sed 's:.* - ::')"

  if [[ -z "$album" ]]; then
    album="$artist"
  fi

  n="$(echo "$f" | sed 's:\..*::')"
  track="$(echo "$f" | sed 's:^[0-9]*\. \(.*\)\.mp3:\1:')"

  echo "===== $mp3file" >&2
  echo $artist >&2
  echo $album >&2
  echo $n >&2
  echo $track >&2
  echo "$(echo "$mp3file" | sed 's:/in/:/:')" >&2
  echo >&2

  id3v2 -D "$mp3file"
  id3v2 -2 --song   "$track"  "$mp3file"
  id3v2 -2 --track  "$n"      "$mp3file"
  id3v2 -2 --artist "$artist" "$mp3file"
  id3v2 -2 --album  "$album"  "$mp3file"
  mv "$mp3file" "$(echo "$mp3file" | sed 's:/in/:/:')"
done

# this can't be done as a systemd path unit because it doesn't seem to
# support multiple *s in a pattern
inotifywait --recursive --timeout 3600 --include '/mnt/nas/music/Podcasts/.*/in/.*\.mp3' $(pwd) >&2

# this script is run in a loop by systemd.
