#!/system/bin/sh
# Capture audio from all apps (Android 13+) and feed it to snapserver.
# The Snapcast app is excluded, so the host plays in sync through it.
# Run as root: su -c sh /data/data/com.termux/files/home/snapcapture.sh
T=/data/data/com.termux/files
JAR=/data/local/tmp/snapcap.jar
SNAPCAST_UID=$(stat -c %u /data/data/de.badaix.snapcast)
# stop file playback and any old capture
for p in $(ps -A -o pid,args | grep -E 'usr/bin/(ffmpeg|socat)|snapplay\.sh /|com\.genymobile\.scrcpy|SnapCap' | grep -v grep | awk '{print $1}'); do kill $p; done
sleep 1
cp $T/home/snapcap/snapcap.jar $JAR && chmod 644 $JAR
su 2000 -c "CLASSPATH=$JAR app_process / SnapCap $SNAPCAST_UID" 2> /data/local/tmp/snapcap.log \
  | su 10063 -g 10063 -c "cat > $T/usr/tmp/snapfifo" &
sleep 2
cat /data/local/tmp/snapcap.log
