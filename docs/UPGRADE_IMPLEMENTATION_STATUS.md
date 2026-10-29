# Upgrade implementation status

Date: 29 October 2026

Release: **v0.11.0, Android build 13**. This tracks [the upgrade plan](APP_UPGRADE_PLAN.md). All proposed feature areas now have software implementations, including explicitly limited experimental features. Physical-device validation, user research, and iOS build verification remain open; they are not completed by an Android release.

See [release notes](releases/v0.11.0.md), [release readiness](RELEASE_READINESS.md), and [keyboard preview](KEYBOARD_PREVIEW.md).

## Added in v0.11.0

| Area | Delivered behavior | Evidence and limits |
|---|---|---|
| F03 keyboard | Explicit Send and separate Enter; masked drafts; session tokens; clears on app/field/connection/background changes; Unicode batch editing | Protocol, local TLS, privacy, and widget tests. Preview; no text mirroring, cursor synchronization, or physical-TV compatibility claim |
| F06 eyes-up mode | Per-TV larger directional pad and hidden favorites, selected in control setup | Responsive widget checks and visual captures; accidental presses and glance frequency require user testing |
| F07 household setup | Per-TV room, power/volume preferences, explicit volume test and user confirmation | Secure persistence and disabled-command tests; preferences do not discover HDMI/audio capabilities |
| F08 destinations | YouTube video and Spotify track/album/playlist templates alongside custom links | Link normalization tests; provider authentication and actual content playback remain device-dependent |
| F09 room suggestions | Manual room filter; active/nearby/recent ordering of saved TVs | Deterministic ranking tests; no automatic room sensing or commands |
| F10 routines | Optional Home Assistant integration: check volume support, request and verify volume, then launch a selected TV favorite | HTTP mock tests cover success, cancellation, wrong target, unsupported volume, and redirects; requires a configured server/token and real integration testing |
| Cast capabilities | Native Android/iOS capability bridge, receiver/media identity matching, pause gating and clamped VOD/live seek windows | Android compilation and capability/range tests; iOS bridge is source-only until built with Xcode |
| Reported state | Reported power/absolute volume with freshness labels and cleared state on disconnect | Fresh/stale/unknown tests; no inferred state or confirmed execution claim |
| Accessibility | Distinct non-overlapping D-pad semantic targets, labels, focus order, contrast/size checks, reduced-motion Cast transitions | Automated Android accessibility guidelines pass; full TalkBack/VoiceOver journeys remain open |
| Diagnostics | Bounded local measurements for first frame, connection attempts and command dispatch; explicit copy/clear | No TV identities, URLs, text or tokens; dispatch is not TV execution latency |
| Connection reliability | Outgoing activity resets the inactivity timer | Local TLS regression test covers active transmission followed by idle timeout |
| Signing | Explicit release signing with ignored private properties/PKCS12, preserving the previous certificate | Release signature matches v0.10.0; existing development-origin identity was imported, not rotated |
| iOS foundation | iOS 15 project, icons, network declarations, plugin registration, Cast bridge and CocoaPods configuration | Plist validation only; Xcode absent, no iOS binary or support certification |

## Delivered changes

| Plan area | Implementation | Verification boundary |
|---|---|---|
| NAV01 | Remote, Apps, and Devices share the application shell. The last paired Android TV restores into Remote; first use opens Devices. Settings is a secondary route. | Automated session tests and emulator navigation; physical reconnection remains to verify |
| NAV02 | Indexed destinations preserve search and scroll context. Disconnected launches retain the requested app and require confirmation of the selected TV. Launch callbacks check target identity. | Direct-launch tests; full pairing-to-launch flow still needs hardware |
| REM01 | Navigation, combined play/pause, mute, and volume precede activity and favorites. Extended playback actions moved into Remote options. Available height controls D-pad sizing. | Layout and command tests at 360×640, 360×800, 700×900, and 900×500 logical pixels |
| REM02 | Full directional quadrants respond to input; OK is a separate center target. Held commands are released when controls deactivate, routes change, the app backgrounds, or the session closes. | Quadrant hit tests and lifecycle implementation; sustained TV key-repeat needs hardware |
| REM03 | Search replaces microphone branding. Foreground status says On TV. Power follows negotiated support; incoming mute state informs its control. Playback toggle does not claim a known playing state. | Code and layout tests; device-specific reporting remains to verify |
| DEV01 | One list combines saved TVs and nearby services. Labels distinguish TV navigation from Cast sessions. Remembered Cast identities are separate from trusted TV pairings. | Emulator discovery and persistence tests; endpoints are never merged by name |
| APP01 | App rows request launch directly. Favorites are selected and ordered per TV. Custom destinations appear in the same searchable library. Technical details are optional. | Search, persistence, migration, ordering, and direct-launch tests |
| APP02 | A shared launch operation distinguishes confirmed, unconfirmed, failed, and cancelled outcomes. Foreground reports provide confirmation. Automatic timed Play Store selection was removed. | Outcome tests verify that transmission or elapsed time never implies success |
| PAIR01 | One visible labeled code input, explicit submission, valid-length gating, and duplicate-submit protection. Fresh pairing data is applied before reconnecting. | Credential-replacement tests; physical code entry and keyboard behavior require device checks |
| CAST01 | Stop casting describes the actual action. Controls require a matching receiver session. Receiver updates can replace local volume values. A reconnect action handles lost sessions. | Build and source verification; actual receiver playback and external volume changes need hardware |
| CAST02 | Direct-link casting is a collapsed advanced section and explains that webpage links are insufficient. Existing URL input and validation are retained. | Existing media URL tests; format and receiver compatibility remain device-dependent |
| SET01 | Removed the false appearance setting. Added connection help and quick access. Background update notices no longer open a modal automatically. Update recovery no longer recommends uninstalling. Corrected the launcher name. | Emulator and Android build |
| VIS01–VIS03 | Accessible action fill, quieter device/app lists, consistent selection colors, and reduced emphasis on technical content. | Contrast test and visual inspection of representative layouts |
| A11Y01–A11Y03 | Explicit directional and volume semantics, visible pairing input, large-text remote checks, and reduced-motion route/shortcut behavior. | Automated checks; TalkBack, motor-accessibility, and comprehensive scaling review remain outstanding |
| TECH01–TECH02 | Reused existing services. Serialized discovery and session operations. Saved endpoints refresh through discovery while preserving certificate pins. Re-pairing retains the saved device rather than silently forgetting it. | Session, endpoint, ordering, and persistence tests |
| TECH03 | Android TV discovery can operate before or without Cast initialization; discovery backends report partial startup failure separately. | Android build and source review; fault-injection coverage remains future work |
| TECH04–TECH05 | Unknown state remains explicit. Commands are not queued across reconnection. Idle traffic drives connection liveness; outgoing activity is included to avoid timing out active remotes. Discovery pauses in the background and resumes deliberately. | Local TLS lifecycle tests and application lifecycle handling; real performance baselines remain outstanding |
| F01, F02, F04 | Immediate remote restoration, contextual recovery, and independent TV favorites. | Software implementation; user-task validation still required |
| F05 | Android Quick Settings tile and launcher shortcut open the Remote destination. Settings can request tile addition on supported Android versions and provides manual instructions. | Android compilation, service registration, and warm-intent navigation checked in emulator |
| F08 foundation | Personal app and content links can be named, favorited, ordered, opened, and deleted. Inputs reject invalid or inappropriate link forms. | Persistence and launch-path checks; YouTube and Spotify templates are now included; provider compatibility still needs device checks |

## Storage and upgrade compatibility

Existing pairing certificates, saved devices, global/per-TV favorites and custom destinations retain their storage keys. New preferences and optional routine credentials use secure storage. Remembered Cast receivers remain separate from Android TV trust.

The release APK retains package `com.example.chromecast_remote` and the v0.10.0 signing certificate. An emulator in-place update retained a custom destination and its favorite status without uninstalling. This does not establish physical-TV pairing or every older-version migration.

## Validation

- `flutter analyze`: no issues.
- `flutter test --reporter expanded`: **128 tests passed**.
- Android debug and release APK builds passed; release version **0.11.0+13**.
- APK signature, package/version and previous-certificate continuity verified.
- Emulator upgrade and navigation smoke checks; representative fake-controller remote and keyboard visual captures.
- [Release readiness](RELEASE_READINESS.md) records measurements and exact validation boundaries.

## Work still requiring external evidence

| Item | Remaining work |
|---|---|
| Physical TV matrix | Pair/re-pair, standby, changed address/network, recovery, sustained key-repeat, power/audio reporting, app compatibility |
| Keyboard preview | Real fields, dismissal/reopening, repeated requests, sensitive fields, Unicode and submission; full synchronized editing is outside the preview |
| Cast | Real receivers, live streams, media from other apps, external volume changes, reconnect and Stop casting |
| Optional routines | Real Home Assistant entities and TV app launch; verify partial outcomes after cancellation/failure |
| Accessibility | Complete TalkBack/VoiceOver pairing, recovery and daily-control journeys, motor-accessibility and large-text review |
| iOS | Build, sign and run with Xcode; validate plugins, permissions, Keychain, Cast and lifecycle; no IPA shipped |
| Research | Formative usability tasks, room/eyes-up usefulness, accidental presses and product baselines |
| Performance | Physical-device connection/recovery distributions and TV response latency; emulator startup observations are not speedup claims |
| Distribution operations | Secure backup of local signing files, independent production identity/Play enrollment decisions |

No analytics or accounts were silently introduced. Home Assistant is optional and contacts only the explicitly configured server when used. Room suggestions are manual and deterministic.

## Implementation references

- [Android Cast MediaStatus](https://developers.google.com/android/reference/com/google/android/gms/cast/MediaStatus)
- [iOS Cast media status](https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_media_status)
- [Home Assistant REST API](https://developers.home-assistant.io/docs/api/rest/)
- [Home Assistant media player](https://www.home-assistant.io/integrations/media_player/)
- [Spotify identifiers and URIs](https://developer.spotify.com/documentation/web-api/concepts/spotify-uris-ids)
