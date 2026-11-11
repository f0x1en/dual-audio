#!/system/bin/sh
# Magisk Action button: toggle capture of all app audio.
MODDIR=${0%/*}
. $MODDIR/common.sh

if capture_running; then
  capture_stop
  echo "$(date) capture off" >> $LOG
  echo "Capture OFF. This phone plays audio normally."
  exit 0
fi

if [ ! -x $T/usr/bin/snapserver ]; then
  echo "snapserver missing. In Termux run: pkg install snapcast-server"
  exit 1
fi
server_running || server_start
advertise_running || advertise_start
[ -f $T/usr/share/snapserver/snapweb/snapcast.apk ] || publish_apk
capture_start
sleep 2
if ! capture_running; then
  echo "Capture failed:"
  cat /data/local/tmp/snapcap.log
  exit 1
fi
echo "$(date) capture on" >> $LOG
echo "Capture ON."
echo "Open Snapcast on every phone. New phones find this host by themselves."
echo "A phone that used another network before: open its server settings,"
echo "wait for the address to fill in, tap OK. Or type:"
share_ips | sed 's/^/  /'
if [ -f $T/usr/share/snapserver/snapweb/snapcast.apk ]; then
  echo
  echo "Friends without the Snapcast app: open in the browser"
  share_ips | awk '{print "  http://" $1 ":1780/snapcast.apk"}'
fi
