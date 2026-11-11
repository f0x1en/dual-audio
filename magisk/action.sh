#!/system/bin/sh
# Magisk Action button: toggle party mode.
# ON:  start snapserver (Termux package snapcast-server) and SnapCap.
# OFF: stop both, so the phone plays audio normally again.
MODDIR=${0%/*}
T=/data/data/com.termux/files
LABEL=$(ls -Zd $T/home | awk '{print $1}')
TERMUX_UID=$(stat -c %u $T)
SNAPCAST_UID=$(stat -c %u /data/data/de.badaix.snapcast 2>/dev/null)
JAR=/data/local/tmp/snapcap.jar

pids() {
  ps -A -o pid,args | grep -E "$1" | grep -v grep | awk '{print $1}'
}

as_termux() {
  su $TERMUX_UID -g $TERMUX_UID -G 3003 -c "export PREFIX=$T/usr HOME=$T/home PATH=$T/usr/bin TMPDIR=$T/usr/tmp LD_PRELOAD=$T/usr/lib/libtermux-exec.so; $1"
}

if [ -n "$(pids 'app_process / SnapCap')" ]; then
  kill $(pids 'app_process / SnapCap|usr/tmp/snapfifo|usr/bin/snapserver') 2>/dev/null
  echo "Party mode OFF"
  exit 0
fi

if [ ! -x $T/usr/bin/snapserver ]; then
  echo "snapserver missing. In Termux run: pkg install snapcast-server"
  exit 1
fi
if [ -z "$SNAPCAST_UID" ]; then
  echo "Snapcast app (de.badaix.snapcast) not installed"
  exit 1
fi

as_termux "setsid snapserver > $T/home/snapserver.log 2>&1 < /dev/null &"
for i in 1 2 3 4 5; do [ -p $T/usr/tmp/snapfifo ] && break; sleep 1; done
# files made from here carry the wrong SELinux label for the Termux app
chcon $LABEL $T/usr/tmp/snapfifo $T/home/snapserver.log 2>/dev/null

cp $MODDIR/snapcap.jar $JAR && chmod 644 $JAR
setsid sh -c "su 2000 -c 'CLASSPATH=$JAR app_process / SnapCap $SNAPCAST_UID' 2> /data/local/tmp/snapcap.log \
  | su $TERMUX_UID -g $TERMUX_UID -c 'cat > $T/usr/tmp/snapfifo'" < /dev/null > /dev/null 2>&1 &
sleep 2

if [ -z "$(pids 'app_process / SnapCap')" ]; then
  echo "SnapCap failed:"
  cat /data/local/tmp/snapcap.log
  exit 1
fi
echo "Party mode ON"
echo "Open Snapcast on every phone and connect to:"
ip -4 -o addr | awk '$2 != "lo" {split($4, a, "/"); print "  " a[1] " (" $2 ")"}'
