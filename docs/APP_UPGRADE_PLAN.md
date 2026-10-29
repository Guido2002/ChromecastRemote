# Chromecast Remote app upgrade plan

Date: 29 October 2026

Status: Recommendations for review and implementation planning

Scope: Product strategy, navigation, UI, usability, accessibility, features, reliability, architecture, privacy, testing, and release quality

Implementation progress is tracked in [Upgrade implementation status](UPGRADE_IMPLEMENTATION_STATUS.md), including delivered software, validation, and remaining research or hardware gates.

## 1. Executive assessment

The application should become a dependable everyday TV remote that opens directly to useful controls. Its present structure gives too much importance to device management, app catalog administration, and technical details. Essential actions and recovery paths need attention before the product gains more features.

The recommended product promise is: **Your TV controls are ready when you open the app.**

The next release should establish three outcomes:

1. Returning users immediately reach the remote for the correct TV.
2. Navigation, playback toggle, mute, and volume are accessible without scrolling on supported phone layouts.
3. Labels, feedback, connection states, and recovery actions accurately describe what the app knows and does.

This is a recommendation document, not authorization to implement every proposal. Experimental features should remain deferred until the core experience meets its acceptance criteria.

### Evidence and limits

The preceding audit inspected the Flutter UI, navigation, discovery, pairing, connection manager, Android TV protocol client, app shortcuts, Cast controls, and updater. The current source was built and the Devices, Remote empty state, Apps, app details, and Settings screens were inspected in an Android emulator.

Connected remote layouts and hardware interactions were reviewed from source. Physical TV pairing, command delivery, playback compatibility, TalkBack usability, and real-device performance were not validated. iOS execution and distribution were not assessed; the repository currently contains the Android platform project.

Throughout this plan:

- **Observed** means visible in the emulator during the audit.
- **Code finding** means supported by the inspected implementation, without claiming hardware execution.
- **Recommendation** means a proposed design or engineering change.
- **Hypothesis** means an assumption requiring user or device testing.

## 2. Product direction and intended users

### Primary audience

Prioritize people controlling a familiar Google TV or Android TV from the couch, including users whose physical remote is missing or inconvenient. Their main tasks are navigating, selecting, going back, pausing, changing volume, and opening a favorite app.

Treat households with several TVs as an important secondary audience. The selected target must remain explicit so a user does not accidentally control another room.

Classic Chromecast users form a separate supported workflow: receiver volume, compatible media sessions, and direct-media playback. Do not imply that these devices provide system navigation.

These audience priorities are product hypotheses. Validate them through interviews and usage research before investing in specialized workflows.

### Product boundaries

- Preserve the distinction between Android TV control and Cast media control.
- Keep operation local where the existing protocols allow it.
- Do not introduce accounts, cloud synchronization, subscriptions, AI assistance, or broad home automation without evidence that they solve a frequent problem.
- Prefer reliable favorites and fast access over a large catalog of uncertain capabilities.
- Do not market a static shortcut catalog as a list of installed TV apps.
- Avoid promising universal device, application, power, or volume compatibility.

### Competitive baseline

Google already documents phone keyboard input, swipe navigation, media controls, and Android Quick Settings access for its virtual remote. These are useful baseline capabilities, not proven differentiators. See [Google virtual remote help](https://support.google.com/chromecast/answer/11221499?hl=en-CA).

Potential differentiation lies in immediate access, low-attention control, helpful recovery, and personal destinations. None of the proposed differentiators should be described as unique or as an established market gap without broader competitive research.

## 3. Priorities and sequencing

Effort estimates are relative scope judgments, not calendar commitments: **S** is a localized change, **M** spans several components or states, and **L** requires substantial integration or protocol work.

| Priority | Recommendation | Effort | Main dependency |
|---|---|---|---|
| P0 | Display the actual remote in the Remote destination and restore it on return | M | Shared selected-device and session state |
| P0 | Keep essential phone controls visible and correct D-pad hit regions | M | Height-aware layout |
| P0 | Correct microphone, foreground-app, disconnect, and appearance semantics | S | Accurate capability and action labels |
| P0 | Fix fresh pairing result handling and address-refresh recovery | M | Connection manager and discovery integration |
| P0 | Fix normal-text contrast on filled blue buttons | S | Separate accessible action-fill token |
| P1 | Unify device selection and shortcut management | M | P0 navigation |
| P1 | Preserve launch intent and make launch feedback honest | M | Explicit target identity and outcome state |
| P1 | Isolate service initialization failures and improve connection recovery | M | Independent service states |
| P1 | Complete accessibility, responsive layout, and reduced-motion work | M | Revised components |
| P1 | Use reported volume and power state where trustworthy | M | Controller state exposure and freshness rules |
| P1 | Investigate phone keyboard support | L | IME compatibility spike |
| P1 | Improve update presentation and distribution recovery | M | Signing and installer workflow verification |
| P2 | Add low-attention remote mode and per-TV control preferences | M | Stable core controls |
| P2 | Add personal destinations and native quick access | M–L | Verified links and reliable resume |
| P3 | Explore room suggestions and external routines | L | Demand validation and reliable integrations |

Recommended release boundary: complete P0 and the essential recovery work before adding experimental capabilities.

## 4. Navigation and information architecture

### NAV01 Make Remote the main destination

**Code finding:** The app opens Devices. Automatic reconnection leaves users there. Remote presents a saved-TV list and pushes the actual remote as a separate screen, outside the bottom navigation.

**Recommendation:** Use three primary destinations: Remote, Apps, and Devices. Move the current Settings content into a header menu. Render the connected remote inside the application shell.

The Remote header should show the selected device, its connection state, a device switcher, and contextual actions. Keep TV Back and application navigation visually and semantically distinct.

**Acceptance criteria:**

- A returning user with a connected last-used TV reaches controls without selecting the TV again.
- First use presents device selection and transitions to Remote after successful setup.
- Changing TV does not create a second navigation hierarchy.
- Moving between destinations preserves the active session.
- System Back behavior is consistent and cannot be confused with sending Back to the television.

### NAV02 Preserve context and unfinished actions

Keep search text, list position, selected filters, and the selected device when moving between destinations. Avoid recreating tab content in ways that discard useful state.

If a user requests an app launch while disconnected, remember the app and intended target. After device selection and connection, resume the request only when the destination is explicit. Cancel the pending request if the user cancels setup or deliberately changes the task.

Never silently redirect a pending command to a different TV.

## 5. Screen by screen redesign

### REM01 Rebuild the phone remote around frequent actions

**Code finding:** Phone content is ordered as D-pad, navigation, foreground-app card, shortcuts, media controls, then volume. This places a frequent action below secondary content.

Recommended hierarchy:

```text
Living room device selector                 More
Connection state                           Power

                 Directional pad

                 Back    Home

                 Play or pause
Mute             Volume down    Volume up

Favorite apps                              All apps
```

- Keep the essential control group stable and visible.
- Move Previous, Next, Stop, Rewind, and Fast-forward into an extended-controls surface.
- Use one prominent playback toggle.
- Put favorite apps below essential controls.
- Make foreground-app information a compact line such as “On TV: YouTube.”
- Fit essential controls at 360 × 800 logical pixels with default text scaling. At large text sizes, preserve reachability and allow purposeful scrolling rather than clipping.
- Adapt to available height as well as width. A wide but short landscape viewport is not equivalent to a tablet.

### REM02 Match directional appearance to input behavior

**Code finding:** The D-pad appears to be a large interactive ring, but directional handling is attached to four individual buttons.

- Make each visible directional region respond consistently across its intended area.
- Give the center an explicit Select or OK semantic button role.
- Keep regions nonoverlapping and provide clear pressed feedback.
- Preserve hold-to-repeat, with repeat cancellation on pointer cancellation, route changes, app backgrounding, and connection loss.
- Do not repeat or replay stale commands after reconnecting.

Validate accidental presses and thumb reach on real phones. A larger visual control is only useful if it improves accuracy.

### REM03 Correct capability and state presentation

- Replace the microphone icon with Search while the action only sends a Search key. Add voice branding only after actual voice input is implemented and verified.
- Replace “NOW PLAYING” with “On TV” or “Active app” for Android TV foreground status.
- Do not use a play-only glyph to imply a known playback state when the protocol cannot report that state.
- Show unknown foreground state without implying that the TV is idle.
- Use reported volume, mute, and power information where reliable. Mark stale or unavailable values as unknown rather than inventing percentages or certainty.
- Explain capability limits in context. Avoid controls that appear enabled but silently do nothing.
- Preserve spatial stability during temporary disconnects; show recovery rather than rebuilding the entire control arrangement.

### DEV01 Unify saved and nearby devices

**Observed:** Similarly named entries compete in discovery. **Code finding:** Saved and Nearby are separate modes, although these properties can overlap.

Use a unified list ordered by current TV, saved TVs, and other nearby devices. Show Connected, Connecting, Nearby, or Not currently found where supported by evidence.

Describe control modes by outcome:

- **TV remote:** navigation, app launching, and supported TV controls.
- **Cast playback:** compatible media sessions and receiver volume.

Do not automatically merge entries by name. Preserve protocol identities internally. If endpoint association is added, make it explicit and user-confirmed, with a way to undo it.

Use a tappable row and a restrained action label instead of equally prominent Connect buttons everywhere. Keep rename, forget, diagnostics, and control preferences in overflow actions.

Remember relevant Cast receivers separately from Android TV trusted pairings. A remembered receiver is not a paired Android TV, and its availability still depends on discovery and SDK behavior.

### APP01 Turn Apps into a launcher

**Observed:** Opening a catalog app leads to a detail page containing package names and launch-method information.

- Launch from the app row or tile when a compatible TV is connected.
- Keep favorite selection a distinct accessible action.
- Move package names, launch methods, and troubleshooting into an optional technical-details sheet.
- Remove duplicate favorite controls from the same normal workflow.
- Combine catalog and custom shortcuts into one searchable management experience.
- Put favorites first and allow explicit ordering.
- Keep the selected target visible, including during connection loss.
- Describe entries as available shortcuts; do not imply installation has been checked.
- Replace the large persistent instruction banner with a compact target selector and contextual help.
- Remove category filters that do not meaningfully help users navigate the small catalog. Reassess filters as the catalog grows.

### APP02 Make launch feedback evidence based

**Code finding:** Remote shortcut animation expires on a fixed timer, independently of success. Launch behavior differs between the remote and library paths.

Use a shared launch operation with requested, confirmed where observable, unconfirmed, failed, and cancelled outcomes. A foreground package match can confirm the active app; it cannot confirm playback of specific content.

For Play Store assisted launches, avoid assuming the focused action is always safe to select. Validate the mechanism on supported devices, constrain any automation, and provide a clear fallback when the outcome cannot be established.

Do not state that an app is missing unless the device actually provides that evidence.

### PAIR01 Simplify and strengthen pairing

- Keep the six-character visual presentation while providing one labeled, accessible input.
- Choose one submission model. Prefer an explicit Pair action enabled only for a complete valid code.
- Prevent duplicate submissions while verification is running.
- Preserve the code after rejection and explain how to correct it.
- Keep the field, error, and action reachable with the keyboard open and large text enabled.
- Offer clear cancellation and retry behavior.
- After successful re-pairing, pass the returned credentials into the active connection rather than reconnecting with stale data.

### CAST01 Clarify the media control experience

Preserve the absence of system navigation on classic Chromecast devices.

- Label an action that stops playback and ends the session **Stop casting**.
- If a separate leave-connected action is offered, verify the SDK behavior before promising playback will continue.
- Reconcile displayed volume with receiver updates after local changes; do not let a local cached value permanently override external changes.
- Enable seeking and transport controls according to reported command support where available.
- Treat unknown duration, live streams, buffering, artwork failures, and absent media as distinct states.
- Explain that another app’s media may not expose a controllable standard session.

### CAST02 Make direct media casting an advanced task

- Present “Cast a media link” as a deliberate secondary action.
- Explain the difference between a direct media URL and a webpage URL.
- Keep syntax validation errors next to the field and preserve input after failure.
- Provide readable loading, receiver rejection, and unsupported-format states.
- Do not imply that a recognized file extension guarantees codec, authentication, DRM, or receiver compatibility.
- Never silently replace existing playback without a clear user action.

### SET01 Remove misleading settings and interruptions

- Remove the static “System” appearance value while the app is fixed dark.
- If appearance options are added, make them functional and validate every supported theme.
- Keep version, licenses, updates, connection help, and optional haptic preferences in a compact secondary area.
- Replace launch-time update dialogs with a nonblocking indicator and a deliberate update action.
- State installation requirements accurately, including possible unknown-source permission steps.
- Remove generic advice to uninstall after signature mismatch. Explain the issue and preserve pairing data whenever possible.
- Correct the Android launcher label from the development-style `chromecast_remote` to the chosen product name.

## 6. Visual design system

### VIS01 Establish a clear hierarchy

Use filled emphasis for the current primary action, quieter treatments for secondary actions, and ordinary rows for repetitive lists. Reserve cards for meaningful groups rather than wrapping every item in a bordered panel.

Use blue consistently for selection and action, green for connected or successful states, and error colors for failures. The Nearby selection should not look like a connection-success state.

Retain the dark interface where it supports couch use. Additional gradients, blur, shadows, or oversized decorative cards are unnecessary.

### VIS02 Correct contrast and typography

The audited primary blue `#2388FF` against white yields approximately 3.48:1 contrast. Create a darker action-fill token or choose an appropriate text color to meet 4.5:1 for normal text. Preserve a separate brighter accent for use on dark surfaces where suitable.

Define a small type hierarchy for page titles, device names, section labels, body copy, and status text. Avoid excessive uppercase labels and letter spacing. Keep technical and error information readable without making it dominate normal use.

### VIS03 Standardize spacing and components

- Use a documented spacing scale, for example 4, 8, 12, 16, 24, and 32 logical pixels.
- Define deliberate variants for action buttons, remote buttons, list rows, statuses, empty states, and recovery panels.
- Use a limited radius scale appropriate to each component type.
- Preserve consistent icon size, alignment, pressed state, and disabled state.
- Treat long names and localized text as normal design inputs.
- Avoid fixed row heights that clip text at larger accessibility settings.

## 7. Accessibility and responsive behavior

### A11Y01 Make interaction understandable without sight

- Provide meaningful button roles and labels for OK, directions, volume, power, playback, and favorite actions.
- Include the app or device name in repeated contextual actions where needed.
- Expose selection, connection, busy, and unavailable states to assistive technology.
- Announce important connection changes and errors without announcing every repeated key event.
- Keep focus order aligned with visual order and restore focus after sheets and dialogs close.
- Do not rely on color, animation, or haptics alone to convey state.
- Test the complete pairing and recovery journeys with TalkBack. Test VoiceOver if an iOS project is delivered.

### A11Y02 Support reliable touch and scalable text

Use at least 48 × 48 logical-pixel touch targets for Android controls, with separation that avoids accidental adjacent activation. Audit explicit shrink-wrap and compact-density overrides. Distinguish visual icon size from its interactive bounds.

Verify small phones, narrow landscape, tablets near the existing breakpoint, larger tablets, split-screen windows, long names, and increased text scaling. At large text sizes, prefer readable reflow and scrolling to clipped controls.

### A11Y03 Apply motion and haptic preferences consistently

The existing entrance helper considers reduced motion, but other custom switchers, scales, and route transitions require consistent handling. Avoid delaying access to controls for decorative animation.

Provide optional haptic preferences if user testing shows demand. A haptic pulse confirms a local press, not successful execution on the TV.

## 8. Reliability and technical architecture

### TECH01 Retain and strengthen the existing boundaries

Reuse the connection manager, protocol clients, stores, theme, and adaptive layout helpers. Do not introduce a new state framework or rewrite the application solely to implement this plan.

Centralize selected-device/session state and shortcut launch behavior so all destinations use the same target, capabilities, status, and outcome rules. Keep device identity explicit rather than relying on display names.

### TECH02 Improve discovery and connection recovery

- Distinguish discovery startup, discovery running, no results yet, partial service failure, and stopped discovery.
- Avoid telling users a scan is finished merely because discovery services have started.
- Keep one discovery protocol usable when the other fails, where feasible.
- Refresh a saved TV’s endpoint from trusted matching discovery data before repeatedly retrying an obsolete address.
- Preserve certificate verification when an address changes. Never bypass trust checks to make reconnection appear successful.
- Use bounded, cancellable retry behavior with clear manual recovery after repeated failure.
- Cancel retries when the user forgets or switches devices.
- Handle background/resume and network changes deliberately; avoid unnecessary scanning and reconnect loops.
- Prevent stale asynchronous results from replacing a newer device selection.

### TECH03 Isolate startup failures

**Code finding:** Cast SDK initialization currently gates the entire app.

Initialize services independently where possible. A Cast startup error should not make Android TV controls unavailable. Present degraded functionality with an appropriate retry action instead of a whole-app failure.

Translate raw exception strings into useful user-facing recovery text. Retain technical details in diagnostics rather than placing long errors into a truncated header line.

### TECH04 Use incoming state carefully

The protocol client receives foreground-app, volume, and power information. Expose suitable state through the controller, with explicit unknown and stale states. Confirm what each message means on representative hardware before making strong UI promises.

Keep command transmission separate from command execution. The app cannot claim every transmitted key was handled by the foreground application.

### TECH05 Improve perceived and actual performance

- Measure launch-to-controls, connection readiness, reconnection duration, and command transmission latency separately.
- Record percentile distributions and failures, not only averages.
- Keep controls available without waiting for app artwork or nonessential update checks.
- Avoid repeated storage loads and rebuilds that lose visible state.
- Bound discovery and retry activity to avoid needless battery consumption.
- Do not queue navigation or volume commands across a disconnect.

No performance speedup is claimed by the audit; measurements are required before optimization.

## 9. Privacy and security

These are engineering review recommendations, not findings of a demonstrated exploit.

- Preserve secure certificate storage and pinned-certificate verification.
- Make Forget remove the intended trust and saved-device state, with a clear confirmation.
- Do not weaken certificate checks during rediscovery, re-pairing, or address migration.
- Treat custom app links and media URLs as user input. Validate accepted formats and never execute shell commands from them.
- Keep sensitive URL parameters, text input, pairing codes, and certificates out of logs and analytics.
- If keyboard support is implemented, avoid retaining entered text and handle sensitive fields deliberately.
- Make diagnostic export explicit, reviewable, and redacted.
- Keep any product analytics optional and minimal. Prefer aggregated task outcomes over raw command histories or content URLs.
- Request only permissions needed for active functionality, with a useful explanation when permission denial blocks a task.
- For updates, verify trusted release provenance, signing continuity, download integrity, and failure cleanup before distribution. Android package validation remains part of the installation flow.

## 10. Feature opportunities

Scores are provisional expert judgments from 1 to 10. They are not evidence of demand or proof of competitive uniqueness. Prioritize expected value relative to effort.

| Feature | Value | Differentiation | Usability | Feasibility | Strategic fit | Classification |
|---|---:|---:|---:|---:|---:|---|
| Resume the last remote | 10 | 3 | 10 | 9 | 10 | Core improvement |
| Guided connection recovery | 10 | 5 | 9 | 7 | 10 | Core improvement |
| Phone keyboard input | 9 | 2 | 9 | 5 | 9 | Major feature |
| Per-TV favorites and ordering | 8 | 4 | 9 | 9 | 9 | Core improvement |
| Quick-access remote entry | 8 | 3 | 9 | 6 | 9 | Major feature |
| Eyes-up remote mode | 8 | 6 | 7 | 8 | 9 | Differentiator candidate |
| Household control setup | 8 | 6 | 8 | 6 | 9 | Differentiator candidate |
| Personal TV destinations | 7 | 6 | 8 | 6 | 8 | Differentiator candidate |
| Room-aware suggestions | 6 | 7 | 7 | 3 | 6 | Experimental |
| TV and audio routines | 6 | 6 | 6 | 3 | 5 | Experimental |

### F01 Resume the last remote

**User and scenario:** A frequent user opens the app to pause or adjust the familiar TV.

**Problem and benefit:** Repeated device selection delays the first useful action. Restore controls immediately.

**Integration and approach:** Reuse last-device storage and the shared connection manager; reconnect within Remote.

**Complexity:** S–M.

**Drawback:** The remembered device may be wrong or unavailable; keep its name prominent and switching immediate.

**Success measure:** Lower open-to-first-command time without increased wrong-device actions.

### F02 Guided connection recovery

**User and scenario:** A household user encounters an unavailable TV, changed address, or expired pairing.

**Problem and benefit:** Generic retry loops provide no path forward. Offer the relevant next action.

**Integration and approach:** Persistent recovery panel using discovery, connection states, and typed pairing exceptions.

**Complexity:** M.

**Drawback:** False diagnoses are worse than honest uncertainty; only claim observable causes.

**Success measure:** Recovery without restarting, uninstalling, or unnecessarily forgetting the TV.

### F03 Phone keyboard input

**User and scenario:** A user enters a search through the television keyboard.

**Problem and benefit:** D-pad text entry is slow. Provide direct phone typing where supported.

**Integration and approach:** Contextual Keyboard action backed by actual IME input handling. The current foreground-app IME parsing is not a complete text-entry implementation.

**Complexity:** L; begin with a compatibility spike.

**Drawback:** Unicode, cursor state, field synchronization, and sensitive inputs require care.

**Success measure:** Faster text completion with a low correction and synchronization-failure rate.

### F04 Per-TV favorites and ordering

**User and scenario:** Different rooms use different TV apps.

**Problem and benefit:** A single global shortcut arrangement creates irrelevant choices. Store useful favorites for each TV.

**Integration and approach:** Scope shortcut selection and explicit order to stable device identity; migrate current global preferences safely.

**Complexity:** S–M.

**Drawback:** Configuration overhead; provide useful defaults and avoid automatic reordering.

**Success measure:** More launches from favorites and less repeated catalog browsing.

### F05 Quick-access remote entry

**User and scenario:** A user needs to pause immediately while using another phone app.

**Problem and benefit:** Finding the app delays control. Add a native shortcut into the last remote.

**Integration and approach:** Android Quick Settings tile or pinned shortcut with clear target naming. Assess other platforms separately.

**Complexity:** M–L.

**Drawback:** OS lifecycle restrictions and stale targets; do not promise invisible background control.

**Success measure:** Faster entry-to-command time and repeat usage.

### F06 Eyes-up remote mode

**User and scenario:** A viewer navigates while watching the TV rather than the phone.

**Problem and benefit:** Small targets and shifting layouts demand visual attention. Offer stable large regions with restrained haptics.

**Integration and approach:** Explicit optional mode using deterministic directional zones and accessible fallback controls.

**Complexity:** M.

**Drawback:** Accidental activation and gesture discoverability.

**Success measure:** Fewer phone glances without increased navigation mistakes.

### F07 Household control setup

**User and scenario:** Volume or power behaves differently because of a TV, audio receiver, or HDMI configuration.

**Problem and benefit:** Users repeatedly try ineffective controls. Learn user-confirmed preferences for the selected TV.

**Integration and approach:** Optional “Adjust controls for this TV” flow combining negotiated capabilities with explicit user feedback. Include a reset.

**Complexity:** M.

**Drawback:** Preferences become stale after hardware changes and cannot prove runtime capability.

**Success measure:** Fewer repeated ineffective actions and fewer recovery visits.

### F08 Personal TV destinations

**User and scenario:** A user repeatedly opens a playlist, channel, or supported content destination.

**Problem and benefit:** Repeated navigation inside TV apps takes time. Save a verified deep link under a useful name.

**Integration and approach:** Extend custom shortcuts with supported-provider templates and an explicit test action.

**Complexity:** M.

**Drawback:** Links, authentication, and provider behavior change. Avoid brittle timed D-pad scripts.

**Success measure:** Successful destination launches and sustained repeat use.

### F09 Room-aware TV suggestions

**User and scenario:** A multi-TV household wants the most relevant TV suggested.

**Problem and benefit:** Manual switching can be repetitive. Offer a visible suggestion based on approved signals.

**Integration and approach:** Research reliable signals first. Ordinary network discovery does not establish the room. Require deliberate selection before commands.

**Complexity:** L with high uncertainty.

**Drawback:** Permissions, privacy, battery use, and wrong-room suggestions.

**Success measure:** High suggestion acceptance with an acceptably low wrong-target rate. Reject the concept if signals are unreliable.

### F10 TV and audio routines

**User and scenario:** A household repeatedly configures compatible television and audio equipment.

**Problem and benefit:** Several separate setup actions could become one named routine.

**Integration and approach:** Explicit supported integrations, acknowledged state changes, bounded retries, and visible partial-failure recovery.

**Complexity:** L.

**Drawback:** Maintenance burden and substantial product-scope expansion.

**Success measure:** Complete routine success and low support cost. Defer until core control reliability is proven.

## 11. Delete and simplify decisions

| Item | Decision | Reason |
|---|---|---|
| Saved-TV landing page inside Remote | Remove | Duplicates device selection before the main task |
| Primary Settings tab | Move to secondary navigation | Current content does not justify equal prominence |
| Mandatory app detail page | Replace with optional details | Adds a step to a simple launch task |
| Package and launch-method information | Hide in diagnostics | Useful for troubleshooting rather than normal use |
| Microphone branding without voice transport | Replace with Search | Current icon implies a capability the app lacks |
| Android TV Now Playing heading | Rename | Foreground app is not playback state |
| Duplicate play/pause prominence | Merge | Competes with essential controls |
| Extended media keys on the main phone surface | Hide behind More controls | Adds density and pushes down volume |
| Competing stars, switches, and favorite actions | Unify | Multiple management models increase learning cost |
| Static System appearance value | Remove or implement | Current display is inaccurate |
| Automatic modal update prompt | Replace with nonblocking notice | Interrupts setup and control |
| Generic uninstall advice | Remove | Risks loss of trusted pairing and preferences |

Retain explicit Forget confirmation, secure trusted pairing, and separate protocol identity. These protections are not unnecessary complexity.

## 12. Validation and measurement

### Usability research

Use five representative participants for an initial formative round, including first-time users, frequent users, and a multi-TV household where possible. This is a discovery round, not a statistically representative study.

| Hypothesis | Task | Observable evidence | Initial acceptance target | Falsifying outcome |
|---|---|---|---|---|
| Resume reduces friction | Open the app and pause the intended TV | Selection detours, time, target errors | No repeated selection; faster median completion | Frequent wrong-TV control |
| Outcome labels resolve discovery ambiguity | Choose full TV navigation among similarly named entries | First choice and requests for explanation | At least 4 of 5 choose correctly unaided | Users still need protocol explanations |
| Stable controls reduce attention | Navigate, pause, and change volume from the couch | Phone glances and input errors | Fewer glances without more errors | Larger regions cause accidental actions |
| Recovery works without technical knowledge | Recover after an address change or expired pairing | Retry loops and completion | At least 4 of 5 recover unaided | Restarting or forgetting remains necessary |
| Shortcut redesign preserves intent | Launch an app while initially disconnected | Repeated browsing and target confusion | Original request resumes on the explicit TV | Users must locate the app again |

### Engineering validation

Run `flutter analyze`, relevant unit and widget tests, and an Android build after implementation. Add meaningful tests for state transitions and user outcomes rather than tests that merely repeat implementation details.

Prioritize tests for:

- Selected-device restoration and switching without stale async results.
- Pairing result replacement and certificate-preserving endpoint refresh.
- Launch intent cancellation, resumption, and outcome reporting.
- No stale command replay and reliable hold cancellation.
- Partial startup and discovery failure.
- Essential-control visibility, large text, long names, and keyboard-visible pairing.
- Per-TV preference migration and persistence.
- External Cast volume changes and unsupported media commands.

Physical-device coverage should include supported Android TV/Google TV families, at least one classic Cast receiver, multiple foreground apps, unavailable devices, standby behavior, network changes, and external volume changes. Add iOS checks only when an iOS build target exists.

### Product metrics

Establish a baseline before choosing numerical performance targets. Measure open-to-controls, connection success, recovery success, wrong-device actions, app-launch outcomes, shortcut usage, and repeated ineffective commands. Keep unknown outcomes separate from failures and success.

## 13. Release readiness

- Validate signing continuity so updates install over the existing application.
- Preserve and migrate trusted pairing and preference data across upgrades.
- Test update download failures, permission denial, cancellation, and installer launch outcomes.
- Verify launcher naming, branding, permissions, and supported-platform claims.
- Update README instructions and screenshots to match the redesigned flows.
- Publish a clear compatibility statement and known limitations.
- Keep a recovery build or forward-fix procedure compatible with storage migrations; do not promise rollback unless verified.
- Validate release-mode behavior and performance, not only emulator debug builds.

The current README describes capabilities and setup. Keep it aligned with actual navigation and avoid advertising accessibility or universal compatibility beyond what has been verified.

## 14. Implementation map and definition of done

| Area | Main existing files | Expected change |
|---|---|---|
| Startup | `lib/main.dart` | Independent service initialization and useful degraded states |
| Shell and device selection | `lib/features/discovery/presentation/devices_screen.dart` | Remote-first shell and unified selection |
| Session recovery | `lib/features/remote/android_tv_connection_manager.dart` | Correct target and pairing replacement |
| Commands and state | `lib/features/remote/android_tv_remote_controller.dart` | Shared observable state and recovery behavior |
| Protocol state | `lib/core/protocol/android_tv/android_tv_remote_client.dart` | Careful use of reported state and optional IME work |
| Phone remote | `lib/features/remote/presentation/android_tv_remote_screen.dart` | Essential control hierarchy and honest labels |
| Directional input | `lib/features/remote/presentation/widgets/directional_pad.dart` | Matching visible and interactive regions |
| Cast control | `lib/features/remote/presentation/cast_remote_screen.dart` | Correct session actions and reconciled media state |
| Pairing | `lib/features/pairing/presentation/pairing_screen.dart` | Accessible input and guarded submission |
| App experiences | `lib/features/apps/presentation/` | Direct launch and unified management |
| Shortcut persistence | `lib/features/apps/app_shortcut_store.dart` | Per-TV favorites and explicit ordering |
| Theme and responsiveness | `lib/shared/presentation/` | Contrast, components, motion, and height-aware layouts |
| Settings and updates | `lib/features/settings/`, `lib/features/update/` | Accurate settings and nonblocking updates |
| Android packaging | `android/app/src/main/AndroidManifest.xml` | Product label and verified permission behavior |

An upgrade is complete when its intended user outcome works, its failure and cancellation states are defined, supported capabilities are accurately presented, relevant automated checks pass, and hardware-dependent behavior has been tested on representative devices.

Do not mark the full roadmap complete because screens look cleaner. The core release must demonstrate immediate access to the correct remote, reachable essential controls, reliable recovery, and truthful feedback.

## 15. Audit scorecard and references

These scores describe the audited version. They are expert judgments, not objective measurements or release targets.

| Category | Audit score | Reason |
|---|---|---|
| Visual design | 6/10 | Consistent foundation; hierarchy and contrast need work |
| Navigation | 3/10 | Duplicate selection and a separate remote navigation context |
| Usability | 4/10 | Frequent controls and recovery paths need priority |
| Accessibility | 4/10 provisional | Contrast and custom interaction concerns; assistive-technology testing outstanding |
| Feature quality | 5/10 | Useful breadth with uneven feedback and capability labeling |
| Product differentiation | 3/10 | No demonstrated compelling advantage over established remotes |
| Interaction design | 4/10 provisional | Directional affordance and outcome feedback need correction |
| Performance perception | Not evaluated | No representative connected-device measurements |
| First-time experience | 4/10 | Protocol choices and catalog presentation complicate understanding |
| Product coherence | 4/10 | Device management, launching, and remote control compete for identity |

### External references

- [Google virtual remote controls and setup](https://support.google.com/chromecast/answer/11221499?hl=en-CA): competitive baseline for keyboard, navigation, media, and quick access.
- [Android touch target guidance](https://support.google.com/accessibility/android/answer/7101858?hl=en): recommended interactive target dimensions.
- [WCAG contrast minimum guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html): normal-text contrast benchmark and exceptions.

The existing source files listed above are the implementation evidence for repository-specific findings. Recommendations extending beyond those findings require validation before committing to scope.
