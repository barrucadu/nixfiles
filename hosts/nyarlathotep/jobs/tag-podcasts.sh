#!/usr/bin/env bash

set -e

sleep 60

for m4afile in */in/*.m4a; do
  if [[ ! -f "$m4afile" ]]; then
    break
  fi

  bitrate=$(ffprobe -v quiet -of flat=s=_ -show_entries format=bit_rate "${m4afile}" | sed 's/[^0-9]*//g')
  destination="$(echo "$m4afile" | sed 's:m4a$:mp3:')"
  echo "m4a: ${m4afile} -> ${destination}" >&2
  ffmpeg -y -i "$m4afile" -codec:a libmp3lame -b:a "$bitrate" -q:a 2 "$destination"
  rm "$m4afile"
done

for mp3file in */in/*.mp3; do
  if [[ ! -f "$mp3file" ]]; then
    break
  fi

  dir="$(echo "$mp3file" | sed 's:/in/.*::')"
  f="$(basename "$mp3file")"

  artist="$(echo "$dir" | sed 's: - .*::')"
  album="$(echo "$dir" | sed 's:.* - ::')"

  if [[ -z "$album" ]]; then
    album="$artist"
  fi

  n="$(echo "$f" | sed 's:\..*::')"
  track="$(echo "$f" | sed 's:^[0-9]*\. \(.*\)\.mp3:\1:')"
  destination="$(echo "$mp3file" | sed 's:/in/:/:')"

  echo "===== $mp3file" >&2
  echo "$artist" >&2
  echo "$album" >&2
  echo "$n" >&2
  echo "$track" >&2
  echo "$destination" >&2
  echo >&2

  id3v2 -D "$mp3file"
  id3v2 -2 --song   "$track"  "$mp3file"
  id3v2 -2 --track  "$n"      "$mp3file"
  id3v2 -2 --artist "$artist" "$mp3file"
  id3v2 -2 --album  "$album"  "$mp3file"
  mv "$mp3file" "$destination"
done

# this can't be done as a systemd path unit because it doesn't seem to
# support multiple *s in a pattern
inotifywait --recursive --timeout 3600 --include '/mnt/nas/music/Podcasts/.*/in/.*\.mp3' "$(pwd)" &>/dev/null

# this script is run in a loop by systemd.
