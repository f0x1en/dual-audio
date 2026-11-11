#!/system/bin/sh
# Runs at boot. Keeps snapserver up and turns capture on while the Snapcast
# app on this phone is connected, off otherwise (so normal audio is untouched).
MODDIR=${0%/*}
. $MODDIR/common.sh

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
# Termux data is readable only after the first unlock
until [ -x $T/usr/bin/snapserver ]; do sleep 5; done

echo "$(date) snapparty started" > $LOG
while true; do
  if ! server_running; then
    echo "$(date) starting snapserver" >> $LOG
    server_start
  fi
  if host_client_connected; then
    if ! capture_running; then
      echo "$(date) host Snapcast connected: capture on" >> $LOG
      capture_start
    fi
  elif capture_running; then
    echo "$(date) host Snapcast gone: capture off" >> $LOG
    capture_stop
  fi
  sleep 3
done
