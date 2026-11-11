#!/system/bin/sh
# Shared helpers for service.sh and action.sh. Source with: . $MODDIR/common.sh
T=/data/data/com.termux/files
JAR=/data/local/tmp/snapcap.jar
LOG=/data/local/tmp/snapparty.log

pids() {
  ps -A -o pid,args | grep -E "$1" | grep -v grep | awk '{print $1}'
}

server_running() { [ -n "$(pids 'usr/bin/snapserver')" ]; }
capture_running() { [ -n "$(pids 'app_process / SnapCap')" ]; }

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
  cp $MODDIR/snapcap.jar $JAR && chmod 644 $JAR
  setsid sh -c "su 2000 -c 'CLASSPATH=$JAR app_process / SnapCap $snapcast_uid' 2> /data/local/tmp/snapcap.log \
    | su $uid -g $uid -c 'cat > $T/usr/tmp/snapfifo'" < /dev/null > /dev/null 2>&1 &
}

capture_stop() {
  kill $(pids 'app_process / SnapCap|cat > .*usr/tmp/snapfifo') 2>/dev/null
}

# IPs friends can use: Wi-Fi and hotspot interfaces only
share_ips() {
  ip -4 -o addr | awk '$2 ~ /^(wlan|swlan|ap|softap)/ {split($4, a, "/"); print a[1] " (" $2 ")"}'
}

# True when the Snapcast app on this phone is connected to the local server
host_client_connected() {
  local peers ip
  peers=$(ss -tn state established '( sport = :1704 )' 2>/dev/null | tail -n +2 | awk '{print $NF}')
  [ -z "$peers" ] && return 1
  for ip in 127.0.0.1 $(ip -4 -o addr | awk '{split($4, a, "/"); print a[1]}'); do
    echo "$peers" | grep -qF "$ip]:" && return 0
    echo "$peers" | grep -qE "^$ip:" && return 0
  done
  return 1
}
