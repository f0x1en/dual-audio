#!/system/bin/sh
# Shared helpers for service.sh and action.sh. Source with: . $MODDIR/common.sh
T=/data/data/com.termux/files
JAR=/data/local/tmp/snapcap.jar
LOG=/data/local/tmp/snapcast-host.log

pids() {
  ps -A -o pid,args | grep -E "$1" | grep -v grep | awk '{print $1}'
}

server_running() { [ -n "$(pids 'usr/bin/snapserver')" ]; }
capture_running() { [ -n "$(pids 'app_process / SnapCap [0-9]')" ]; }
advertise_running() { [ -n "$(pids 'app_process / SnapCap advertise')" ]; }

server_start() {
  local uid label
  uid=$(stat -c %u $T)
  label=$(ls -Zd $T/home | awk '{print $1}')
  # Android blocks the network of idle background apps, Termux included
  cmd deviceidle whitelist +com.termux > /dev/null
  am set-inactive com.termux false
  su $uid -g $uid -G 3003 -c "export PREFIX=$T/usr HOME=$T/home PATH=$T/usr/bin TMPDIR=$T/usr/tmp LD_PRELOAD=$T/usr/lib/libtermux-exec.so; setsid snapserver > $T/home/snapserver.log 2>&1 < /dev/null &"
  for i in 1 2 3 4 5; do [ -p $T/usr/tmp/snapfifo ] && break; sleep 1; done
  # files made here carry the wrong SELinux label for the Termux app
  chcon $label $T/usr/tmp/snapfifo $T/home/snapserver.log 2>/dev/null
}

capture_start() {
  local uid snapcast_uid
  uid=$(stat -c %u $T)
  snapcast_uid=$(stat -c %u /data/data/de.badaix.snapcast)
  setsid sh -c "su 2000 -c 'CLASSPATH=$JAR app_process / SnapCap $snapcast_uid' 2> /data/local/tmp/snapcap.log \
    | su $uid -g $uid -c 'cat > $T/usr/tmp/snapfifo'" < /dev/null > /dev/null 2>&1 &
}

capture_stop() {
  kill $(pids 'app_process / SnapCap [0-9]|cat > .*usr/tmp/snapfifo') 2>/dev/null
}

# Announce the server via mDNS so Snapcast apps find it without an IP
advertise_start() {
  cp $MODDIR/snapcap.jar $JAR && chmod 644 $JAR
  setsid su 2000 -c "CLASSPATH=$JAR app_process / SnapCap advertise 1704" > /data/local/tmp/snapadvertise.log 2>&1 < /dev/null &
}

# Serve the installed Snapcast app at http://<host-ip>:1780/snapcast.apk,
# so friends on the same network can install it from their browser.
publish_apk() {
  local apks www uid
  www=$T/usr/share/snapserver/snapweb
  apks=$(pm path de.badaix.snapcast | sed 's/^package://')
  if [ "$(echo "$apks" | wc -l)" != 1 ]; then
    echo "$(date) Snapcast is a split APK, not published" >> $LOG
    return 1
  fi
  uid=$(stat -c %u $T)
  cp "$apks" $www/snapcast.apk
  chown $uid:$uid $www/snapcast.apk
  chcon $(ls -Zd $www | awk '{print $1}') $www/snapcast.apk
}

# IPs friends can use: Wi-Fi and hotspot interfaces only
share_ips() {
  ip -4 -o addr | awk '$2 ~ /^(wlan|swlan|ap|softap)/ {split($4, a, "/"); print a[1] " (" $2 ")"}'
}
