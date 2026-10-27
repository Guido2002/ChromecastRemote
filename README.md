# Chromecast Remote

A Flutter remote control app for Chromecast and Google TV devices.

The app lets you discover compatible devices on your local network and control them directly from your phone. Google TV devices support navigation through a virtual remote, while older Chromecast devices use Google Cast media controls.

## Features

- **Device discovery** — Find Chromecast and Google TV devices on the same Wi-Fi network.
- **Google TV remote** — Navigate using a D-pad, select, back and home buttons.
- **Media controls** — Play, pause, skip tracks, rewind and fast-forward in supported apps.
- **Volume controls** — Adjust volume or mute the connected device.
- **Device pairing** — Pair with Google TV using the code displayed on your television.
- **Automatic reconnection** — Reconnect to previously paired devices.
- **Chromecast support** — Control supported Google Cast media sessions on older Chromecast devices.
- **Dark interface** — Simple remote layout inspired by physical TV remotes.

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

## Getting Started

Make sure Flutter is installed and configured.

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

Your phone and Chromecast or Google TV device must be connected to the same local network.

## How It Works

The app uses two different protocols depending on the device.

**Google TV / Android TV**

Uses Android TV Remote Protocol v2 for pairing and sending remote commands over a local network connection.

- TCP 6467 — Pairing
- TCP 6466 — Remote commands

**Classic Chromecast**

Uses Google Cast for device discovery, media sessions and supported playback controls.

Classic Chromecast devices do not support system-wide navigation through the Android TV remote protocol.

## Limitations

- Media commands depend on the application running on the TV.
- Not every streaming app supports all playback controls.
- Current media metadata and playback progress are not universally available through Android TV Remote v2.
- Power and volume functionality can depend on TV and HDMI-CEC configuration.
- Google TV remote connectivity relies on a protocol that is not provided as a stable public remote-control SDK.

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
