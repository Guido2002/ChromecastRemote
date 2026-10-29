# Phone keyboard preview

Status: Included as preview functionality in v0.11.0 (Android build 13).

## Delivered behavior

The Android TV remote header now has a Phone keyboard action when the TV negotiates input-method support. It opens a local composer for an explicit text request to the selected television.

1. Select a search or ordinary text field on the television.
2. Open Phone keyboard in the app. Sending remains unavailable until the television reports input-session counters.
3. Enter text on the phone. Draft text is obscured by default; Show draft text is optional.
4. Choose Send to the named TV. Typing and the phone keyboard's Done action do not send text.
5. Check the result on the TV. Enter on TV is a separate action, available only when key commands are supported and there is no unsent draft.

The composer clears its draft when the reported app, input-session counters, or connection changes. Backgrounding the app also clears the draft and pauses the composer. Resumption is explicit. No text request is queued for reconnection or redirected to a different TV.

The send button includes the TV name so the destination remains visible while scrolling above the phone keyboard. Small-phone and large-text layouts scroll within the space above the keyboard.

## Protocol implementation

The trimmed protobuf schema now includes the input batch-edit and show-request message definitions. The client uses only reported routing counters; it does not invent an input field, display a TV field value, or persist incoming field text.

Each local composer addresses an opaque input-session token. Tokens are replaced when counters change, invalidated when the foreground app changes, and discarded when the connection closes. A token from an older field or connection is rejected even if the numeric counters later repeat.

Requests use a discrete batch-edit message. Unicode offsets follow the reference sender's Unicode code-point convention rather than Dart string UTF-16 length. Empty, NUL-containing, and oversized input is rejected. The limit is 2000 Unicode code points.

The UI reports a request, not confirmed insertion. No acknowledgement of correct text entry or submission is inferred from writing to the socket. Incoming TV field contents are not mirrored into the phone composer. Drafts are not stored, logged, or sent to analytics, and keyboard personalization and suggestions are disabled for the composer.

The reference is pinned to androidtvremote2 revision `e664a8e1f14ee458b14c646bfb3ea46f10367051`:

- [Protocol message definitions](https://github.com/tronikos/androidtvremote2/blob/e664a8e1f14ee458b14c646bfb3ea46f10367051/src/androidtvremote2/remotemessage.proto)
- [Reference sender and counter handling](https://github.com/tronikos/androidtvremote2/blob/e664a8e1f14ee458b14c646bfb3ea46f10367051/src/androidtvremote2/remote.py)

## Connection liveness correction

The reference implementation resets inactivity tracking for transmitted commands as well as received packets. A TV can stop idle pings while receiving commands, so an incoming-only timer can incorrectly disconnect an actively used remote.

The client now resets its idle timeout after outgoing key, app-link, text, and protocol traffic. A local TLS regression test keeps the receiver silent while commands are transmitted, verifies that the connection remains available, then verifies timeout after traffic stops. This is an inactivity detector, not a guarantee that every transmitted command was handled.

## Validation boundary

Static analysis reports no issues and all **128 tests pass** across the app. Android debug and release builds succeed.


Automated coverage includes:

- Exact batch-edit wire encoding, reported zero counters, Unicode offsets, and input-size validation.
- Stale field, application, and connection tokens; duplicate counter reports.
- A local TLS receiver verifying input requests, counter routing, separate Enter, disconnect rejection, and IME capability negotiation.
- No transmission while typing or choosing Done; draft clearing, obscured input, target checks, and explicit resume.
- Enter disabled without key support and while a draft remains unsent.
- Keyboard-visible layouts at 360 by 640 logical pixels and at 200 percent text scaling.

Physical Android TV and application compatibility are not established by these tests. A phone emulator was used for release smoke checks; no physical TV was connected for keyboard validation. Before promoting the preview to a stable feature, verify:

| Scenario | Required observation |
|---|---|
| Empty and prefilled search fields | Determine whether each app inserts, replaces, or otherwise interprets a request; do not promise append or synchronized editing |
| Repeated text requests | Verify resulting field contents and counter updates |
| Field switching in the same app | Confirm reported counters invalidate old requests |
| Field dismissal and reopening | Confirm stale field behavior and any additional visibility signals needed |
| App switching and reconnection | Verify no old draft reaches the next field or connection |
| Accented text, emoji, and non-Latin text | Verify visible contents and cursor behavior on real apps |
| Password and other sensitive fields | Verify app-specific handling before claiming compatibility |
| Enter or search submission | Verify submission occurs only from the explicit TV Enter action |
| TalkBack and the visible phone keyboard | Verify focus, announcements, scrolling, and clear/resume actions |

Full TV-text mirroring, cursor synchronization, automatic typing, voice streaming, and Cast keyboard input are outside this keyboard preview. The separate [hold-to-talk voice feature](VOICE_AND_NOW_PLAYING.md) is included in v0.12.0.
