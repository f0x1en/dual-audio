#!/bin/sh
# Pack the Magisk module zip. Pulls snapcap.jar built on the phone (snapcap/build.sh).
set -e
cd "$(dirname "$0")"
adb shell su -c cat /data/data/com.termux/files/home/snapcap/snapcap.jar > snapcap.jar
rm -f ../snapparty.zip
zip -qr ../snapparty.zip module.prop action.sh snapcap.jar META-INF
echo "built: $(cd .. && pwd)/snapparty.zip"
