#!/data/data/com.termux/files/usr/bin/sh
# Start snapserver on the host phone (uses $PREFIX/etc/snapserver.conf).
pkill -x snapserver
setsid nohup snapserver > "$HOME/snapserver.log" 2>&1 < /dev/null &
sleep 2
pgrep -a snapserver
tail -3 "$HOME/snapserver.log"
