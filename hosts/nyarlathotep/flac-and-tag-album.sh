#!/usr/bin/env bash

set -e

for artist in *; do
  if [[ -d $artist ]]; then
    pushd $artist
    for album in *; do
      if [[ -d $album ]]; then
        echo "===== $artist - $album" >&2
        pushd $album
        if [[ ! -e "$artist - $album.log" ]]; then
          echo "(missing log file)" >&2
        fi
        if [[ ! -e "cover.jpg" ]] && [[ ! -e "cover.png" ]] && [[ ! -e "cover.gif" ]]; then
          echo "(missing cover file)" >&2
        fi
        flac *.wav
        rm *.wav
        for flacfile in *.flac; do
          n="$(echo "$flacfile" | sed 's:\..*::')"
          track="$(echo "$flacfile" | sed 's:^[0-9]*\. \(.*\)\.flac:\1:')"
          metaflac --set-tag="tracknumber=$n" "$flacfile"
          metaflac --set-tag="title=$track"   "$flacfile"
          metaflac --set-tag="artist=$artist" "$flacfile"
          metaflac --set-tag="album=$album"   "$flacfile"
        done
        popd
        echo
        mv $album "../../out/$artist - $album"
      fi
    done
    popd
    rmdir $artist
  fi
done
