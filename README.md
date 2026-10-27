# Chromecast Remote

A universal Flutter remote for TVs on your local Wi-Fi network:

- **Google TV / Android TV** (Chromecast with Google TV, Google TV Streamer,
  Android TV devices) — full remote with D-pad navigation, OK, Back, Home,
  Power, volume, mute and assistant via **Android TV Remote Protocol v2**
  (TLS + Protocol Buffers, pairing ports 6467/6466).
- **Classic Chromecast** (gen 1–3, Ultra, other Cast receivers) — media
  session control (play/pause/seek/stop), receiver volume, and casting a
  direct media URL via the **Google Cast SDK**.

Both device types are discovered automatically on the local network and shown
in one list, labelled by the protocol they support.

## Features

- **Device discovery** — Find Chromecast and Google TV devices on the same Wi-Fi network.
- **Google TV remote** — Navigate using a D-pad, select, back and home buttons.
- **Media controls** — Play, pause, skip tracks, rewind and fast-forward in supported apps.
- **App shortcuts** — Launch TV apps (Netflix, YouTube, Spotify, Videoland, NPO Start, Prime Video, Disney+ and more) from the remote, with the active app highlighted when the TV reports it. Custom shortcuts (package name or deep link) can be added in the manage sheet.
- **Volume controls** — Adjust volume or mute the connected device.
- **Device pairing** — Pair with Google TV using the code displayed on your television.
- **Automatic reconnection** — Reconnect to previously paired devices.
- **Chromecast support** — Control supported Google Cast media sessions on older Chromecast devices.
- **Dark interface** — Simple remote layout inspired by physical TV remotes.
- **Phone and tablet layouts** — Compact phone controls and purpose-built
  tablet layouts with two-column remotes, larger targets and bounded content.
- **Accessible, state-driven interface** — Semantic status colors, clear
  recovery actions, immediate command feedback and reduced-motion support.

Some controls depend on the connected device and the application currently running on the TV.

## Supported Devices

| Device | Remote navigation | Media controls |
|---|---|---|
| Chromecast with Google TV (4K) | Yes | Yes |
| Chromecast with Google TV (HD) | Yes | Yes |
| Google TV Streamer | Yes | Yes |
| Compatible Android TV devices | Yes | Yes |
| Chromecast (1st–3rd generation) | No | Cast sessions |
| Chromecast Ultra | No | Cast sessions |

## Requirements

- Flutter 3.44 or later, Dart 3.12 or later
- Android Studio (Android builds) or Xcode (iOS builds)
- Phone and TV on the same Wi-Fi network (no guest network / client isolation)

## Setup

```sh
flutter pub get
```

For a fresh clone without generated platform folders, run
`flutter create --platforms=android,ios .` once before building. Keep the Cast
entries and the network permissions in the Android manifest when regenerating
platform files.

### Android permissions

`android/app/src/main/AndroidManifest.xml` declares `INTERNET`,
`ACCESS_NETWORK_STATE` and `CHANGE_WIFI_MULTICAST_STATE` (required for mDNS
discovery of `_androidtvremote2._tcp` services).

### iOS local network access

Add these entries inside the `<dict>` in `ios/Runner/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Chromecast Remote uses your local network to discover and control TVs.</string>
<key>NSBonjourServices</key>
<array>
    <string>_CC1AD845._googlecast._tcp</string>
    <string>_googlecast._tcp</string>
    <string>_androidtvremote2._tcp</string>
</array>
```

The Cast options provider and media notification service in the Android
manifest must be kept if you regenerate `android/`.

## Use the remote

1. Connect the phone and the TV to the same Wi-Fi network.
2. Open the app — devices appear automatically as they are discovered.
3. Tap a **Google TV / Android TV** device to pair: enter the 6-character
   hexadecimal code shown on the TV. Pairing is remembered; the app
   reconnects automatically next time.
4. Use the D-pad, Back, Home, Assistant, Power and volume controls.
5. The **Media** section sends standard Android media key events
   (Play/Pause 85, Stop 86, Next 87, Previous 88, Rewind 89, Fast Forward 90)
   to whichever app is in the foreground — YouTube, Spotify, Netflix, etc.
   Which keys an app honours varies per application.
6. Tap a **Google Cast** device for media playback control, receiver volume
   and casting a direct media link.

### Protocol notes

- Pairing implements the Google TV pairing protocol ("polo"): mutual TLS with
  an app-generated self-signed RSA-2048 client certificate, and a pairing
  secret derived as SHA-256 over both certificates' RSA public keys plus the
  on-screen code. The client certificate is generated once and stored in
  platform secure storage (Keychain / EncryptedSharedPreferences); the TV's
  certificate fingerprint is pinned after pairing and verified on reconnect.
- Google TV / Android TV uses TCP port 6467 for pairing and TCP port 6466
  for remote commands.
- Remote commands use the Android TV Remote Protocol v2 `RemoteMessage`
  protobuf messages (key inject, ping/pong keep-alive, configure/set-active
  handshake) — see `protos/`. Regenerate the Dart code with:
  `protoc --dart_out=lib/core/protocol/android_tv/proto -I protos protos/*.proto`
  (requires `protoc` and `dart pub global activate protoc_plugin`).
- A Google TV advertising both `_androidtvremote2._tcp` and `_googlecast._tcp`
  appears as two labelled entries; the protocols share no reliable identifier,
  so entries are never merged by name.

### Updates

The app checks GitHub Releases for a newer version. An update icon in the
Devices screen runs a manual check; a silent check also runs once at launch
and only speaks up when a newer release exists.

Publish a GitHub release with a tag like `v0.2.0` and attach the APK as a
release asset. On Android the app downloads the APK itself with a progress
indicator and hands it to the system package installer — Android still asks
the user to confirm the install and, once, to allow installs from this app.
The update APK must be signed with the same key as the installed app or
Android refuses the install. On releases without an APK asset (and on iOS)
the release page opens in the browser instead.

### Limitations

- Classic Chromecasts have **no system navigation** — the Cast SDK controls
  media sessions only. The app shows no D-pad for them.
- Media started by other apps can only be controlled when the receiver
  exposes a standard Cast media session.
- Power/volume depend on the TV's HDMI-CEC and audio configuration.
- Android TV Remote Protocol v2 does not report playback state, so the media
  section uses a combined Play/Pause toggle and shows no playback metadata.
  A transmitted key event is not guaranteed to be handled by the foreground
  app (e.g. Netflix ignores Next/Previous).
- The assistant button sends KEYCODE_SEARCH; voice audio streaming is not
  implemented.
- App shortcuts use direct app links to open installed apps without visiting
  the Play Store. Known package names in custom shortcuts use the same links,
  including previously saved shortcuts. Apps without a verified deep link
  (currently NPO Start and unknown custom packages) retain the
  `market://launch?id=<package>` fallback, which may require selecting Open
  in the Play Store even when installed. Custom deep links are preserved.
  Android TV Remote Protocol v2 cannot list installed apps, so shortcuts are
  chosen from a catalog or added manually.
- Google TV remote connectivity relies on a protocol that is not provided as a stable public remote-control SDK.

## Run

```sh
flutter run
```

## Validate

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Unit tests cover the varint framing codec, protobuf wire serialization, the
pairing-secret derivation (with a known-answer vector from the Python
reference implementation), certificate public-key extraction, and the paired
device store. Pairing and remote control themselves require a physical
Google TV / Chromecast on the same network and cannot be covered by automated
tests.

The app uses the default Google Cast receiver application ID.

## Built With

- Flutter
- Dart
- Android TV Remote Protocol v2
- Google Cast
- mDNS / DNS-SD
- Protocol Buffers

## Disclaimer

This is an independent project and is not affiliated with or endorsed by Google.

Chromecast, Google TV and Android TV are trademarks of Google LLC.

## License

See the `LICENSE` file for details.
