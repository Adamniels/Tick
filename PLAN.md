# Tick — Implementation Plan

The brief (`CLAUDE.md`) says **what** to build. This file says **how, in what order, and where we are**.

## How to use this file

- Work one milestone at a time. Finish its acceptance criteria and check in with Adam before starting the next.
- Tasks are sized for roughly one session. Tick `[x]` when a task is done **and** verified (builds, tests pass, manually checked where relevant).
- Every milestone ends with the verification gate:
  ```bash
  xcodebuild -scheme Tick -destination 'platform=macOS' build
  xcodebuild -scheme Tick -destination 'platform=macOS' test
  ```
- ☁️ marks a task that changes the SwiftData model. Any such change must follow the CloudKit rules in the brief and be logged in the schema change log at the bottom, and the schema must be deployed to production before the archived app is used.
- New decisions go in the decision log. New open questions go in the open questions section until they're resolved.

Status legend: ⬜ not started · 🟨 in progress · ✅ done

## Progress

| # | Milestone | Status |
|---|-----------|--------|
| 0 | Housekeeping | ✅ |
| 1 | Foundation: models, sync, menu bar timer, projects and tags | ✅ (sync test done in M6, 2026-10-03) |
| 2 | The popup and pomodoro | ✅ |
| 3 | Reminders | ✅ |
| 4 | Main window: entries | ✅ |
| 5 | Statistics | ✅ |
| 6 | Polish and install | ✅ (installed and verified 2026-09-25; two-Mac sync test done 2026-10-03) |
| 7 | Calendar day view (+ data export) | ✅ |
| 8 | Later: Toggl import | ⬜ |

---

## Milestone 0 — Housekeeping

Goal: a clean project base before any feature code.

- [x] Add a standard Xcode `.gitignore` and untrack `Tick.xcodeproj/xcuserdata/`. Commit a shared `Tick` scheme instead (`xcshareddata/`), so the test action is explicit.
- [x] Switch to Swift 6 language mode (keep MainActor default isolation). Fix any template warnings.
- [x] Add a unit test target `TickTests` using Swift Testing, with one trivial test so the `test` command runs. The target is hosted by the app and uses MainActor default isolation like the app.
- [x] Create the folder structure from the brief. Existing files were moved into `App/`, `Models/`, and `Views/`. Git doesn't track empty folders, so `Services/`, `Utilities/`, and the `Views/` subfolders are created when their first file lands.
- [x] Fix the template crashing on launch (it also broke the test host): CloudKit is temporarily disabled on the template container, see M1.

**Done when:** the app builds, `xcodebuild test` passes, and `git status` is clean after a build.

---

## Milestone 1 — Foundation

Goal: a menu bar app that starts and stops a timer, synced via CloudKit, with colored projects and tags.

### Model and storage
- [x] ☁️ Replace `Item` with `Project`, `Tag`, `TimeEntry`, and `PomodoroSession` exactly as in the brief. Delete `Item.swift` and `ContentView.swift`.
- [x] `ModelContainer` with `cloudKitDatabase: .private("iCloud.com.adamniels.Tick")`, replacing the temporary `cloudKitDatabase: .none` from M0. Handle container creation errors with a visible message rather than a crash where feasible. (On failure the app falls back to an in-memory store and the panel shows a red "Not saving" banner. The store is named `Tick.store`, decision D13.)
- [x] When the app runs as the unit test host, use an in-memory store without CloudKit, so tests never touch real data or iCloud.
- [x] `Utilities/Color+Hex.swift`: `Color` ↔ hex string, with unit tests (round trip, invalid input falls back to the default grey).

### Timer logic
- [x] `TimerService`: `start(description:project:tags:)` stops any running entry first; `stop()`; `continue(from:)` copies description, project and tags. Elapsed time is always derived from `start`.
- [x] Duplicate running entry resolution (decision D6): when more than one entry has `end == nil`, keep the newest, set each older entry's `end` to the start of the next newer one. Pure function plus unit tests.
- [x] Run the resolution on launch and after remote changes arrive. Implemented in the status item's refresh, on every save and every second (decision D12). Unit tested; the two-Mac check is deferred to M6 (D18).

### Menu bar
- [x] Replace `WindowGroup` with a menu bar item. No Dock icon. `MenuBarExtra` failed (label never updated), so this is now `NSStatusItem` + `NSPopover` owned by `AppDelegate` (decision D16).
- [x] Label: `● 0:42:13 Operation Rollout` in the project color while running, an icon only when idle. Must update every second. **Risk hit and resolved:** the `MenuBarExtra` label stayed on the idle icon while running, so we switched to `NSStatusItem` (D16).
- [x] Panel: description field, project picker (non-archived only), multi-tag picker, start/stop button. (No pomodoro placeholder, decision D15.)
- [x] Panel: today's entries with a daily total and a "Continue" action per entry (decision D8c). ▶ shows only on hover, right-click gives Continue / Delete (decision D17). Fixed: the list collapsed to zero height inside the popover.
- [x] Panel: "Open Tick" (main window) and "Quit" buttons.

### Projects and tags
- [x] Minimal main window (`NSWindow` hosting SwiftUI, D16) with Projects and Tags sections. M4 extends this window.
- [x] Create, rename, recolor (`ColorPicker` → hex), archive and unarchive for both projects and tags.
- [x] Archived items are hidden from pickers but still shown on existing entries.

### Manual verification (Adam)
Everything under Menu bar and Projects and tags is implemented, and builds and tests pass. It stays unticked until checked by hand:
- [x] Idle menu bar shows the stopwatch icon. No Dock icon.
- [x] Running: the label shows a **colored** dot (grey when the entry has no project), a clock that ticks every second, and the project name (or description). It updates immediately on Start and Stop.
- [x] Panel: start with Return, project picker shows colored dots, tag chips toggle, Stop works, today's list shows all entries and the total updates, ▶ appears on hover and starts a copy, right-click → Delete removes an entry.
- [x] "Open Tick" brings the main window to the front. Projects and tags: add (name field is focused), rename, recolor, archive, show archived, unarchive.
- [x] Archived project disappears from the panel picker but stays on today's entries.

### Sync check
Deferred to M6 (decision D18): only one Mac is available right now. Done 2026-10-03, see M6.

**Done when:** you can track real work from the menu bar all day, projects and tags sync between the Macs, and the tests pass.
**Reminder:** deploy the CloudKit schema before using an archived build (first time ever).

---

## Milestone 2 — The popup and pomodoro

Goal: the unmissable popup exists, and pomodoro uses it.

### OverlayController
- [x] One `NSPanel` per `NSScreen`: `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, borderless, full-screen dimmed background, card centered on each screen.
- [x] Panels can become key (subclass override) so buttons work immediately; `NSApp.activate` on show.
- [x] Esc, clicking outside, and Cmd+W do nothing. The popup closes only via a button.
- [ ] Rebuild the panels when the screen configuration changes while shown. (Implemented, not yet exercised: plug or unplug a monitor while a popup shows.)
- [x] A content model (title, message, list of actions) so M2 and M3 reuse one overlay view (`Views/Overlay/`). Requests have ids so they can be dismissed from elsewhere and aren't queued twice.
- [x] Play the configured sound on show.
- [ ] Only one overlay at a time. If a second one is requested while one is shown, queue it. (Implemented, first exercised in M3 when reminders can coincide with pomodoro.)
- [x] No Return shortcut, and buttons are disabled for the first 0.6 s so a stray click or keypress can't answer the popup (D19).
- [x] Manual test checklist: full screen app, other Space, second monitor, while in a video call, while a sheet is open in another app.

### Settings (first version)
- [x] Settings section in the main window (D20) with local `@AppStorage` values: pomodoro durations, dim opacity, card size, sound (from system sounds), and a **Test popup** button.

### Pomodoro
- [x] Phase state machine as a pure type: work → short break, with a long break after every 4th work block; durations from settings (default 25/5/15). Unit tests for the sequence, the long break count, and extensions.
- [x] ☁️ `PomodoroService`: creates `PomodoroSession` records; checks the synced `plannedEnd` every second from the `AppDelegate` refresh loop (D23), never a stored countdown. `PomodoroSession` gains `runID` and `endedAt` (D21). Transition rules are in D22. Unit tested end to end with a spy overlay.
- [x] Pomodoro toggle in the panel, remembered between timers (decision D8a).
- [x] After a work block, popup: **Start break** / **5 more minutes** / **End pomodoro**.
- [x] After a break, popup: **Start next block** / **Extend break 5 min** / **End**.
- [x] Breaks stop the time entry, and the next work block continues it as a new entry with `isPomodoro = true` (decision D8b). Setting to keep the entry running instead.
- [x] Menu bar shows the phase and remaining time, for example `🍅 18:42`, or a break symbol during breaks.
- [x] If `plannedEnd` passed while the Mac was asleep, show the popup on wake. (Covered by the per-second check; verify manually.)
- [x] Running entry: the description is editable in the panel (Adam's request). Return no longer stops the timer. Editing past entries stays in M4. (Now applied on Return rather than per keystroke, D24.)
- [x] Fix: the panel must not move while open (D24): the popover points at an invisible anchor window placed over the item when it opens, not at the item itself. The running description is applied on Return (or focus loss, or closing the panel).
- [x] Multi-Mac (decision D4): each Mac shows its own popup, and closes it when synced data shows the phase has been handled elsewhere. Unit tested; the real two-Mac check is part of the deferred M6 sync test (D18).

**Done when:** a full 4-block pomodoro cycle works end to end, the popup is impossible to miss on every screen and Space, and the tests pass.

---

## Milestone 3 — Reminders

Goal: Tick notices when you're not tracking, forgot to stop, or were away.

- [x] Settings: work hours (weekdays plus start and end time), idle threshold X, forgotten timer threshold Y (default 3 h), presence threshold, away minimum, snooze length, and an on/off switch per reminder.
- [x] Pure `ReminderEvaluator` (inputs: time, running entry, pomodoro status, presence, snoozes) and `WorkHours` (overnight windows, wall-clock times across DST), unit tested. Run from the per-second refresh loop (D23).
- [x] Presence (decision D5): screen unlocked and last user input less than N minutes ago (`CGEventSource.secondsSinceLastEventType`).
- [x] **Idle reminder:** no running timer for X minutes, within work hours, user present, no pomodoro active (D25). Popup offers quick start of the 3 most recent distinct entries, **Start new timer** (opens the panel), and **Remind me in N min**. Unit tested.
- [x] **Forgotten timer:** running longer than Y hours. Popup offers **Still working** (snooze another Y), **Stop at selected time** (time field in the popup, D27), and **Stop now**. Unit tested.
- [x] **Sleep and lock:** `AwayTracker` over sleep, lock and display sleep (D26). On return, if a timer ran through an away period longer than the minimum, popup: **Remove away time** (split around the gap) / **Keep the time** / **Stop at departure**. Unit tested.
- [x] Popups close themselves when their reason is resolved elsewhere (timer started or stopped, possibly on another Mac). Unit tested.
- [x] Reminders never interrupt an active pomodoro popup. They queue behind it. (Uses the M2 overlay queue; exercise manually.)

### Manual verification (Adam)
Set short thresholds first (Settings → Reminders: idle 1 min, forgotten 1 h is the minimum, away 1 min) and make today a work day with hours covering now.
- [x] Idle: stop all timers, keep using the Mac; after the threshold the popup asks what you're working on. Try a quick-start button, then **Start new timer** (the panel opens), then **Remind me in N min**.
- [x] Idle does not appear when you're away from the keyboard longer than the presence setting, outside work hours, or during a pomodoro break.
- [x] Away: with a timer running, lock the screen (Ctrl+Cmd+Q) for more than the minimum, unlock: the popup offers to remove the away time. Check the entries in the panel afterwards.
- [x] Forgotten: covered by unit tests (manual test optional, the minimum threshold is 1 h).
- [x] Settings: work day toggles and start and end times save and take effect.

**Done when:** each reminder triggers correctly in manual tests, and the evaluator and service tests pass.

---

## Milestone 4 — Main window: entries

Goal: full control of history.

- [x] Main window as a `NavigationSplitView`: Entries (default), Projects, Tags, Settings (Statistics added in M5).
- [x] Entries list grouped by day with day totals. The running entry is shown live. Fetches 14 days at a time with "Show earlier days" rather than all history.
- [x] Overlap detection as a pure function (one sorted pass, unit tested). Overlapping entries are marked with an orange warning icon.
- [x] Pure day grouping and draft validation, unit tested. `TimerService.save(_:to:)` creates or updates from a draft, unit tested.
- [x] Edit sheet on a draft (D28): description, project, tags, start, end. Validation: end after start; a running entry can't start in the future and its end isn't editable here (D29). Updates `updatedAt`.
- [x] Add a manual entry with the same sheet (defaults to the last hour).
- [x] Double-click to edit; right-click for Edit, Continue and Delete; the Delete key deletes. Delete asks for confirmation.
- [x] Shared `ProjectPicker` and `TagSelector` used by the panel and the editor.

### Manual verification (Adam)
- [x] Entries shows today and earlier days with correct totals; the running entry ticks.
- [x] Double-click an entry, change description, project, tags and times, Save; then again with Cancel (nothing changes).
- [x] Try an end before the start: Save is disabled with a message.
- [x] Add a manual entry that overlaps another: both show the orange warning.
- [x] Right-click → Continue starts a timer; right-click → Delete… and the Delete key both ask before deleting.
- [x] "Show earlier days" loads more history.

**Done when:** you can fix any mistake in your history without touching the menu bar, and the tests pass.

---

## Milestone 5 — Statistics

Goal: see where the time goes.

- [x] Period picker: today, this week, this month, custom range. The previous period is compared at the same point in time (D32). Pure `StatsPeriod`, unit tested (Monday-first weeks, month lengths, reversed custom dates).
- [x] Aggregation as pure functions with unit tests (`Statistics.compute`): clip entries to the period, count the running entry up to now, split entries across midnight for per-day data, a "No project" bucket, archived projects included, overlap as summed minus covered time (D31).
- [x] Header: total time in the period, change against the previous period, and the overlap notice.
- [x] Charts (Swift Charts, project colors, archived projects included): time per project, time per tag (D30, with footnote), time per day stacked by project, and completed pomodoros per day.
- [x] Resolve open question Q1 (tag time counting) before building the tag chart. (D30; Q2 resolved as D31.)

### Manual verification (Adam)
- [x] Statistics (main window) shows this week: total, comparison line, and the four charts in project colors.
- [x] Switch Today, This week, This month and Custom; the numbers change sensibly.
- [x] A period with an overlapping manual entry shows the orange overlap notice.
- [x] Spot-check: one day's total in Statistics (Today) matches the day total in Entries.

**Done when:** the numbers match a manual calculation for a sample week, and the tests pass.

---

## Milestone 6 — Polish and install

Goal: an app you install once and forget about.

- [x] Add `KeyboardShortcuts` 3.1.0 (SPM, pre-approved in the brief; `Package.resolved` committed).
- [x] Global shortcuts, recorded in Settings → Shortcuts, no presets (D33): **Start or stop timer** (stops the running timer, or continues the most recent entry), **Open Tick panel**, and **Open Tick window** (added at Adam's request).
- [x] Launch at login toggle via `SMAppService.mainApp` (Settings → General), including the "requires approval" case.
- [x] Settings reorganized into tabs: General, Pomodoro, Reminders, Popup, Shortcuts.
- [x] App icon (generated: white stopwatch on an orange-red gradient). The menu bar icon stays the SF Symbol `stopwatch`, a template image.
- [x] Two-Mac sync test (deferred from M1, D18), see the install steps below. Done 2026-10-03 with the second Mac, confirmed by Adam.

### Install (Adam; needs your Apple account)
1. **Check the development schema.** CloudKit Console → `iCloud.com.adamniels.Tick` → Development → Schema → Record Types. All four must exist: `CD_Project`, `CD_Tag`, `CD_TimeEntry`, `CD_PomodoroSession` (with `CD_runID` and `CD_endedAt`). A record type only appears after its first record is saved, so if one is missing, create one in a debug build (for example a tag) and check again.
2. **Deploy the schema.** CloudKit Console → Deploy Schema Changes → deploy to Production.
3. **Archive.** Destination **Any Mac**, then Xcode → Product → Archive. (Hardened Runtime is enabled; notarization requires it.) In the Organizer: Distribute App → **Direct Distribution**. Xcode signs with Developer ID and notarizes; this build uses the **production** CloudKit environment. Export `Tick.app`.
4. **Install.** Quit the debug Tick (Quit in the panel), move the exported `Tick.app` to Applications, open it.
5. **Login item.** Settings → General → "Open Tick at login". Approve in System Settings if asked.
6. **Production starts empty.** The exported build uses its own local store, `Tick-Production.store` (D36), so nothing tracked with debug builds, including the test entries, is uploaded to production. Debug builds keep using `Tick.store` and the development environment; the two never mix.
7. **Second Mac.** Copy the same exported `Tick.app` to its Applications, same Apple ID, open it, then run the two-Mac sync test:
   - Create a project on one Mac; it appears on the other within about a minute.
   - Start a timer on both at almost the same time; after sync only the newest keeps running (D6).
   - Run a 1-minute pomodoro with both awake: both show the popup, and answering on one closes it on the other (D4).

### Manual verification (Adam)
- [x] Record both shortcuts; start/stop and open panel work from any app.
- [x] Settings tabs all show their settings; changes still take effect.
- [x] The installed app shows the new icon in Finder and Launchpad.
- [x] After a restart (or log out and in), Tick starts by itself.

**Done when:** both Macs run the archived build from `/Applications`, start at login, and sync.

---

## Milestone 7 — Calendar day view

Goal: see a day like Toggl and fix or add entries directly on a timeline (moved ahead of the install, D34).

- [x] Calendar section in the main window: header with previous/next day (also ⌘← ⌘→), date with a Today badge or button, day total, zoom, and new entry.
- [x] Scrollable 24-hour grid, opening at the current time (or the first entry on other days), with a current-time line.
- [x] Entries as blocks in project colors (description, project, duration); the running entry dashed and growing live; overlapping entries side by side in columns.
- [x] Click a block to edit (the M4 editor); right-click for Edit, Continue, Delete.
- [x] Drag on empty space to create (editor opens prefilled; Cancel creates nothing); click on empty space for a 30-minute entry.
- [x] Drag a block's top or bottom edge to resize, or the whole block to move. Snaps to 5 minutes, minimum 5 minutes. A running entry: start only, not after now. A block crossing midnight: no dragging on the continuing side.
- [x] Pure `CalendarLayout` (positions, overlap columns, snapping, drag results with limits), unit tested.

### Data export (added before install, D35)
- [x] `ExportArchive` format v1: projects, tags, entries (relationships as id references), pomodoro sessions, local settings; ISO 8601 UTC times exact to the millisecond. JSON round trip and CSV (RFC 4180) unit tested.
- [x] Settings → Data: **Export all data (JSON)…** and **Export time entries (CSV)…** through the system save panel. Sandbox: user-selected files are now read-write (was read-only).
- [x] Manual: export both, open the JSON in a text editor and the CSV in Numbers; the data matches Entries.

### Manual verification (Adam)
- [x] Today looks like the Toggl day view: blocks at the right times, colors, the running entry growing, the now line.
- [x] Previous/next/Today and zoom work.
- [x] Create by dragging and by clicking; Cancel creates nothing.
- [x] Resize both edges and move a block; the change sticks and shows in Entries.
- [x] Overlapping entries appear side by side.

---

## Milestone 8 — Later

- [ ] Import history from Toggl CSV (Settings → Data).
- [ ] Restore from a Tick JSON export (format v1, D35), for moving between databases or Macs.

---

## Cleanup after install (2026-09-25)

A review pass after M7, one commit per item, with build, tests and a Release build as the gate.

- [x] `TrackingService` extracted as the single start/stop/continue entry point; `PomodoroService` keeps phases and the popup (D38).
- [x] Failed actions are shown, not just logged: `ErrorReporter` with a panel banner and a main-window alert (D39).
- [x] Helpers moved to their owners: `TimeEntry.displayLabel`, `TimeEntry.queryLookback`, `EditTarget` next to `EntryEditor`.
- [x] One shared delete confirmation for Entries and Calendar.
- [x] Calendar split into view shell, `CalendarTimeline` (explicit inputs and callbacks) and `CalendarBlock`.
- [x] Settings split into one file per tab under `Views/Settings/`; `ExportFile` moved out of `Services/`.
- [x] Stale comments fixed, unused log categories removed.
- [x] `CLAUDE.md` brief brought in line with the code and decisions.

---

## Fixes from GitHub issues (from 2026-10-03)

Open work is tracked as GitHub issues; this lists what landed and the decisions behind it.

- [x] #3 and #6: the main window opens on the current Space and display, and opening it no longer leaves the menu bar blank (D40). Verified by hand.
- [x] #1: Statistics steps through days, weeks and months with ‹ ›, shows the period, and has a button back to the current one (D41). Verified by hand. Also fixed: a completed period lost the end of a longer previous period in its comparison, and the stats query kept its old range across midnight.
- [x] #4: "Start break" in the panel during a work block, so a break can start early without ending the pomodoro (D42). Verified by hand.
- [x] #2: a timer bar at the top of the main window, in every section: start, stop, edit the running description, and the pomodoro controls (D43). Verified by hand, including the narrowest window.


---

## Releases

Each release: bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` (app target), deploy the CloudKit schema if the schema log has an undeployed row, archive and export as in M6, replace `Tick.app` on both Macs, then tag the release commit `vX.Y`.

| Version | Date | Tag | Contents |
|---------|------|-----|----------|
| 1.0 (1) | 2026-09-25 | none | M0 to M7, first install. |
| 1.1 (2) | 2026-10-03 | `v1.1` | #1, #2, #3, #4, #6. No schema change. Installed on both Macs. |
---

## Decision log

| # | Date | Decision | Why |
|---|------|----------|-----|
| D1 | 2026-09-24 | Deployment target macOS 26 (brief said 14). | All of Adam's Macs run 26. It avoids known SwiftData and CloudKit bugs in older versions. |
| D2 | 2026-09-24 | Swift 6 language mode from the start. | Timers, sleep and wake, and AppKit panels involve concurrency. Strict checking is cheap on an empty codebase. |
| D3 | 2026-09-24 | `.gitignore`, untrack `xcuserdata`. | Per-user Xcode state doesn't belong in git. |
| D4 | 2026-09-24 | Every awake Mac shows the popup. It closes when synced state shows the phase was handled. | Unmissable wherever you are. Sync delay is acceptable. |
| D5 | 2026-09-24 | The idle reminder also requires presence (unlocked, recent input). | Avoids popups piling up on a Mac nobody is using. |
| D6 | 2026-09-24 | With two running entries, the older one gets `end` = the newer one's `start`. | This is how the brief's rule is interpreted. |
| D7 | 2026-09-24 | No `PomodoroSession` ↔ `TimeEntry` relationship for now. | Pomodoros per day don't need it. It can be added later as a schema change if per-project pomodoro stats are wanted. |
| D8a | 2026-09-24 | Pomodoro is turned on per timer via a toggle in the panel, remembered between timers. | Not all work suits pomodoro. |
| D8b | 2026-09-24 | Breaks stop the entry, and the next block starts a new entry (`isPomodoro = true`). Setting to override. | Honest stats with no special cases. |
| D8c | 2026-09-24 | The panel shows today's entries plus a daily total. No separate "Today" view. | Same query, less UI. |
| D9 | 2026-09-24 | Progress is tracked in `PLAN.md`. The brief stays in `CLAUDE.md`. | Git-tracked, diffable, and readable by both of us. |
| D10 | 2026-09-24 | Plan, code, and comments in English. The brief stays in Swedish. | Global convention: English for technical work. |
| D11 | 2026-09-24 | Swift Testing target for pure logic. UI is tested with manual checklists. | The real bugs live in time math and state machines. |
| D12 | 2026-09-24 | Duplicate running entries are resolved by the always-alive menu bar label, observing a `@Query` of running entries, instead of the store's remote change notification. | SwiftData doesn't reliably expose that notification. One trigger covers launch, local changes, and CloudKit imports. Resolution is deterministic, so concurrent resolution on two Macs writes the same values. |
| D13 | 2026-09-24 | The synced store is named `Tick.store`. The template's `default.store` is left untouched (safe to delete by hand). | Avoids migrating the template `Item` schema and avoids deleting files. |
| D14 | 2026-09-24 | `@Model` types, `ColoredLabel`, and pure utilities (`HexColor`, `DurationFormat`) are `nonisolated`. Services and views stay on MainActor. | Under MainActor default isolation, a custom protocol refining `PersistentModel` otherwise becomes a main-actor-isolated conformance, which SwiftData rejects. Models are bound to their context, not to an actor. |
| D15 | 2026-09-24 | No disabled pomodoro placeholder in M1. The toggle arrives with M2. | Dead UI. |
| D16 | 2026-09-24 | The menu bar item is an `NSStatusItem` with an `NSPopover`, and the main window an `NSWindow` with `NSHostingController`, all owned by `AppDelegate`. The SwiftUI views are unchanged. D12 is updated: duplicates are resolved in the status item's refresh (every save plus a one-second tick that fetches the running entry). | Adam's test showed the `MenuBarExtra` label never updating from its `@Query`. AppKit gives full control of the title and a non-template colored dot. `openWindow` doesn't work outside SwiftUI scenes, so the main window moved to AppKit as well. The per-second fetch is trivial and also picks up CloudKit imports. |
| D17 | 2026-09-24 | M1 panel entries: ▶ shows only on hover; right-click → Continue / Delete, without confirmation. | One stray click created entries that couldn't be removed until M4. A context-menu delete is already a deliberate two-step action. |
| D18 | 2026-09-24 | M1 is closed without the two-Mac sync test. It moves to M6, before the install checklist. | Only one Mac is available now. Sync logic is unit tested, and M2 to M5 don't depend on it. Risk: a sync problem is found late. The quick single-Mac CloudKit Console check reduces that risk. |
| D19 | 2026-09-24 | The popup has no keyboard shortcut, and its buttons ignore input for 0.6 s after appearing. Cmd+Q is not blocked. | The popup activates Tick while you may be typing or clicking elsewhere. A stray Return or click must not answer it. Blocking quit would be hostile. |
| D20 | 2026-09-24 | Settings are a section of the main window, not a SwiftUI `Settings` scene. | The brief lists settings in the main window. A `Settings` scene can't be opened reliably from the AppKit popover (same reason as D16). |
| D21 | 2026-09-24 | `PomodoroSession` gains `runID` (groups one run) and `endedAt` (nil = active phase). | Long breaks need a count of completed blocks per run. `endedAt` is how another Mac learns a phase was handled so it can close its popup (D4). Free now: production was never deployed. |
| D22 | 2026-09-24 | Pomodoro and timer rules: "End pomodoro" also stops the timer. Stopping the timer ends the run (a block cut short doesn't count). Starting with pomodoro off ends the run. Starting with pomodoro on during a break starts the next block. Switching task mid-block keeps the block. | Predictable: pomodoro never runs without you tracking, and tracking is never silently stopped except by a break (configurable). |
| D23 | 2026-09-24 | `AppDelegate` owns one refresh loop: every second (aligned to the displayed clock) and after every save it resolves duplicates, runs the pomodoro check, and redraws the menu bar. `PomodoroService` takes an injectable clock for its popup actions. | One source of timing. Wake from sleep and CloudKit imports need no special handling because every tick re-reads state. The clock makes button actions testable in simulated time. |
| D24 | 2026-09-24 | Keep the system `NSPopover`, but anchor it to an invisible, click-through window placed over the menu bar item when it opens, so it never moves while open. The running description is applied on Return (or focus loss, or closing the panel), not per keystroke. | A popover follows its anchor, and the item's width follows its title (starting a timer grows it leftwards), so anchored to the item it jumped, sometimes in the wrong direction. Rejected: a custom borderless dropdown (failed three times: at the screen origin, then at zero size), locking the item's width while open (macOS wrapped the title onto two lines), and re-anchoring on width changes (jumped, sometimes the wrong way). A fixed anchor window is the standard menu bar app technique. |
| D25 | 2026-09-24 | Reminders are evaluated locally on each Mac. The idle clock counts from the latest of: last entry end, app launch, return from away, and the start of today's work window. No idle reminder while a pomodoro phase is active. | Presence is local, so idle belongs to the Mac you're at. Counting from launch, return and work start avoids a popup the moment you log in or come back. A pomodoro break is deliberate time without a timer. |
| D26 | 2026-09-24 | "Away" means asleep, locked, or displays asleep; the period ends when the last of them clears. "Remove away time" splits the entry: it ends at departure and continues as a new entry from now. | Displays sleeping without a lock is also time away from the Mac. Splitting keeps both halves correct and visible, instead of silently shifting the start time. |
| D27 | 2026-09-24 | Popups can carry an optional time field (`OverlayDateInput`), and more than three buttons stack vertically. | "Stop at selected time" needs a time input. The idle popup has up to five choices, which don't fit side by side. |
| D28 | 2026-09-24 | The entry editor works on a draft copy (`EntryDraft`) and saves only on Save. | Live binding would save, and sync, every keystroke, and Cancel couldn't undo. A draft also makes validation a pure, testable function. |
| D29 | 2026-09-24 | A running entry's end can't be edited in the editor; stopping goes through the panel. | Stopping has pomodoro rules (D22). Keeping one way to stop avoids a second path that bypasses them. |
| D30 | 2026-09-24 | (Q1) An entry with several tags counts its full time toward each tag; the tag chart says tag totals can exceed the period total. Untagged time gets a "No tag" bar. | Splitting time between tags would give numbers no one can trace back to entries. |
| D31 | 2026-09-24 | (Q2) Statistics sum entry durations everywhere, so per-project numbers add up to the total. When the period contains overlaps, a notice shows the overlapping time (sum minus covered time) and how many entries, pointing to Entries where they're marked. | Overlaps only come from manual entries or edits and are almost always mistakes; the stats should point at them, not silently compensate. Rejected: union of intervals (per-project stops adding up) and proportional splitting (hard to explain). |
| D32 | 2026-09-24 | The comparison with the previous period is at the same point in time: this week so far versus last week up to the same weekday and time (likewise for today, the month, and a custom range, which compares with the same length right before it). | Comparing a partial period with a complete one would almost always look like a drop. |
| D33 | 2026-09-24 | Global shortcuts with no presets: start/stop (stops the running timer, or continues the most recent entry when none runs; opens the panel if there is no history), open panel, and open the main window. | Continuing the last entry is the most useful one-key start. Any preset risks colliding with another app's shortcut, so Adam records his own. |
| D34 | 2026-09-24 | The calendar day view (brief: "later") is built before the install, as M7; Toggl import becomes M8. The calendar is its own main-window section; blocks can also be moved, like Toggl; drags snap to 5 minutes. | Adam wants it before installing. A list and a timeline are different tools, so both get a direct sidebar entry. Moving is the natural companion to resizing. 5-minute snapping keeps drags precise without fiddling. |
| D35 | 2026-09-24 | Export lives in Settings → Data: all data as versioned JSON (`formatVersion` 1; ids kept, relationships as id references; ISO 8601 UTC exact to the millisecond; includes local settings) and time entries as CSV (Toggl-like columns plus ISO times). User-selected files become read-write in the sandbox. | Export is rare, so it belongs in Settings, not the sidebar (and Tick has no File menu). JSON is the complete, re-importable archive for moving to a new app or database; CSV is for spreadsheets and other trackers. ISO 8601 is portable; sub-millisecond precision isn't worth a Swift-only format. Import comes in M8. |
| D36 | 2026-09-24 | One local store per CloudKit environment: the app reads its own `icloud-container-environment` entitlement at launch; Production uses `Tick-Production.store`, anything else keeps `Tick.store`. Export times are integer milliseconds. | Debug and release builds share the sandbox container (same bundle id). Opening the development store with production mirroring would have uploaded all test data to production. The entitlement, not the build configuration, is what decides the CloudKit environment. Integer milliseconds make export → import → export stable (formatters truncate float noise). |
| D37 | 2026-09-24 | Hardened Runtime enabled for the app target, with no exceptions. | Required for notarization (Direct Distribution). Nothing Tick does (Carbon hotkeys, input idle time, panels, SwiftData/CloudKit, SMAppService, statically linked KeyboardShortcuts) needs a runtime exception. Tests still run with the injected test bundle. |
| D38 | 2026-09-25 | `TrackingService` is the single entry point for start, stop and continue, applying D22; `PomodoroService` only handles phases, transitions and the popup, exposing `beginWorkBlock` and `endRun` to it. | All tracking went through `PomodoroService`, even without pomodoro, which hid where tracking starts and stops. Behavior unchanged; the existing tests cover it. |
| D39 | 2026-09-25 | User actions run through one `ErrorReporter` (injected into services, in the environment for views): failures are logged and shown as a dismissible panel banner and a main-window alert. The per-second refresh only logs. | Six helpers only logged errors, so a failed save was invisible. The refresh loop would flood the UI with a persistent error. The service wiring is covered by review, not tests: forcing a real save failure would need a test-only hook in production code. |
| D40 | 2026-10-03 | (#3, #6) The main window is `.moveToActiveSpace` and `.fullScreenAuxiliary`, is placed on the display with keyboard focus (`NSScreen.main`; centred there if it is elsewhere, pure `WindowPlacement`), and is ordered in before Tick activates. Tick's own window can no longer go full screen. | Activating first made macOS switch to the Space the window was last on, and that switch left the system menu bar blank. The popover and the popup already ordered in first. |
| D41 | 2026-10-03 | (#1) Statistics periods are Day, Week, Month and Custom, stepped with a relative `offset` (0 is current, negative is past; no future). Changing the kind resets it; Custom keeps its date pickers. A completed period compares with the whole previous period (refines D32). The stats view recomputes the period every minute and keys its content on the query range, so the query follows midnight. | An offset never goes stale, unlike a stored date: after midnight 0 is still today. Comparing with "previous start + elapsed" cut a 31-day month or a DST day short. The window is only hidden when closed (D16), so a query fixed at creation showed last week's range on Monday morning. |
| D42 | 2026-10-03 | (#4) A break can start early from the panel through the same `startBreak` as the popup. A work block counts as completed only if it reached its planned end, so an early break neither counts as a pomodoro nor brings the long break closer. | Same rule as stopping early (`endRun`), so pomodoro stats stay honest. Tradeoff: with early breaks the long break comes later in the cycle. |
| D43 | 2026-10-03 | (#2) The timer controls are one shared view, `TimerControls` in `Views/Timer/`, used by the panel and by a bar above every main-window section. The bar is one row when there is room and stacks like the panel when narrow (`ViewThatFits`). Only the panel starts the timer on Return anywhere; in the window, Return starts it only from the description field. | One implementation, so the panel and the window can't drift apart, and new controls (like #4's) appear in both. A toolbar was too narrow for description, project and tags. A window-wide Return default would start an empty timer from any section with nothing focused. |

## Open questions

_None right now. Q1 and Q2 were resolved as D30 and D31._

## CloudKit schema change log

Each model change must be deployed via CloudKit Console → Deploy Schema Changes before an archived build uses it.

| Date | Change | Deployed to production |
|------|--------|------------------------|
| — | Initial schema (M1) | ✅ (before the 2026-09-25 install; production syncs, log updated 2026-10-03) |
| 2026-09-24 | `PomodoroSession`: added `runID: UUID`, `endedAt: Date?` (M2, D21). Production has never been deployed, so this folds into the first deploy. | ✅ (with the initial schema) |
