# Upgrade implementation status

Date: 29 October 2026

This document tracks delivery against [the app upgrade plan](APP_UPGRADE_PLAN.md). The core software upgrade and supporting improvements are implemented. The complete roadmap is not finished: physical-device validation, research-dependent features, and production release preparation remain separate gates.

Release package: [v0.10.0 notes](releases/v0.10.0.md), Android version 0.10.0, build 12.

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
| TECH04–TECH05 | Unknown state remains explicit. Commands are not queued across reconnection. Incoming traffic, not outgoing key presses, drives connection liveness. Discovery pauses in the background and resumes deliberately. | Local TLS lifecycle tests and application lifecycle handling; real performance baselines remain outstanding |
| F01, F02, F04 | Immediate remote restoration, contextual recovery, and independent TV favorites. | Software implementation; user-task validation still required |
| F05 | Android Quick Settings tile and launcher shortcut open the Remote destination. Settings can request tile addition on supported Android versions and provides manual instructions. | Android compilation, service registration, and warm-intent navigation checked in emulator |
| F08 foundation | Personal app and content links can be named, favorited, ordered, opened, and deleted. Inputs reject invalid or inappropriate link forms. | Persistence and launch-path checks; provider templates and link compatibility catalog are not delivered |

## Connection lifecycle corrections

The protocol client previously started closing a socket before checking whether it should notify reconnection listeners. Closing set the intentional-close flag, which could suppress the unexpected-disconnect callback. The client now captures the notification decision before teardown.

Connection attempts also carry cancellation generations so a late TLS connection cannot replace a cancelled session. Held keys are tracked and released on teardown. An intentional disconnect does not schedule reconnection. Tests use a local TLS server to exercise actual socket closure, independently of physical TVs.

## Storage compatibility

- Existing certificate and Android TV pairing keys remain unchanged.
- Existing global favorite selections and custom links migrate into an ordered favorites representation.
- Each paired TV copies global preferences when its scope is first used; later changes are independent.
- Remembered Cast receivers use a separate storage key and never acquire Android TV trust through discovery.
- No new accounts, analytics, cloud services, or runtime package dependencies were introduced.
- Existing custom destination naming behavior is retained: adding a destination with the same normalized name replaces that entry in its scope.

## Remaining work and explicit gates

| Item | Status | Required next evidence or work |
|---|---|---|
| F03 phone keyboard | Feasibility work remains | The current protobuf schema contains incoming input-field status but no complete outgoing editing message model. Extend from a verified protocol reference, then test field synchronization, cursor handling, Unicode, submission, sensitive input, cancellation, and app compatibility on real TVs. Do not advertise keyboard support yet. |
| Cast command capabilities | SDK limitation remains | The current Flutter Cast status entity does not expose a supported-media-command mask. Accurate capability gating needs a verified native bridge or upstream SDK change; duration alone cannot prove seek support. |
| Cast live media and receiver volume | Hardware gate | Verify live streams, external volume changes, media started by other apps, reconnect, and Stop casting on representative receivers. |
| Detailed power and volume displays | Partially delivered | Mute reporting is consumed. Trustworthy power state, absolute volume reporting, and freshness behavior need device validation before broader display or control claims. |
| F06 eyes-up mode | Deferred by roadmap dependency | First validate the new stable standard remote, phone-glance frequency, and accidental directional presses. |
| F07 household control setup | Deferred by roadmap dependency | Validate real power/volume compatibility and determine which user-confirmed preferences improve outcomes. |
| F08 provider templates | Deferred beyond custom-link foundation | Verify supported provider links and authentication behavior before adding templates or calling destinations guaranteed. |
| F09 room suggestions and F10 routines | Experimental and deferred | Reliable signals/integrations, user demand, privacy decisions, and failure recovery must be established first. |
| Accessibility certification | Not claimed | Run complete TalkBack tasks and review focus, announcements, touch accuracy, large text, keyboard-visible pairing, and real-device contrast. |
| Performance claims | Not measured | Establish launch-to-controls, connection, reconnection, command transmission, and recovery distributions on release builds. |
| Production signing identity | Existing GitHub distribution retained | v0.10.0 uses the existing signing configuration to preserve update compatibility. A separately managed production identity remains future work; no new signing identity was generated. |
| Release migration and compatibility matrix | Hardware gate | Test upgrades over an installed version, unavailable TVs, changed addresses, invalid pairing, app compatibility, standby, and network changes. |
| iOS | Not implemented or tested in this upgrade | The repository has no iOS platform project. Add platform configuration and perform separate SDK, accessibility, permission, and lifecycle verification before claiming support for a delivered iOS build. |
| User research and product metrics | Outstanding | Run the formative tasks and establish baselines described in the upgrade plan. No usage analytics were silently added. |

## Validation

Automated checks cover the existing protocol/storage/media behavior plus the new session, favorites, launch, contrast, directional input, responsive layout, large-text, and TLS lifecycle behavior. Final verification: `flutter analyze` reported no issues, all **92 tests passed**, `flutter build apk --debug` succeeded, and `git diff --check` passed. The debug APK is available at `build/app/outputs/flutter-apk/app-debug.apk`. Release validation also passed for version 0.10.0, build 12: the release APK builds, its package identity is unchanged, and its certificate matches the published v0.9.0 APK.

Commands:

```sh
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
git diff --check
```

Representative emulator checks: Devices and Apps rendering, the three-destination shell, optional settings, native service registration, opening Remote through the Android shortcut action, and retaining a Netflix launch request while selecting a TV. Connected remote layout captures use a fake controller; they are not evidence of physical TV operation.

## Native quick access reference

The tile follows the version-specific activity-launch behavior in the [Android TileService API reference](https://developer.android.com/reference/android/service/quicksettings/TileService) and exposes addition through [Android Quick Settings tile guidance](https://developer.android.com/develop/ui/views/quicksettings-tiles). It opens the application and does not send commands while the phone is locked.
