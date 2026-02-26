# SheetShow Development Guidelines

## Project Overview
SheetShow is a **fully offline** Flutter Windows desktop app for managing and annotating sheet music PDFs.
There is no server, no auth, no cloud sync. All data is local.

## Stack
- **Client**: Dart 3.5 / Flutter 3.24 — Windows desktop only
- **Database**: Drift 2.x (SQLite, FTS5) at `<workspace>/.sheetshow/data.db`
- **PDF rendering**: `pdfrx` 1.x (PDFium-based)
- **State management**: Riverpod 2.x
- **Navigation**: GoRouter 13.x
- **File picking**: `file_picker` 8.x
- **Window management**: `window_manager` 0.4.x
- **No server component** (was removed; do not re-add)

## Project Layout
```
client/              Flutter app
  lib/
    core/
      database/      Drift schema + migrations (app_database.dart)
      services/      WorkspaceService, FolderWatchService, etc.
      theme/
      constants/
    features/
      library/       Score library — scores, folders, import, search
        models/
        repositories/
        services/    ImportService, SearchService, ThumbnailService
        ui/
      reader/        PDF viewer with pen annotation
      setlists/      Set list builder + performance mode
      workspace/     Workspace setup screen (first-launch)
  test/
    unit/            Pure-logic tests (mockito, in-memory Drift)
    integration/     Widget / service integration tests
.github/
  workflows/
    client-ci.yml   CI: analyze → test (≥60% coverage, excluding generated files) → build
  agents/
    copilot-instructions.md   ← this file
```

## Commands
```bash
# Install dependencies
flutter pub get                                 (from client/)

# Generate Drift code after schema changes
dart run build_runner build --delete-conflicting-outputs

# Format
dart format lib/ test/

# Analyze (zero warnings enforced in CI)
flutter analyze --fatal-infos --fatal-warnings

# Run unit tests with coverage
flutter test --coverage test/unit/

# Build Windows release
flutter build windows --release
```

## Code Style
- Dart: follow `flutter_lints`; no unused imports; prefer `const` constructors
- Repositories return domain models (never raw Drift row types to UI)
- Riverpod providers are `Provider<T>` or `FutureProvider<T>`; pass `ref` down via constructor injection where possible
- All DB writes are in repositories; services orchestrate repositories
- Use `dart:io` for file I/O; avoid `dart:html`

## Database / Schema Rules
- Schema version is in `AppDatabase.schemaVersion`; bump on every structural change
- Every schema change needs a corresponding migration in the `MigrationStrategy.onUpgrade` chain
- Run `build_runner` after any change to Drift table classes
- Current schema version: **5** (workspace-aware)
- Tables: `scores`, `folders`, `score_folder_memberships`, `score_tags`, `folder_tags`, `annotation_layers`, `set_lists`, `set_list_entries`, `score_search` (FTS5)

## Testing Requirements
- **All new services and repositories must have unit tests** in `test/unit/`
- Use `mockito` for mocking; `@GenerateMocks([...])` + `build_runner` for generated mocks
- Use an **in-memory Drift database** (`NativeDatabase.memory()`) for repository tests — do not mock the DB
- Integration tests go in `test/integration/` and use `WidgetTester` or real (temp-dir) databases
- CI enforces **≥ 60% line coverage** (excluding Drift-generated `*.g.dart` files) — new code must not drop coverage below this threshold
- For file-system-dependent services (e.g. `FolderWatchService`, `WorkspaceService`):
  - Use `Directory.systemTemp.createTempSync()` in tests; clean up in `tearDown`
  - Inject `Directory`/`File` paths rather than hardcoding so tests can override them

## Workspace Architecture (as of v2)
- User picks a **single root workspace folder**; all PDFs live under it
- App metadata stored at `<workspace>/.sheetshow/data.db`
- Workspace path persisted in `AppDocumentsDir/sheetshow_config.json`
- `FolderWatchService` watches the workspace recursively for file/folder changes
- Score files are **not copied** — `local_file_path` points to the original file inside the workspace
- Renaming a score in-app also renames the PDF on disk (and vice versa via the watcher)
- Fresh install: import the same workspace folder → all data (tags, set lists, annotations) restored

## Git / PR Rules
- Pre-commit hook (`.githooks/pre-commit`): `dart format` check + `flutter analyze` — must pass
- Commits follow Conventional Commits: `feat(scope):`, `fix(scope):`, `refactor(scope):`, etc.
- Every commit that adds a feature should include or update tests
- **Never push directly to `main`** — always work on a feature branch and open a PR; pushing to `main` requires explicit approval from the repo owner

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

