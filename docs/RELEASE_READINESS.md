# Release readiness and verification boundaries

## Android signing

Release builds now use `android/key.properties` and an explicit release signing configuration. There is no automatic fallback to a newly generated debug key. A template is provided at `android/key.properties.example`.

For this workspace, the existing signing identity was imported into a PKCS12 keystore with a random password. Its certificate was preserved so updates can retain the installed application's data. The source identity originated from the earlier development signing configuration; this is not a certificate rotation or a claim of Play Store enrollment.

Local private files:

- `~/.local/share/chromecast-remote/signing/release.p12`
- `android/key.properties`

These files are excluded from Git. The signing directory and files have restrictive permissions. Back up the keystore and its properties securely before relying on future release builds. Never upload the properties or keystore as release assets.

A clean clone needs the matching private signing configuration to produce compatible releases. Changing the application ID or signing certificate can prevent in-place updates and lose access to saved pairings.

## iOS project

The repository now includes an iOS 15 project, branded icon assets, local-network and Bonjour declarations, a Cast capability bridge, and a CocoaPods configuration. Flutter plugins are registered through the generated engine integration.

This machine has only Apple command-line tools, not Xcode. No iOS binary, archive, signing validation, simulator run, or App Store distribution is claimed. On a Mac with Xcode:

```sh
flutter pub get
cd ios
pod install
cd ..
flutter build ios --no-codesign
```

Then configure the bundle identifier and development team, verify plugin integration, and test Bonjour permissions, Cast, secure storage, keyboard input, lifecycle behavior, and VoiceOver on supported iOS devices. Swift Package Manager compatibility also needs verification in Xcode; CocoaPods is provided as an alternative integration path.

## Features requiring hardware checks

The Android software release includes the implemented keyboard preview, Cast capability checks, live seek boundaries, reported TV state, per-TV control setup, eyes-up mode, room suggestions, destination templates, optional Home Assistant routines, and local diagnostics.

These features have automated coverage and Android build verification. They do not establish compatibility with every television or app.

- Keyboard: validate field changes, field dismissal, repeated requests, Unicode, and sensitive inputs on physical TVs. This remains explicit-send preview functionality, not a synchronized TV editor.
- Cast: verify pause/seek flags, live windows, external volume changes, reconnect, and stopping playback on physical receivers.
- Reporting: values are labeled as reported; old values are marked Last report and disconnected sessions clear them. Do not treat these as guaranteed live measurements.
- Household setup: preferences reflect user confirmation, not automatic discovery of the HDMI/audio configuration.
- Rooms: suggestions use manually assigned rooms, discovery, and recency. No physical room sensing or automatic commands are implemented or claimed.
- Destinations: YouTube and Spotify templates normalize supported public link formats. A TV app can still reject a link; foreground app confirmation does not prove that content played.
- Routines: Home Assistant is optional and requires a user-configured server and token. Volume is checked before app launch; failures and cancellation can leave an already-applied volume change. There are no blind key macros or automatic background routines.
- Accessibility: automated D-pad target size, label, contrast, and distinct semantic-bound checks pass. Complete TalkBack/VoiceOver and motor-accessibility validation remains a human/device task.

## Measurements

Settings contains Local measurements. It keeps up to 100 samples in memory for first frame, connection attempts, and command request dispatch. Samples contain no TV identifiers, text, URLs, or credentials and are not uploaded. Copying the summary is explicit. Request dispatch is not TV response or execution latency.

Emulator cold-start and in-place update observations are recorded with release verification. An emulator is not a substitute for a physical-device performance or compatibility study.

## Release gates

Before publishing an Android APK:

1. Run static analysis, the complete test suite, and the release build.
2. Verify package identity, version code, APK signature, and signing continuity against the last published APK.
3. Verify an in-place install and retained application preferences where a test device is available.
4. Attach the APK, checksum, release notes, and explicit compatibility boundaries.
5. Push source and a version tag matching the release artifact.

A production quality claim still requires the physical-device and user validation above. The release notes must not mark those tasks complete without evidence.

## v0.11.0 release verification

On 29 October 2026, static analysis was clean and all 128 automated tests passed. Both Android build variants succeeded. The release APK reports `com.example.chromecast_remote`, version `0.11.0`, code `13`, and its signing certificate matches v0.10.0.

An Android API 37 phone emulator installed v0.10.0, saved a harmless custom destination as a favorite, then installed v0.11.0 with `adb install -r` without uninstalling. Both the destination and selected favorite survived and rendered in Apps. No commands were sent to physical TVs during this check.

Three valid force-stopped v0.11.0 emulator launches reported Android Activity `TotalTime` values of 591, 617 and 592 milliseconds (`am start -W`). These are Activity display observations, not connection readiness or TV response latency. Early zero-time results from back-to-back starts were rejected and rerun with the stop allowed to settle. Earlier v0.10.0 observations were 2468, 1868 and 1427 milliseconds under different emulator warm-up conditions; the runs are not controlled comparative evidence and no speedup is claimed.

Artifact: `ChromecastRemote-v0.11.0.apk`, 61,791,914 bytes.

SHA-256: `fc75b9f92a9962f54d433719ccb8a75b7f47eb414c792739c1bb499752760ab2`.

## v0.12.0 release verification

On 29 October 2026, static analysis reported no issues and all 146 automated tests passed. Android debug and signed release APK builds passed. The release retains `com.example.chromecast_remote`, reports version `0.12.0`, code `14`, and its APK signature/certificate matches the published v0.11.0 artifact.

An Android API 37 emulator updated from v0.11.0 using `adb install -r` without uninstalling. A saved custom destination and its selected favorite status survived and rendered in Apps. The installed package reports version 0.12.0/build 14. Microphone permission remains ungranted until requested; no audio capture or commands to physical TVs were exercised during release verification.

Voice search, Smart Now Playing and haptics are included; [feature verification and boundaries](VOICE_AND_NOW_PLAYING.md) describe the automated checks and outstanding physical-TV/iOS work. No iOS binary is distributed.

Artifact: `ChromecastRemote-v0.12.0.apk`, 62,022,178 bytes.

SHA-256: `a0d022c85e6aefb2e3f807a534a5db280e1a77644f020fb7ef8456510ceaf306`.
