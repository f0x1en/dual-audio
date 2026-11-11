#!/data/data/com.termux/files/usr/bin/sh
# Play files or folders into the snapserver pipe, one after another.
# Usage: ./snapplay.sh /sdcard/Music/song.mp3 /sdcard/Music/Telegram
FIFO="$PREFIX/tmp/snapfifo"
for arg in "$@"; do
  if [ -d "$arg" ]; then
    find "$arg" -type f -not -path '*/.*' \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.ogg' -o -iname '*.wav' \) | sort
  else
    echo "$arg"
  fi
done | while IFS= read -r f; do
  echo "playing: $f"
  ffmpeg -nostdin -loglevel error -i "$f" -f s16le -ar 48000 -ac 2 -y "$FIFO"
done
