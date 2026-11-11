#!/system/bin/sh
# Runs once at boot: start snapserver and its mDNS announcement.
# Party mode (audio capture) is switched with the Action button.
MODDIR=${0%/*}
. $MODDIR/common.sh

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
# Termux data is readable only after the first unlock
until [ -x $T/usr/bin/snapserver ]; do sleep 5; done

echo "$(date) boot: starting snapserver and announcement" > $LOG
server_running || server_start
advertise_running || advertise_start
