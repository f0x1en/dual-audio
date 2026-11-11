# dual-audio

Play the same audio on several phones at once, in sync, to make it louder.

One rooted Android phone is the host. It captures the audio of any app (Spotify, YouTube, a local player) and serves it with [Snapcast](https://github.com/badaix/snapcast). The other phones, and the host itself, play it through the Snapcast Android app. Snapcast keeps every client in sync continuously, so playback does not drift over time.

## How it works

- **snapserver** runs on the host in Termux (`pkg install snapcast-server`) and reads raw PCM from a pipe.
- **SnapCap** (`snapcap/SnapCap.java`) is a small `app_process` program that runs as the shell user. It uses Android's audio policy API to capture media audio from all apps and writes it to snapserver's pipe.
  - The Snapcast app is excluded from the capture, so the host plays the stream itself, in sync with everyone else, without an echo loop.
  - Captured apps are muted on the host. You only hear them through Snapcast.
- **SnapCap advertise** announces the server via mDNS (`_snapcast._tcp`), so Snapcast apps find the host on Wi-Fi or on the host's hotspot without typing an IP.
- A **Magisk module** (`magisk/`) starts snapserver and the announcement at boot. Its Action button switches the capture on and off.

## Requirements

**Host phone**
- Android 13 or newer, rooted with Magisk
- [Termux](https://f-droid.org/packages/com.termux/) with `snapcast-server` and `darkhttpd`
- [Snapcast](https://github.com/badaix/snapdroid) app (`de.badaix.snapcast`)

**Other phones**
- Snapcast app. No root needed.

**Build machine**
- `adb` and `zip`

## Build

SnapCap is built on the host phone, against the phone's own framework, so no Android SDK is needed.

1. In Termux on the host:
   ```sh
   pkg install snapcast-server darkhttpd openjdk-21 d8 dex2jar
   ```
2. Copy the `snapcap/` folder to `~/snapcap` in Termux, then run:
   ```sh
   ~/snapcap/build.sh
   ```
   This writes `~/snapcap/snapcap.jar`.
3. On the computer, with the phone connected over adb:
   ```sh
   magisk/pack.sh
   ```
   This pulls the jar and writes `snapcast-host.zip`.
4. Install `snapcast-host.zip` in the Magisk app (Modules, Install from storage), then reboot.

## Use

1. Unlock the host after boot. snapserver starts by itself.
2. In Magisk, open Modules and tap **Action** on **Snapcast Host**. Capture is now on, and the output shows the host's IP.
3. Open Snapcast on the host and on every other phone, then press play.
   - A phone that never connected before finds the host by itself.
   - A phone that connected on another network before: open its server settings, wait for the address to fill in, tap OK.
   - A phone without the Snapcast app: open `http://<host-ip>:1781/snapcast.apk` in its browser and install it. The host serves its own installed copy with darkhttpd. The Action output shows the full link.
4. Play music in any app on the host.
5. Tap **Action** again to turn capture off. The host then plays audio normally.

To fix a small constant offset between phones, set the latency per phone in the web UI at `http://<host-ip>:1780`.

## Notes

- Apps that opt out of audio capture are not captured.
- After switching networks, the Snapcast app keeps the old server address until you open its server settings.
- Starting the server makes Termux exempt from battery optimization, because Android blocks the network of idle background apps.
- `snapcap/snapcapture.sh`, `snaphost.sh` and `snapplay.sh` are manual Termux scripts from before the Magisk module. `snapplay.sh` plays files into the pipe instead of capturing.

## Credits

- [Snapcast](https://github.com/badaix/snapcast) by Johannes Pohl (GPL-3.0). It is not included here, only used.
- The audio capture and fake-context approach in SnapCap is adapted from [scrcpy](https://github.com/Genymobile/scrcpy) (Apache-2.0).

## License

[Apache-2.0](LICENSE)
