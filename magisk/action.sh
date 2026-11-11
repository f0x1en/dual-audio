#!/system/bin/sh
# Magisk Action button: show status. Party mode itself is automatic (service.sh).
MODDIR=${0%/*}
. $MODDIR/common.sh

if server_running; then echo "Server: running"; else echo "Server: not running (see $LOG)"; fi
if capture_running; then
  echo "Party mode: ON (host Snapcast connected)"
else
  echo "Party mode: OFF. Open Snapcast on this phone and press play to start."
fi
echo
echo "Friends connect Snapcast to:"
share_ips | sed 's/^/  /'
echo
echo "Last events:"
tail -3 $LOG 2>/dev/null | sed 's/^/  /'
