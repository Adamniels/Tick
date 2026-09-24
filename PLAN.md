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
| 1 | Foundation: models, sync, menu bar timer, projects and tags | 🟨 |
| 2 | The popup and pomodoro | ⬜ |
| 3 | Reminders | ⬜ |
| 4 | Main window: entries | ⬜ |
| 5 | Statistics | ⬜ |
| 6 | Polish and install | ⬜ |
| 7 | Later: calendar view, Toggl import | ⬜ |

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
- [ ] Run the resolution on launch and after remote changes arrive. Implemented via the menu bar label's `@Query` of running entries (decision D12). Verify in the two-Mac test.

### Menu bar
- [ ] Replace `WindowGroup` with `MenuBarExtra` (`.window` style). No Dock icon.
- [ ] Label: `● 0:42:13 Operation Rollout` in the project color while running, an icon only when idle. Must update every second. **Risk:** if a `MenuBarExtra` label can't tick or color reliably, fall back to an `NSStatusItem` owned by the app delegate. Decide early in this task.
- [ ] Panel: description field, project picker (non-archived only), multi-tag picker, start/stop button. (No pomodoro placeholder, decision D15.)
- [ ] Panel: today's entries with a daily total and a "Continue" action per entry (decision D8c).
- [ ] Panel: "Open Tick" (main window) and "Quit" buttons.

### Projects and tags
- [ ] Minimal main window (`Window` scene) with Projects and Tags sections. M4 extends this window.
- [ ] Create, rename, recolor (`ColorPicker` → hex), archive and unarchive for both projects and tags.
- [ ] Archived items are hidden from pickers but still shown on existing entries.

### Manual verification (Adam)
Everything under Menu bar and Projects and tags is implemented, and builds and tests pass. It stays unticked until checked by hand:
- [ ] Idle menu bar shows the stopwatch icon. No Dock icon.
- [ ] Running: the label shows a **colored** dot, a clock that ticks every second, and the project name (or description). If the dot is grey/monochrome or the clock freezes, we switch to `NSStatusItem` (the M1 risk).
- [ ] Panel: start with Return, project picker shows colored dots, tag chips toggle, Stop works, today's list and total update, Continue starts a copy.
- [ ] "Open Tick" brings the main window to the front. Projects and tags: add (name field is focused), rename, recolor, archive, show archived, unarchive.
- [ ] Archived project disappears from the panel picker but stays on today's entries.

### Sync check
- [ ] Manual test: run debug builds on two Macs with the same iCloud account. Create a project on one, see it on the other. Start a timer on both, confirm the duplicate resolution.

**Done when:** you can track real work from the menu bar all day, projects and tags sync between the Macs, and the tests pass.
**Reminder:** deploy the CloudKit schema before using an archived build (first time ever).

---

## Milestone 2 — The popup and pomodoro

Goal: the unmissable popup exists, and pomodoro uses it.

### OverlayController
- [ ] One `NSPanel` per `NSScreen`: `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, borderless, full-screen dimmed background, card centered on each screen.
- [ ] Panels can become key (subclass override) so buttons work immediately; `NSApp.activate` on show.
- [ ] Esc, clicking outside, and Cmd+W do nothing. The popup closes only via a button.
- [ ] Rebuild the panels when the screen configuration changes while shown.
- [ ] A content model (title, message, list of actions) so M2 and M3 reuse one overlay view (`Views/Overlay/`).
- [ ] Play the configured sound on show.
- [ ] Only one overlay at a time. If a second one is requested while one is shown, queue it.
- [ ] Manual test checklist: full screen app, other Space, second monitor, while in a video call, while a sheet is open in another app.

### Settings (first version)
- [ ] `Settings` scene with local `@AppStorage` values: dim opacity, card size, sound (from system sounds), and a **Test popup** button.

### Pomodoro
- [ ] Phase state machine as a pure type: work → short break, with a long break after every 4th work block; durations from settings (default 25/5/15). Unit tests for the sequence, the long break count, and extensions.
- [ ] `PomodoroService`: creates `PomodoroSession` records; schedules the next phase end from the synced `plannedEnd` (never a stored countdown).
- [ ] Pomodoro toggle in the panel, remembered between timers (decision D8a).
- [ ] After a work block, popup: **Start break** / **5 more minutes** / **End pomodoro**.
- [ ] After a break, popup: **Start next block** / **Extend break 5 min** / **End**.
- [ ] Breaks stop the time entry, and the next work block continues it as a new entry with `isPomodoro = true` (decision D8b). Setting to keep the entry running instead.
- [ ] Menu bar shows the phase and remaining time, for example `🍅 18:42`, or a break symbol during breaks.
- [ ] If `plannedEnd` passed while the Mac was asleep, show the popup on wake.
- [ ] Multi-Mac (decision D4): each Mac shows its own popup, and closes it when synced data shows the phase has been handled elsewhere.

**Done when:** a full 4-block pomodoro cycle works end to end, the popup is impossible to miss on every screen and Space, and the tests pass.

---

## Milestone 3 — Reminders

Goal: Tick notices when you're not tracking, forgot to stop, or were away.

- [ ] Settings: work hours (weekdays plus start and end time), idle threshold X, forgotten timer threshold Y (default 3 h), presence threshold.
- [ ] `ReminderService` with one periodic check (around 30 s) that feeds a pure evaluator: (now, running entry, settings, presence) → reminder or none. Unit tests for work hours edges (midnight, weekends) and thresholds.
- [ ] Presence detection (decision D5): screen unlocked and last user input less than N minutes ago (`CGEventSource.secondsSinceLastEventType`).
- [ ] **Idle reminder:** no running timer for X minutes, within work hours, user present. Popup offers quick start of the 3–5 most recent projects, **Start new timer** (opens the panel focused), and **Remind me in 15 min**.
- [ ] **Forgotten timer:** running longer than Y hours. Popup offers **Still working** (snooze until another Y), **Stop now**, and **Stop at…** (time picker bounded between start and now).
- [ ] **Sleep and lock:** track away periods via `NSWorkspace` sleep and wake notifications plus screen lock and unlock notifications. On return, if a timer ran through an away period longer than a minimum (for example 5 min), popup: **Keep the time** / **Remove away time** (stop at away start and continue now as a new entry) / **Stop at away start**.
- [ ] Reminders never interrupt an active pomodoro popup. They queue behind it.

**Done when:** each reminder triggers correctly in manual tests (using temporarily short thresholds), and the evaluator tests pass.

---

## Milestone 4 — Main window: entries

Goal: full control of history.

- [ ] Main window as a `NavigationSplitView`: Entries, Projects, Tags (Statistics added in M5).
- [ ] Entries list grouped by day with day totals. The running entry is shown live. Fetch a bounded date range with "load more" rather than all history.
- [ ] Overlap detection as a pure function (unit tested). Overlapping entries are marked visually.
- [ ] Edit sheet: description, project, tags, start, end. Validation: end must be after start. Updates `updatedAt`.
- [ ] Add a manual entry with the same sheet.
- [ ] Delete with confirmation. "Continue" from any row.

**Done when:** you can fix any mistake in your history without touching the menu bar, and the tests pass.

---

## Milestone 5 — Statistics

Goal: see where the time goes.

- [ ] Period picker: today, this week, this month, custom range. The previous period is the one of equal length immediately before.
- [ ] Aggregation as pure functions with unit tests: clip entries to the period, count the running entry up to now, split entries across midnight for per-day data, and a "No project" bucket.
- [ ] Header: total time in the period and the change against the previous period.
- [ ] Charts (Swift Charts, project colors, archived projects included): time per project, time per tag, time per day stacked by project, and completed pomodoros per day.
- [ ] Resolve open question Q1 (tag time counting) before building the tag chart.

**Done when:** the numbers match a manual calculation for a sample week, and the tests pass.

---

## Milestone 6 — Polish and install

Goal: an app you install once and forget about.

- [ ] Add `KeyboardShortcuts` (SPM, pre-approved in the brief). Global shortcuts: start/stop toggle and open panel, both configurable in Settings.
- [ ] Launch at login toggle via `SMAppService.mainApp`.
- [ ] Settings reorganized into tabs: General, Pomodoro, Reminders, Popup, Shortcuts.
- [ ] App icon and a template menu bar icon.
- [ ] Install checklist: deploy the CloudKit schema to production, archive, export, move to `/Applications`, enable login item, and verify sync between both Macs on the production environment.

**Done when:** both Macs run the archived build from `/Applications`, start at login, and sync.

---

## Milestone 7 — Later

- [ ] Calendar day view with entries as blocks on a timeline; drag to create, drag the edges to resize.
- [ ] Import history from Toggl CSV.

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

## Open questions

- **Q1 (M5):** An entry with several tags: does its full time count toward each tag? Proposal: yes, with a note that tag totals can exceed the period total. Splitting the time between tags would give misleading numbers.

## CloudKit schema change log

Each model change must be deployed via CloudKit Console → Deploy Schema Changes before an archived build uses it.

| Date | Change | Deployed to production |
|------|--------|------------------------|
| — | Initial schema (M1) | ⬜ |
