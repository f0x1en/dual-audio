#!/data/data/com.termux/files/usr/bin/sh
# Build snapcap.jar in Termux on the phone.
# Needs: pkg install openjdk-21 d8 dex2jar
# Compiles against the phone's own framework (real Android API, hidden calls included).
set -e
cd "$(dirname "$0")"
[ -f fw-classes.jar ] || d2j-dex2jar -f -o fw-classes.jar /system/framework/framework.jar
rm -rf classes stub-classes && mkdir classes stub-classes
javac --release 11 -d stub-classes stubs/android/os/Parcelable.java
javac --release 11 -cp stub-classes:fw-classes.jar -d classes SnapCap.java
d8 --min-api 33 --classpath fw-classes.jar --output snapcap.jar classes/*.class
echo "built: $(pwd)/snapcap.jar"
