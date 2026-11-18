# AGENTS.md

Flutter/Dart mobile app (Android is the real target) for personal schedule management. UI text and code comments are in Vietnamese; keep that style for user-facing strings and comments. Single package, no monorepo, no codegen, no CI config.

## Commands

- Verify: `flutter analyze` then `flutter test` (both currently clean; 79 tests in `test/`).
- One test file: `flutter test test/conflict_service_test.dart`
- Run: `flutter run -d <device-id>` (see `flutter devices`). After editing `pubspec.yaml` or adding packages, stop and rerun; hot reload is not enough.
- `flutter run -d chrome` only shows UI; `sqflite` does not work on web.
- Build APK: `flutter build apk --release`. NDK must be exactly `28.2.13676358`.
- `analysis_options.yaml` excludes `android/ ios/ web/ windows/ macos/ linux/ build/` from analysis.

## README is stale

`README.md` feature table and folder tree describe the original v1 (only `home_screen`, `add_event_screen`, `event.dart` with a single `date`). Trust the code and `git log`. Excel import, reminders, statistics, and the timetable views are already implemented.

## Architecture

- Entry: `lib/main.dart` -> `ChangeNotifierProvider(AppData()..load())` -> `screens/main_shell.dart`. The shell is a 4-tab `IndexedStack` (Lịch, Sổ cái, Thống kê, Cài đặt). Tabs are built lazily on first open.
- State: one `ChangeNotifier`, `providers/app_data.dart`, which owns the in-memory events, labels, conflict ids and reminder settings. Mutations go through `AppData` (DB write -> refetch -> `notifyListeners()` -> `_syncReminders()`), never straight to `DatabaseHelper` from screens.
- `AppData.events` and `labels` return cached `UnmodifiableListView`s. They are replaced only when data changes, because widgets rely on identity to skip rebuilds. A timer calls `notifyListeners()` every minute, so a getter that builds a new object each call causes rebuilds on every tick.
- Pure logic is in `lib/services/` (`bulk_reschedule_service`, `conflict_service`, `free_slot_service`, `import_parser`, `reminder_planner`, `stats_service`, `timetable_layout`, `timetable_pages`). These have the unit tests. Put new logic here, free of Flutter imports, so it stays testable.
- `reminder_service.dart` is the only file that touches `flutter_local_notifications` and `timezone`. `reminder_planner.dart` decides what to schedule.
- `widgets/calendar_timetable.dart` (~41 KB) and `widgets/week_timetable.dart` (~27 KB) are the hot path: drag/resize on the Day/Week grid and the move-event screen. During a drag, only the overlay is repainted through a `ValueNotifier<int> _frame` and `ValueListenableBuilder`. Do not replace that with a `setState()` per pointer move. Conflict results are cached in `_conflictsFor`.

## Database (`lib/database/database_helper.dart`)

- SQLite file `lich.db`, current `_dbVersion = 3`. Tables: `events`, `labels`, `settings`.
- Schema change: bump `_dbVersion`, add an `if (oldVersion < N)` step in `onUpgrade`, and update `onCreate`. Existing devices keep their data.
- Times are `start_time` / `end_time`, stored as `millisecondsSinceEpoch` ints. The old single `date` column is gone (migrated in `_migrateV1ToV2`).
- `PRAGMA foreign_keys = ON`. Deleting a label sets `events.label_id` to NULL in a transaction.
- `deleteOlderThanOneYear()` runs on every app start, deleting events whose `end_time` is more than 365 days old. Be careful when testing with old dates; they will be removed.

## Startup order

`main()` must not `await` the notification init. `ReminderService.init()` runs inside `AppData.load()` after `runApp()`, so the first frame is not blocked. Keep it there.

## OpenCode / tooling in this repo

- `opencode.json` is project-local and untracked. It sets the model to `anthropic/claude-opus-5-5` through the Stali gateway (`baseURL` ends in `/v1`; OpenCode appends `/messages`). The API key lives in OpenCode's `/connect` store. Never write it into files or commit it.
- MCP servers use absolute Windows paths and call `node.exe` or `uvx.exe` directly (no `npx`, since spawning `npx` without a shell fails on Windows). Keep that when editing them.
- `graphify-out/` is gitignored and generated. The graph was built at commit `59f8904`, before the current uncommitted edits, so rebuild before trusting it for recent code. `.serena/` is Serena's per-project cache and is untracked.

## Git

- Remote: `haidu349/app_quan_ly_lich_mobile`, branch `main`.
- Commit messages are short Vietnamese descriptions of one feature.
- Don't commit keys, keystores, or `auth.json`. Put APKs in GitHub Releases, not in the repo.
