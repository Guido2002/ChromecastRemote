# Voice search, Smart Now Playing and haptics

Status: included in v0.12.0, Android build 14. Physical-TV voice/Cast compatibility still requires device validation.

## Hold-to-talk voice search

The Android TV remote has a microphone action. It is enabled only when the connected TV negotiates voice and key support.

1. Hold the microphone. Grant microphone permission if requested; after the permission dialog, hold again if the original press was interrupted.
2. Wait for **Listening**, then speak. The destination remains the selected TV.
3. Release to end the request and check the television for its result. Recording ends automatically after ten seconds.

Screen-reader users activate once to start and again to stop. The same duration limit applies. Unsupported devices keep the action disabled. A classic Cast receiver does not acquire voice-search capability.

Audio is raw PCM16 little-endian, 8 kHz, mono. The app requests a voice session with KEYCODE_SEARCH, waits for the TV's routing ID, acknowledges the session, and then sends bounded audio frames and an explicit end message. It never invents a voice-session ID. Small recorder callbacks are combined before sending; only the final short frame is zero-padded to the reference receiver's minimum size.

Audio remains in memory and is not saved, logged, transcribed on the phone, or uploaded to an app-operated service. It goes to the selected television; that television's voice provider may process it online. Audio already transmitted cannot be recalled.

Releasing before permission or TV readiness completes prevents recording from starting later. Leaving Remote, changing targets, losing the connection, backgrounding the app, or disposing the control cancels recording and discards unsent audio. A timeout or permission failure provides recovery text. A sent request does not prove recognition or execution.

The existing Search on TV menu item remains a separate key action. Phone keyboard retains explicit text submission and is not a speech transcription interface.

Reference implementation and wire schema, pinned to androidtvremote2 revision `e664a8e1f14ee458b14c646bfb3ea46f10367051`:

- [Voice handshake and audio framing](https://github.com/tronikos/androidtvremote2/blob/e664a8e1f14ee458b14c646bfb3ea46f10367051/src/androidtvremote2/remote.py)
- [Voice protobuf messages](https://github.com/tronikos/androidtvremote2/blob/e664a8e1f14ee458b14c646bfb3ea46f10367051/src/androidtvremote2/remotemessage.proto)
- [Recorder documentation](https://pub.dev/packages/record/versions/7.1.2)

Android declares `RECORD_AUDIO`; iOS has a microphone usage description. Recording is foreground-only. No background recording service or speech-recognition account is added.

## Smart Now Playing

The Remote pane automatically switches to a dedicated media view when the Cast SDK reports connected, loaded media and the native capability bridge confirms the same receiver and media-session ID. Playing, paused, buffering and loading sessions qualify; idle, missing, mismatched and disconnected sessions do not.

The dedicated view includes reported artwork (or a neutral placeholder), title, progress, playback controls and receiver volume. Seek windows and pause support continue to use receiver capabilities. Artwork failure does not prevent transport controls. The view supports narrow screens, tablets, landscape and enlarged text.

**TV remote** returns to navigation without stopping the Cast session. This choice persists for that media session; **Now playing** opens media controls again. A new media session can switch automatically. Ending the session returns to the existing remote. Apps and Devices are not forcibly replaced while the user is working there.

No Android TV and Cast endpoint is merged by name. The Cast receiver name stays visible, and TV navigation keeps its own selected TV. Ordinary Android TV applications continue to show only reported foreground app, available key commands and reported power/volume. The app does not create media artwork, a playback timeline, or a playing/paused state for those applications.

## Haptic feedback

Settings → **Haptic feedback** enables or disables local tactile feedback. The preference is saved on the phone and applies to directional/OK, navigation, playback, volume, power, voice and shortcut actions. Haptics default to enabled, matching the previous remote's existing press feedback.

A tap produces one light pulse. A held directional/volume control pulses once when the hold is recognized; repeated commands do not repeatedly vibrate. Cast volume commits use a selection tick. Disabled controls do not trigger pulses. Duplicate feedback in extended playback controls has been removed. A haptic pulse represents the local interaction, not TV acknowledgement.

## Verification and remaining checks

`flutter analyze` reports no issues; all **146 tests pass**. Android debug and signed release APK builds pass. The iOS permission plist passes syntax validation. Cast layouts are checked at 320×640, 360×800, 700×900, 900×500, and 200% text scaling. Visual captures use reported-state fixtures, not a physical receiver.

Automated coverage includes local TLS voice routing, capability negotiation, PCM padding and stale tokens; microphone permission/hold/release/limit/cancellation behavior; Cast identity, automatic/manual switching, reported media UI and command gating; haptic persistence and one-pulse behavior. The existing application tests continue to cover Android TV's honest state presentation.

Physical microphone capture, recognition on representative TV assistants/apps, real Cast receivers and tactile feel still require device testing. The iOS project remains unbuilt in this environment because Xcode is unavailable; its permission declaration does not establish iOS runtime compatibility.
