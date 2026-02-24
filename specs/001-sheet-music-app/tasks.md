# Tasks: SheetShow — Windows Sheet Music Manager

**Input**: Design documents from `/specs/001-sheet-music-app/`  
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/rest-api.md ✅, contracts/sync-protocol.md ✅, quickstart.md ✅

**Stack**: Flutter 3.24 / Dart 3.5 (client) · .NET 8 ASP.NET Core (server) · Drift/SQLite + FTS5 (local DB) · PostgreSQL 16 + EF Core 8 (cloud DB) · Azure Blob Storage (file storage)

**Tests**: Not generated as separate tasks. TDD is mandated by plan.md (red → green → refactor); write failing tests before each implementation task as part of normal PR workflow. Test files live under `client/test/unit/`, `client/test/integration/`, and `server/tests/`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story increment.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no blocking dependencies)
- **[Story]**: User story this task belongs to (US1–US6)
- All paths relative to repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository scaffold, tooling, CI pipelines, and local dev environment. No code logic yet.

- [ ] T001 Create monorepo directory structure: `client/`, `server/`, `specs/`, `.github/workflows/` per plan.md project layout
- [ ] T002 Initialize Flutter 3.24 project in `client/` — run `flutter create --platforms=windows .` then update `client/pubspec.yaml` with all dependencies: `pdfrx: ^2.0.0`, `drift: ^2.0.0`, `drift_flutter: ^0.1.0`, `flutter_secure_storage: ^9.0.0`, `riverpod: ^2.0.0`, `flutter_riverpod: ^2.0.0`, `go_router: ^13.0.0`, `connectivity_plus: ^6.0.0`, `file_picker: ^8.0.0`, `path_provider: ^2.0.0`, `http: ^1.0.0`, `uuid: ^4.0.0`, `build_runner: ^2.0.0`, `drift_dev: ^2.0.0`
- [ ] T003 [P] Initialize .NET 8 solution in `server/` — run `dotnet new sln -n SheetShow` then create projects: `dotnet new classlib -n SheetShow.Core`, `dotnet new classlib -n SheetShow.Infrastructure`, `dotnet new webapi -n SheetShow.Api`, `dotnet new xunit -n SheetShow.UnitTests`, `dotnet new xunit -n SheetShow.IntegrationTests`; add NuGet packages: `Microsoft.EntityFrameworkCore`, `Npgsql.EntityFrameworkCore.PostgreSQL`, `Microsoft.AspNetCore.Identity.EntityFrameworkCore`, `Azure.Storage.Blobs`, `Serilog.AspNetCore`, `Swashbuckle.AspNetCore`, `Moq`, `WebApplicationFactory`, `coverlet.collector`
- [ ] T004 [P] Create `server/docker-compose.yml` — PostgreSQL 16 on `localhost:5432` (user: `sheetshow`, password: `sheetshow_dev`, db: `sheetshow`) + Azurite on `localhost:10000`; matching `server/src/SheetShow.Api/appsettings.Development.json` with connection strings
- [ ] T005 [P] Configure Flutter linting in `client/analysis_options.yaml` — enable `flutter_lints`, `dart_code_metrics` with cyclomatic complexity cap of 10, zero-warnings policy (`errors: unawaited_futures: error`)
- [ ] T006 [P] Configure .NET formatting in `server/.editorconfig` and add `StyleCop.Analyzers` NuGet to `SheetShow.Api` and `SheetShow.Core`; add `server/.globalconfig` to enforce `dotnet format --verify-no-changes`
- [ ] T007 [P] Create `.github/workflows/client-ci.yml` — steps: `flutter pub get` → `flutter analyze` → `dart format --set-exit-if-changed` → `flutter test --coverage` → lcov gate ≥ 80% → `flutter build windows`
- [ ] T008 [P] Create `.github/workflows/server-ci.yml` — steps: `dotnet format --verify-no-changes` → `dotnet build` → `dotnet test --collect:"XPlat Code Coverage"` → coverage gate ≥ 80% → `docker build`
- [ ] T009 Create Azure Bicep infrastructure templates in `server/infra/main.bicep` — provisions: Azure Container Registry, Container Apps environment, PostgreSQL Flexible Server (B2ms), Blob Storage account (`scores` container, hot tier), Key Vault; parameterized for `dev` / `prod` environments

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core cross-story infrastructure that ALL user stories depend on. No user story implementation may begin until this phase is complete.

**⚠️ CRITICAL**: Phases 3–8 are blocked by this phase.

- [ ] T010 Create Dart shared constants in `client/lib/core/constants/app_constants.dart` — define: `kSyncPollIntervalSec = 30`, `kSyncBackoffCapSec = 300`, `kMaxFolderDepth = 10`, `kAnnotationSizeThresholdBytes = 65536`, `kTombstoneDays = 90`, `kAccessTokenExpiryMin = 15`, `kRefreshTokenExpiryDays = 90`, `kSearchDebounceMs = 200`, `kLargeFileThresholdBytes = 10485760`
- [ ] T011 Create `client/lib/core/constants/api_config.example.dart` — export `const String kApiBaseUrl = 'https://localhost:7001/api/v1';`; add `client/lib/core/constants/api_config.dart` to `.gitignore`
- [ ] T012 [P] Create Flutter design system tokens in `client/lib/core/theme/` — `app_colors.dart` (primary, surface, error, on-* semantic colours), `app_spacing.dart` (4-pt grid: xs=4, sm=8, md=16, lg=24, xl=32), `app_typography.dart` (text styles mapped to Material 3 type scale), `app_theme.dart` (ThemeData composed from tokens; no inline style values permitted elsewhere)
- [ ] T013 [P] Create `ClockService` abstraction in `client/lib/core/services/clock_service.dart` — abstract class `ClockService { DateTime now(); }` + `SystemClockService` implementation; register via Riverpod `Provider`; ensures deterministic tests (no `DateTime.now()` in production logic)
- [ ] T014 [P] Define shared Dart enums in `client/lib/core/models/enums.dart` — `SyncState { synced, pendingUpload, pendingUpdate, pendingDelete, conflict }`, `AnnotationTool { pen, highlighter, eraser }`, `SyncOperationType { create, update, delete }`, `SyncEntityType { score, folder, setList, setListEntry, annotationLayer }`
- [ ] T015 Define complete Drift database schema in `client/lib/core/database/app_database.dart` — declare all 8 tables as Drift `Table` subclasses: `Scores` (all columns from data-model.md including `syncState`, `cloudId`, `serverVersion`, `isDeleted`), `Folders` (with `parentFolderId` self-FK), `ScoreTags` (composite PK), `SetLists`, `SetListEntries` (composite unique index `setListId + orderIndex`), `AnnotationLayers` (composite unique index `scoreId + pageNumber`), `SyncQueue`, `SyncMeta`; enable WAL mode via `DatabaseConnection` pragma (`PRAGMA journal_mode=WAL`) for SC-008 crash safety
- [ ] T016 Declare FTS5 virtual table `score_search` in `client/lib/core/database/app_database.dart` — columns `title` and `tags_flat`; write `rebuildScoreSearch(String id, String title, String tagsFlat)` helper that upserts into FTS5 on every score create/update
- [ ] T017 Run Drift code generation to produce `client/lib/core/database/app_database.g.dart` — command: `dart run build_runner build --delete-conflicting-outputs`; commit generated file
- [ ] T018 [P] Implement `ErrorDisplayService` in `client/lib/core/services/error_display_service.dart` — maps `Exception` subtypes (network, validation, storage-full, quota-exceeded, auth) to user-readable `String` messages with corrective action hints; no stack traces in UI; expose via Riverpod `Provider`
- [ ] T019 [P] Implement `ApiClient` in `client/lib/core/services/api_client.dart` — HTTP wrapper (using `http` package) with: Bearer token injection from `TokenStorageService`, automatic 401 → refresh → retry once, request/response JSON serialisation, error → `AppException` mapping, timeout constants from `app_constants.dart`
- [ ] T020 [P] Configure app-level Riverpod `ProviderScope` and `GoRouter` routing skeleton in `client/lib/main.dart` — register `ClockService`, `ErrorDisplayService`, `ApiClient` providers; define named route stubs for all screens (library, reader, set-lists, auth, sync); `WidgetsFlutterBinding.ensureInitialized()` before `runApp`
- [ ] T021 Scaffold .NET Clean Architecture project references in `server/SheetShow.sln` — `SheetShow.Infrastructure` references `SheetShow.Core`; `SheetShow.Api` references `SheetShow.Infrastructure`; test projects reference their target + `Moq`, `FluentAssertions`
- [ ] T022 [P] Define C# server-side constants in `server/src/SheetShow.Core/Constants/` — `QuotaLimits.cs` (`DefaultQuotaBytes = 10_737_418_240L`), `TombstoneDays.cs` (`Days = 90`), `TokenExpiry.cs` (`AccessTokenMinutes = 15`, `RefreshTokenDays = 90`), `SyncConstants.cs` (`MaxBatchSize = 100`, `MaxRetries = 10`, `AnnotationInlineSizeLimit = 65_536`)
- [ ] T023 [P] Define core server interfaces in `server/src/SheetShow.Core/Interfaces/` — `IFileStorageService.cs` (`GenerateUploadUrlAsync`, `GenerateDownloadUrlAsync`, `DeleteAsync`), `IEmailService.cs` (`SendPasswordResetAsync`), `ISecretsManager.cs` (`GetSecretAsync`), `IScoreRepository.cs` (`GetAllAsync`, `GetByIdAsync`, `CreateAsync`, `UpdateAsync`, `SoftDeleteAsync`)
- [ ] T024 [P] Create `GlobalExceptionMiddleware` in `server/src/SheetShow.Api/Middleware/GlobalExceptionMiddleware.cs` — catches all unhandled exceptions; maps to RFC 7807 `ProblemDetails` shape (type, title, status, detail, traceId) matching contracts/rest-api.md error schema
- [ ] T025 [P] Create `RequestLoggingMiddleware` in `server/src/SheetShow.Api/Middleware/RequestLoggingMiddleware.cs` — Serilog-based structured logging of method, path, status code, duration; masks Authorization header
- [ ] T026 Configure `Program.cs` in `server/src/SheetShow.Api/Program.cs` — DI composition root: register middleware pipeline (logging → exception handling → auth → rate limiting → CORS), Swagger/OpenAPI, rate limiting policies (auth: 10/min per IP, uploads: 30/min per user, other: 300/min per user), Serilog, `appsettings.{env}.json` configuration
- [ ] T027 Create `ApplicationDbContext` in `server/src/SheetShow.Infrastructure/Persistence/ApplicationDbContext.cs` — EF Core 8 DbContext extending `IdentityDbContext<AppUser>`; declare `DbSet<>` for all entities; global query filters for `IsDeleted = false` (soft-delete); configure composite unique indexes: `(ScoreId, PageNumber)` on `AnnotationLayers`, `(SetListId, OrderIndex)` on `SetListEntries`, `(UserId, Tag)` on `ScoreTags`
- [ ] T028 Generate initial EF Core migration in `server/src/SheetShow.Infrastructure` — command: `dotnet ef migrations add InitialCreate --project src/SheetShow.Infrastructure --startup-project src/SheetShow.Api`; migration creates all tables, indexes, ASP.NET Identity tables, `sync_log` audit table, and `Version` columns for optimistic concurrency

**Checkpoint**: Foundation complete — all user story phases may now begin

---

## Phase 3: User Story 1 — Import and View Sheet Music (Priority: P1) 🎯 MVP

**Goal**: Musician imports PDF files, browses the library with thumbnails, opens any score full-screen, and navigates multi-page documents smoothly.

**Independent Test**: Import a PDF → confirm it appears in library grid with thumbnail → open it → scroll through all pages → confirm no rendering lag. No other features required.

### Server — Score CRUD and File Storage

- [ ] T029 [P] [US1] Create `Score` server entity in `server/src/SheetShow.Core/Entities/Score.cs` — properties: `Id` (Guid), `UserId`, `Title`, `Filename`, `BlobPath`, `TotalPages`, `FolderId` (nullable), `Version` (int, default 1), `IsDeleted`, `DeletedAt`, `CreatedAt`, `UpdatedAt`; navigation: `ICollection<ScoreTag> Tags`
- [ ] T030 [P] [US1] Implement `AzureBlobStorageService` in `server/src/SheetShow.Infrastructure/Azure/AzureBlobStorageService.cs` — implement `IFileStorageService`: `GenerateUploadUrlAsync` (15-min SAS write token), `GenerateDownloadUrlAsync` (15-min SAS read token), `DeleteAsync` (soft-flag only; hard delete managed by lifecycle policy)
- [ ] T031 [US1] Implement `ScoreRepository` in `server/src/SheetShow.Infrastructure/Persistence/Repositories/ScoreRepository.cs` — implement `IScoreRepository`: `GetAllAsync` (filter by `UserId`, optional `folderId`, optional `since` timestamp), `GetByIdAsync` (with ownership check), `CreateAsync`, `UpdateAsync` (increment `Version`, check optimistic concurrency), `SoftDeleteAsync` (set `IsDeleted=true`, `DeletedAt=now`)
- [ ] T032 [US1] Create `ScoresController` in `server/src/SheetShow.Api/Controllers/ScoresController.cs` — endpoints per rest-api.md: `GET /scores` (with `?folderId`, `?since`), `POST /scores` (create metadata, idempotent on `clientId`), `GET /scores/{id}` (with `blobDownloadUrl`), `PUT /scores/{id}` (update title/folder/tags with `clientVersion` optimistic concurrency, returns 409 on conflict), `DELETE /scores/{id}` (soft delete), `POST /scores/{id}/upload-url`, `GET /scores/{id}/download-url`
- [ ] T033 [US1] Register `ScoreRepository`, `AzureBlobStorageService` in `Program.cs` DI; add `[Authorize]` to `ScoresController`; apply rate limiting policies

### Client — Import, Library, and Reader

- [ ] T034 [P] [US1] Create `ScoreModel` in `client/lib/features/library/models/score_model.dart` — immutable Dart class mapping to `scores` Drift table: `id`, `title`, `filename`, `localFilePath`, `totalPages`, `thumbnailPath`, `folderId`, `importedAt`, `updatedAt`, `syncState`, `cloudId`, `serverVersion`, `isDeleted`; `fromJson` / `toJson` for API sync payloads; `copyWith`
- [ ] T035 [P] [US1] Implement `ScoreRepository` (client) in `client/lib/features/library/repositories/score_repository.dart` — Drift DAO: `watchAll()` (reactive stream, excludes `isDeleted`), `getById(String id)`, `insert(ScoreModel)`, `update(ScoreModel)`, `softDelete(String id)`, `updateSyncState(String id, SyncState)`, `updateCloudId(String id, String cloudId, int serverVersion)`; register as Riverpod `Provider`
- [ ] T036 [US1] Implement `ImportService` in `client/lib/features/library/services/import_service.dart` — `importPdf()`: open file picker (PDF filter), validate file exists and is non-empty, copy to app documents directory (`path_provider`), extract page count via `pdfrx`, generate UUID, insert via `ScoreRepository` with `syncState = pendingUpload`, enqueue `create` operation in `sync_queue`, trigger `ThumbnailService`; throw typed exceptions for corrupt/unsupported files caught by `ErrorDisplayService`
- [ ] T037 [US1] Implement `ThumbnailService` in `client/lib/features/library/services/thumbnail_service.dart` — `generateThumbnail(String localFilePath, String scoreId)`: open PDF via `pdfrx`, render page 1 at 200×280 px, save as PNG to app cache directory, update `scores.thumbnailPath` via `ScoreRepository`; runs on an isolate to avoid blocking UI
- [ ] T038 [P] [US1] Create `ScoreCard` widget in `client/lib/features/library/ui/score_card.dart` — displays thumbnail (`Image.file`, fallback to music-note placeholder), title text, `SyncState` badge icon (pending/conflict/offline); uses design system tokens; `onTap` callback; `Semantics` label for accessibility
- [ ] T039 [P] [US1] Create `LibraryScreen` in `client/lib/features/library/ui/library_screen.dart` — Riverpod `ConsumerWidget` watching `ScoreRepository.watchAll()` stream; `GridView.builder` of `ScoreCard` widgets; FAB for import via `ImportService`; loading skeleton while stream is pending; empty-state illustration; navigate to `ReaderScreen` on tap
- [ ] T040 [US1] Create `PdfPageView` widget in `client/lib/features/reader/ui/pdf_page_view.dart` — wraps `pdfrx` `PdfViewer` widget with: lazy page rendering, smooth scroll/swipe gestures, page number indicator overlay, fit-width default layout; handles mixed portrait/landscape page sizes per-page using `pdfrx` page dimension API
- [ ] T041 [US1] Create `ReaderScreen` in `client/lib/features/reader/ui/reader_screen.dart` — full-screen scaffold with `PdfPageView`; app bar (score title, back button, annotation toggle placeholder); `CircularProgressIndicator` while PDF loads; passes `localFilePath` from `ScoreModel` to `pdfrx`
- [ ] T042 [US1] Wire `LibraryScreen` → `ReaderScreen` navigation in `client/lib/main.dart` GoRouter routes — `/library` → `/reader/:scoreId`; pass `ScoreModel` via `extra`; ensure `WillPopScope` restores library scroll position

**Checkpoint**: US1 complete — import a PDF, see it in the library grid with thumbnail, open it, scroll all pages

---

## Phase 4: User Story 2 — Organize with Folders and Tags (Priority: P2)

**Goal**: Musician creates folders, moves scores into them by drag-and-drop, adds free-text tags, and searches the library by title or tag in real time.

**Independent Test**: Create a folder → drag a score into it → add tags to a score → search by tag name → confirm only tagged scores appear. No set lists or sync required.

### Server — Folders Endpoint

- [ ] T043 [P] [US2] Create `Folder` server entity in `server/src/SheetShow.Core/Entities/Folder.cs` — `Id`, `UserId`, `Name`, `ParentFolderId` (nullable, self-FK), `Version`, `IsDeleted`, `DeletedAt`, `CreatedAt`, `UpdatedAt`
- [ ] T044 [US2] Create `FoldersController` in `server/src/SheetShow.Api/Controllers/FoldersController.cs` — `GET /folders` (all non-deleted for user), `POST /folders` (idempotent on `clientId`), `PUT /folders/{id}` (rename or reparent with `clientVersion` concurrency), `DELETE /folders/{id}` (soft-delete; scores inside move to root — `folderId = null`)

### Client — Folder Model, Repository, and Tree UI

- [ ] T045 [P] [US2] Create `FolderModel` in `client/lib/features/library/models/folder_model.dart` — maps to `folders` Drift table; `id`, `name`, `parentFolderId`, `syncState`, `cloudId`, `isDeleted`; `fromJson` / `toJson`; `copyWith`
- [ ] T046 [P] [US2] Implement `FolderRepository` in `client/lib/features/library/repositories/folder_repository.dart` — Drift DAO: `watchAll()` (reactive stream), `create(FolderModel)`, `rename(String id, String name)`, `reparent(String id, String? parentId)`, `softDelete(String id)`, `getDepth(String id)` (walks parent chain, enforces `kMaxFolderDepth = 10`), `updateSyncState`; throws `FolderDepthException` if nesting exceeds limit

### Client — Tag Management with FTS5

- [ ] T047 [US2] Implement tag management in `client/lib/features/library/repositories/score_repository.dart` — add `setTags(String scoreId, List<String> tags)`: normalise to lowercase, delete existing `score_tags` rows for score, bulk insert new rows, call `rebuildScoreSearch` to update FTS5 `tags_flat`; mark score `syncState = pendingUpdate`
- [ ] T048 [P] [US2] Implement `SearchService` in `client/lib/features/library/services/search_service.dart` — `searchStream(String query)`: debounce 200ms, query FTS5 `score_search` table for `title MATCH ? OR tags_flat MATCH ?`, return `Stream<List<ScoreModel>>`; empty query returns all scores; results exclude soft-deleted

### Client — Folder and Search UI

- [ ] T049 [P] [US2] Create `FolderTree` widget in `client/lib/features/library/ui/folder_tree.dart` — recursive `ListView` rendering folder hierarchy from `FolderRepository.watchAll()` stream; collapsible nodes; `DragTarget<ScoreModel>` on each folder node that calls `ScoreRepository.update` to set `folderId`; create/rename/delete context menu per node; `Semantics` labels
- [ ] T050 [P] [US2] Create `SearchBar` widget in `client/lib/features/library/ui/search_bar.dart` — `TextField` feeding `SearchService.searchStream`; real-time results list overlay while query non-empty; result tap navigates to `ReaderScreen`
- [ ] T051 [US2] Integrate `FolderTree` and `SearchBar` into `LibraryScreen` in `client/lib/features/library/ui/library_screen.dart` — `NavigationRail` or side drawer containing `FolderTree`; `SearchBar` in app bar; library grid filters by selected folder ID; switching folders updates `GridView` contents via reactive stream
- [ ] T052 [US2] Implement drag-and-drop score → folder in `client/lib/features/library/ui/library_screen.dart` — wrap `ScoreCard` in `Draggable<ScoreModel>`; `DragTarget` on `FolderTree` nodes calls `ScoreRepository.update(score.copyWith(folderId: targetFolderId))`
- [ ] T053 [P] [US2] Create tag editor in `client/lib/features/library/ui/score_detail_sheet.dart` — bottom sheet with `Wrap` of tag chips, `TextField` to add new tag, tap-to-remove; save calls `ScoreRepository.setTags`; display tags on `ScoreCard` as `Chip` widgets
- [ ] T054 [US2] Display folder breadcrumb and tag chips in `LibraryScreen` header and `ScoreCard` in `client/lib/features/library/ui/` — breadcrumb row showing current folder path; score cards show tag chips below title

**Checkpoint**: US2 complete — folders, drag-drop scores, tags, FTS5 search all independently testable

---

## Phase 5: User Story 3 — Create and Use Set Lists (Priority: P3)

**Goal**: Musician builds a named set list by dragging or searching scores into it, reorders entries by drag-and-drop, and steps through scores sequentially in performance mode.

**Independent Test**: Create set list → add scores via search → reorder by drag → open performance mode → advance to next piece → confirm correct score opens full-screen. No sync required.

### Server — Set Lists Endpoint

- [ ] T055 [P] [US3] Create `SetList` and `SetListEntry` server entities in `server/src/SheetShow.Core/Entities/SetList.cs` and `SetListEntry.cs` — `SetList`: `Id`, `UserId`, `Name`, `Version`, `IsDeleted`, `DeletedAt`, timestamps; `SetListEntry`: `Id`, `SetListId`, `ScoreId`, `OrderIndex`
- [ ] T056 [US3] Create `SetListsController` in `server/src/SheetShow.Api/Controllers/SetListsController.cs` — `GET /setlists` (with entries), `POST /setlists` (entries array, idempotent on `clientId`), `PUT /setlists/{id}` (full entries replacement with `clientVersion`), `DELETE /setlists/{id}` (soft-delete; referenced scores unaffected)

### Client — Set List Models and Repository

- [ ] T057 [P] [US3] Create `SetListModel` in `client/lib/features/setlists/models/set_list_model.dart` — `id`, `name`, `entries` (`List<SetListEntryModel>`), `syncState`, `cloudId`, timestamps; `fromJson` / `toJson`; `copyWith`
- [ ] T058 [P] [US3] Create `SetListEntryModel` in `client/lib/features/setlists/models/set_list_entry_model.dart` — `id`, `setListId`, `scoreId`, `orderIndex`, `addedAt`; `fromJson` / `toJson`
- [ ] T059 [P] [US3] Implement `SetListRepository` in `client/lib/features/setlists/repositories/set_list_repository.dart` — Drift DAO: `watchAll()`, `getWithEntries(String id)`, `create(SetListModel)`, `rename(String id, String name)`, `softDelete(String id)`, `addEntry(String setListId, String scoreId)` (appends at end, computes next `orderIndex`), `removeEntry(String entryId)`, `reorderEntries(String setListId, List<String> orderedEntryIds)` (reassigns `orderIndex` 0..n in a single transaction), `updateSyncState`; uniqueness check: rejects duplicate `(setListId, orderIndex)` within transaction

### Client — Set List Builder and Performance Mode UI

- [ ] T060 [P] [US3] Create `SetListsScreen` in `client/lib/features/setlists/ui/set_lists_screen.dart` — `ListView` of set list cards from `SetListRepository.watchAll()`; create (FAB), rename (dialog), delete (swipe-to-dismiss with confirmation); tap navigates to `SetListBuilderScreen`
- [ ] T061 [US3] Create `SetListBuilderScreen` in `client/lib/features/setlists/ui/set_list_builder.dart` — `ReorderableListView` of entries from `SetListRepository.getWithEntries()`; drag handle reorders (calls `reorderEntries` on drop); `IconButton` to remove entry; inline `SearchBar` (reuses library `SearchService`) to find scores and tap-add without leaving screen; "Start Performance" button
- [ ] T062 [P] [US3] Handle orphaned entries (score soft-deleted) in `SetListBuilderScreen` — when `ScoreRepository.getById` returns null for an entry's `scoreId`, render a warning card ("Score not found — removed from library") with option to remove the entry from the set list
- [ ] T063 [US3] Create `PerformanceModeScreen` in `client/lib/features/setlists/ui/performance_mode_screen.dart` — full-screen `ReaderScreen` stack; bottom overlay shows piece title, position (e.g. "2 / 8"), previous/next arrows; advancing to next piece calls `SetListRepository.getWithEntries` to get ordered score IDs and loads next `ScoreModel`; tapping screen hides overlay after 3-second inactivity timer
- [ ] T064 [P] [US3] Add set list navigation routes in `client/lib/main.dart` GoRouter — `/setlists`, `/setlists/:id/builder`, `/setlists/:id/performance`

**Checkpoint**: US3 complete — set lists, drag-reorder, search-add, performance mode all independently testable

---

## Phase 6: User Story 4 — Annotate Sheet Music with Surface Pen (Priority: P4)

**Goal**: Musician draws ink annotations over a score using the Surface Pen (pressure, tilt, palm rejection), with pen/highlighter/eraser tools, undo, and persistent storage across sessions.

**Independent Test**: Open a score → enable annotation mode → draw with Surface Pen → draw with highlighter → erase a stroke → close app → reopen → confirm all annotations persist exactly. Offline only, no sync required.

### Win32 Platform Channel Plugin

- [ ] T065 [US4] Create Win32 C++ platform channel plugin in `client/windows/runner/windows_ink_plugin/` — files: `CMakeLists.txt` (registers plugin with Flutter Windows runner), `windows_ink_plugin.h`, `windows_ink_plugin.cpp`; plugin hooks `WM_POINTER` messages on the Flutter window HWND via `SetWindowSubclass`; reads pen data via `GetPointerPenInfo` (pressure 0–1024, tilt X/Y, twist); sends normalised pressure and tilt to Dart via `MethodChannel("sheetshow/ink")`; emits events as a `EventChannel` stream
- [ ] T066 [US4] Implement palm rejection in `client/windows/runner/windows_ink_plugin/windows_ink_plugin.cpp` — filter `WM_POINTER` events where `GetPointerType` returns `PT_TOUCH` while a pen pointer is in proximity (detected by a non-null `GetPointerPenInfo` return); forward only `PT_PEN` pointer events to Dart

### Client — Annotation Models and Repository

- [ ] T067 [P] [US4] Create `InkStroke` model in `client/lib/features/reader/models/ink_stroke.dart` — `id` (UUID), `tool` (AnnotationTool), `color` (Color), `strokeWidth`, `opacity`, `points` (`List<NormalisedPoint>` with x, y, pressure each in [0,1]), `createdAt`; coordinates normalised to page dimensions (scale-independent); `fromJson` / `toJson`
- [ ] T068 [P] [US4] Create `AnnotationLayer` model in `client/lib/features/reader/models/annotation_layer.dart` — `id`, `scoreId`, `pageNumber` (1-based), `strokes` (`List<InkStroke>`), `syncState`, `serverVersion`, `updatedAt`; `fromJson` / `toJson`
- [ ] T069 [P] [US4] Create `ToolSettings` model in `client/lib/features/reader/models/tool_settings.dart` — `activeTool` (AnnotationTool), `color`, `strokeWidth`, `opacity`; immutable; defaults: pen black 2.5px 1.0, highlighter yellow 12px 0.4, eraser transparent 20px 1.0
- [ ] T070 [P] [US4] Implement `AnnotationRepository` in `client/lib/features/reader/repositories/annotation_repository.dart` — Drift DAO: `getLayer(String scoreId, int pageNumber)`, `saveLayer(AnnotationLayer)` (upsert on composite unique index `scoreId + pageNumber`), `clearLayer(String scoreId, int pageNumber)` (set `strokes_json = '[]'`), `watchLayer(String scoreId, int pageNumber)` (reactive stream), `updateSyncState`

### Client — Annotation Services

- [ ] T071 [US4] Implement `AnnotationService` in `client/lib/features/reader/services/annotation_service.dart` — `addStroke(InkStroke)`: appends stroke to in-memory list then persists via `AnnotationRepository.saveLayer`; `undoLastStroke()`: removes last stroke from in-memory stack, persists; `clearAll()`: clears in-memory and persists empty list; marks `syncState = pendingUpdate` on any mutation; undo stack capped at 50 strokes to prevent unbounded memory
- [ ] T072 [P] [US4] Implement `InkRendererService` in `client/lib/features/reader/services/ink_renderer_service.dart` — converts `List<InkStroke>` to `List<Flutter Path>` for `CustomPainter`: pen/highlighter strokes use `Path.lineTo` with cubic smoothing; eraser strokes apply `BlendMode.clear` clip operations; pressure modulates `strokeWidth * pressure`; tilt modulates `strokeWidth` asymmetrically

### Client — Annotation UI

- [ ] T073 [US4] Create `AnnotationOverlay` widget in `client/lib/features/reader/ui/annotation_overlay.dart` — `CustomPaint` widget overlaid on `PdfPageView` via `Stack`; `CustomPainter` calls `InkRendererService` to paint stroke list; captures pointer events from Win32 platform channel (`EventChannel` stream from `windows_ink_plugin`) for pressure/tilt; falls back to `Listener` widget `PointerEvent` on non-pen input; stroke drawn in real time (updates in-memory list every `PointerMoveEvent`, commits to `AnnotationService` on `PointerUpEvent`); target latency ≤ 50ms (SC-006)
- [ ] T074 [P] [US4] Create `AnnotationToolbar` widget in `client/lib/features/reader/ui/annotation_toolbar.dart` — row of tool toggle buttons (pen, highlighter, eraser icons) with active state; colour picker `showDialog`; stroke width `Slider`; undo `IconButton` (calls `AnnotationService.undoLastStroke`); "Clear All" `IconButton` with `AlertDialog` confirmation; uses design system tokens
- [ ] T075 [US4] Integrate `AnnotationOverlay` and `AnnotationToolbar` into `ReaderScreen` in `client/lib/features/reader/ui/reader_screen.dart` — `Stack`: `PdfPageView` → `AnnotationOverlay` (conditional on annotation mode) → `AnnotationToolbar` (bottom, conditional); `FloatingActionButton` to toggle annotation mode on/off; load existing `AnnotationLayer` from `AnnotationRepository.watchLayer` on screen entry

**Checkpoint**: US4 complete — pen draw/highlight/erase with pressure, undo, clear all, persist across sessions

---

## Phase 7: User Story 5 — Offline-First with Cloud Sync (Priority: P5)

**Goal**: All features work fully offline. When connected and logged in, all changes sync automatically to the cloud within 30 seconds. Conflicts are resolved in a side-by-side merge editor.

**Independent Test**: Use app offline (import, annotate, set list edit) → reconnect → verify changes appear in cloud backend within 30s → force a conflict → confirm merge editor appears.

### Client — Sync Models

- [ ] T076 [P] [US5] Create `SyncQueueEntry` model in `client/lib/features/sync/models/sync_queue_entry.dart` — maps to `sync_queue` Drift table; `id`, `entityType`, `entityId`, `operation`, `payloadJson`, `status`, `createdAt`, `attemptCount`, `lastAttemptAt`, `errorMessage`
- [ ] T077 [P] [US5] Create `ConflictInfo` model in `client/lib/features/sync/models/conflict_info.dart` — `entityType`, `entityId`, `conflictType` (metadata_modified, annotation_modified, delete_vs_update, set_list_modified), `localPayload`, `serverPayload`, `serverVersion`
- [ ] T078 [P] [US5] Create `SyncStatus` model in `client/lib/features/sync/models/sync_status.dart` — `state` enum (idle, syncing, conflict, offline, error), `lastSyncAt` (DateTime?), `pendingConflictCount`, `errorMessage`; expose as Riverpod `StateNotifier`

### Client — Sync Services

- [ ] T079 [P] [US5] Implement `SyncQueueProcessor` in `client/lib/features/sync/services/sync_queue_processor.dart` — reads `pending` entries from `sync_queue` Drift table ordered by `created_at`; deduplicates: collapse multiple `update` ops for same `entity_id` (keep latest payload); `delete` supersedes any pending `create` or `update` for same entity; returns ordered `List<SyncQueueEntry>` ready for push batch; max batch size = `SyncConstants.MaxBatchSize`
- [ ] T080 [US5] Implement `ConflictDetector` in `client/lib/features/sync/services/conflict_detector.dart` — processes push response results array; for each `status: conflict` result, creates `ConflictInfo` with `conflictType` derived from entity type and server payload; for `status: not_found` prompts "Keep local?" decision; queues `ConflictInfo` list for `MergeEditorScreen`
- [ ] T081 [US5] Implement `SyncService` in `client/lib/features/sync/services/sync_service.dart` — **pull phase**: `POST /api/v1/sync/pull` with `deviceId` and `since` timestamp from `sync_meta`; apply per-entity merge logic (table from sync-protocol.md: create/update/delete × local sync state); paginate if `hasMore: true`; update `sync_meta.last_sync_at`; **push phase**: call `SyncQueueProcessor`, `POST /api/v1/sync/push` with deduplicated batch, process results via `ConflictDetector`; **error handling**: exponential backoff (5s → 10s → 20s → 40s → cap 5min), max 10 retries then mark `failed`; **401 handling**: attempt token refresh, pause and emit `error` state if refresh fails
- [ ] T082 [P] [US5] Implement connectivity monitor and sync triggers in `client/lib/features/sync/services/sync_service.dart` — use `connectivity_plus` to listen for network state changes; on reconnect trigger sync after 2s debounce; on app foreground trigger immediate sync; periodic `Timer.periodic` every 30s while online; expose `SyncStatus` stream to UI via `StateNotifierProvider`
- [ ] T083 [P] [US5] Implement stable device ID generation in `client/lib/features/sync/services/sync_service.dart` — on first launch, generate UUID v4 and persist to `sync_meta` table under key `device_id`; read on every subsequent sync call
- [ ] T084 [US5] Implement PDF blob upload/download in `client/lib/features/sync/services/sync_service.dart` — **upload**: when `sync_queue` has `create` for a score, first `POST /scores/{id}/upload-url`, then stream local PDF to pre-signed Azure URL via `http`; mark `synced` on success; **download**: when pull receives score `create`/`update` with new `version`, `GET /scores/{id}/download-url`, stream to local file; files >10MB download in background with `SyncStatusIndicator` progress

### Server — Sync Endpoints

- [ ] T085 [P] [US5] Create `SyncController` in `server/src/SheetShow.Api/Controllers/SyncController.cs` — `POST /api/v1/sync/pull` (authenticated; parse `deviceId`, `since`, `entityTypes`; returns paginated `changes` array up to `MaxBatchSize`; skip changes authored by requesting `deviceId`), `POST /api/v1/sync/push` (authenticated; process operations array, detect version conflicts, write accepted ops to `sync_log`, return results per `operationId`)
- [ ] T086 [US5] Implement `SyncService` (server) in `server/src/SheetShow.Core/Services/SyncService.cs` — pull: query `sync_log` for user's changes since `since` timestamp (excluding `deviceId`), hydrate full entity payloads, order by `AppliedAt`, paginate with `hasMore`; push: for each operation call `ConflictDetectionService`, apply accepted operations to entities, append `sync_log` entry, update `EntityVersion`; return per-operation results
- [ ] T087 [P] [US5] Implement `ConflictDetectionService` in `server/src/SheetShow.Core/Services/ConflictDetectionService.cs` — compare incoming `clientVersion` vs current entity `Version`; if server version > client version return `conflict` result with `serverPayload` and `conflictType`; if `clientVersion == serverVersion` (post-resolution intentional overwrite) accept unconditionally
- [ ] T088 [P] [US5] Implement `StorageQuotaService` in `server/src/SheetShow.Core/Services/StorageQuotaService.cs` — `CheckQuotaAsync(Guid userId, long fileBytes)`: compares `UsedStorageBytes + fileBytes` vs `StorageQuotaBytes`; returns `quota_exceeded` if over limit; `AddUsageAsync` / `RemoveUsageAsync` called on upload/delete

### Client — Sync UI

- [ ] T089 [US5] Create `SyncStatusIndicator` widget in `client/lib/features/sync/ui/sync_status_indicator.dart` — Riverpod `ConsumerWidget` watching `SyncStatus` `StateNotifier`; renders per state: `idle` → "Synced [timestamp]", `syncing` → spinner + "Syncing…", `conflict` → warning badge + "N conflicts to resolve", `offline` → cloud-slash icon + "Offline — changes saved locally", `error` → error icon + "Sync failed — tap to retry" (tap calls `SyncService.retryNow()`); mount in app bar of `LibraryScreen`
- [ ] T090 [US5] Create `MergeEditorScreen` in `client/lib/features/sync/ui/merge_editor_screen.dart` — displays one `ConflictInfo` at a time; renders side-by-side local vs cloud comparison appropriate to `conflictType`: annotation conflicts use two `PdfPageView` + `AnnotationOverlay` instances (local strokes left, cloud strokes right); metadata conflicts show field-diff table; set list conflicts show two `ReorderableListView` instances; actions: "Take Local", "Merge Both ✓ (Recommended)", "Take Cloud"; Merge Both = stroke union (deduplicate by stroke `id`); on resolution write to local DB with `syncState = pendingUpdate`, trigger next sync

**Checkpoint**: US5 complete — fully offline, auto-sync on reconnect, conflict merge editor functional

---

## Phase 8: User Story 6 — User Account and Authentication (Priority: P6)

**Goal**: Musician registers an account, logs in to activate cloud sync, logs out (local data preserved), and benefits from persistent auth across restarts.

**Independent Test**: Register account → log in → verify sync activates and library syncs → log out → confirm all local scores still accessible. Reset password via email link.

### Server — Identity and Auth Endpoints

- [ ] T091 [P] [US6] Configure ASP.NET Core Identity in `server/src/SheetShow.Infrastructure/Identity/` — `AppUser.cs` extending `IdentityUser` (add `DisplayName`, `StorageQuotaBytes`, `UsedStorageBytes`, `CreatedAt`, `LastSyncAt`); `JwtTokenService.cs` (generate 15-min access JWT with `userId`/`email` claims, opaque 90-day refresh token stored hashed in DB, rotation on every `/auth/refresh`); `IdentityServiceExtensions.cs` registers Identity + JWT bearer auth in DI
- [ ] T092 [P] [US6] Implement `SmtpEmailService` in `server/src/SheetShow.Infrastructure/Email/SmtpEmailService.cs` — implement `IEmailService.SendPasswordResetAsync(string email, string resetLink)`; reads SMTP config from `ISecretsManager`; stubbed for local dev (logs link to console)
- [ ] T093 [US6] Create `AuthController` in `server/src/SheetShow.Api/Controllers/AuthController.cs` — all endpoints per rest-api.md: `POST /auth/register` (create user, return tokens; 409 on duplicate email), `POST /auth/login` (validate credentials, return tokens; 401 on invalid), `POST /auth/refresh` (rotate refresh token; 401 on expired), `POST /auth/logout` (revoke refresh token; authenticated), `POST /auth/forgot-password` (always 202 to prevent user enumeration; send reset email), `POST /auth/reset-password` (validate token, update password; 400 on expired)
- [ ] T094 [P] [US6] Apply auth rate limiting (10 req/min per IP) to all `AuthController` endpoints in `server/src/SheetShow.Api/Program.cs`

### Client — Auth Models, Services, and UI

- [ ] T095 [P] [US6] Create `AuthToken` model in `client/lib/features/auth/models/auth_token.dart` — `accessToken`, `refreshToken`, `expiresAt` (DateTime), `userId`; `fromJson` / `toJson`
- [ ] T096 [P] [US6] Create `UserProfile` model in `client/lib/features/auth/models/user_profile.dart` — `userId`, `email`, `displayName`; `fromJson`; stored in Riverpod state after login
- [ ] T097 [P] [US6] Implement `TokenStorageService` in `client/lib/features/auth/services/token_storage_service.dart` — use `flutter_secure_storage` (Windows Credential Manager backend): `saveTokens(AuthToken)`, `loadTokens()` → `AuthToken?`, `clearTokens()`; keys: `sheetshow_access_token`, `sheetshow_refresh_token`, `sheetshow_token_expiry`
- [ ] T098 [P] [US6] Add JWT auth interceptor to `ApiClient` in `client/lib/core/services/api_client.dart` — on every request attach `Authorization: Bearer <accessToken>`; on 401 response call `TokenStorageService.loadTokens`, attempt `POST /auth/refresh`; on successful refresh retry original request once; on refresh 401 clear tokens, emit `unauthenticated` Riverpod state, stop `SyncService`
- [ ] T099 [US6] Implement `AuthService` in `client/lib/features/auth/services/auth_service.dart` — `register(email, password, displayName)`, `login(email, password)`, `logout()`, `refreshToken()`, `forgotPassword(email)`, `resetPassword(email, token, newPassword)`; on login/register: save tokens via `TokenStorageService`, set `UserProfile` in Riverpod state, start `SyncService`; on logout: clear tokens, stop `SyncService`, keep local DB data intact
- [ ] T100 [P] [US6] Create `LoginScreen` in `client/lib/features/auth/ui/login_screen.dart` — email + password `TextField`s, "Log In" `ElevatedButton` (calls `AuthService.login`), loading state, error display via `ErrorDisplayService`, link to `RegisterScreen`, link to `ForgotPasswordScreen`, "Continue without account" button (local-only mode)
- [ ] T101 [P] [US6] Create `RegisterScreen` in `client/lib/features/auth/ui/register_screen.dart` — email, display name, password `TextField`s with validation; "Create Account" button calls `AuthService.register`; error display; link back to `LoginScreen`
- [ ] T102 [P] [US6] Create `ForgotPasswordScreen` in `client/lib/features/auth/ui/forgot_password_screen.dart` — email field, "Send Reset Link" button calls `AuthService.forgotPassword`; always shows "If that email is registered, you'll receive a link shortly" (matches server 202 behaviour)
- [ ] T103 [US6] Implement auth-gated routing in `client/lib/main.dart` — GoRouter `redirect` callback: check `TokenStorageService.loadTokens()` on app launch; if valid token → `/library`; if no token → `/auth/login`; `SyncService.start()` if token present; on logout navigate to `/auth/login`; add `/auth/login`, `/auth/register`, `/auth/forgot-password` routes
- [ ] T104 [US6] Show "Log in to enable sync" prompt in `SyncStatusIndicator` in `client/lib/features/sync/ui/sync_status_indicator.dart` when user is unauthenticated — tap opens `LoginScreen` as modal bottom sheet; local-only mode still shows last-modified timestamps

**Checkpoint**: US6 complete — register, login, sync activates, logout keeps local data, persistent across restarts

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility, edge cases, validation, and final quality gates across all user stories.

- [ ] T105 [P] Add `Semantics` wrapper to all interactive widgets across `client/lib/features/` — `ScoreCard`, `FolderTree` nodes, `SearchBar`, `SetListBuilderScreen` entries, `AnnotationToolbar` buttons, `MergeEditorScreen` actions, auth form fields; validate with `flutter_test` `AccessibilityTester`
- [ ] T106 [P] Implement corrupt/invalid PDF error handling in `client/lib/features/library/services/import_service.dart` — catch `pdfrx` `PdfException`; detect `total_pages = 0`; detect file size 0; surface human-readable error via `ErrorDisplayService`: "This file couldn't be imported — it may be corrupted or password-protected"
- [ ] T107 [P] Implement local storage full detection in `client/lib/features/library/services/import_service.dart` — check `path_provider` free space before copying PDF; if < file size + 50MB buffer, abort import with "Not enough storage space" error via `ErrorDisplayService`
- [ ] T108 [P] Handle mixed portrait/landscape PDF pages in `client/lib/features/reader/ui/pdf_page_view.dart` — read per-page dimensions from `pdfrx` page object; set `PdfPageView` height dynamically per rendered page so landscape pages display without cropping or letterboxing
- [ ] T109 [P] Implement sync interruption recovery in `client/lib/features/sync/services/sync_service.dart` — detect in-flight batch on app restart (entries with `status = in_flight`); reset to `pending` and retry with backoff; prevent duplicate push of same `batchId` using `sync_meta`
- [ ] T110 [P] Handle "score deleted on another device" during sync pull in `client/lib/features/sync/services/sync_service.dart` — when pull receives `delete` for an entity with `pending_update` local state, add to conflict queue as `delete_vs_update` type; show in `MergeEditorScreen`
- [ ] T111 [P] Implement score rename and delete context actions in `client/lib/features/library/ui/library_screen.dart` — long-press `ScoreCard` shows context menu: "Rename" (inline dialog, updates `ScoreRepository`, marks `pendingUpdate`), "Delete" (confirmation dialog, calls `ScoreRepository.softDelete`, enqueues `delete` to `sync_queue`)
- [ ] T112 [P] Handle set list referencing a soft-deleted score in `client/lib/features/setlists/ui/set_list_builder.dart` — already scaffolded in T062; verify "Score not found" warning renders for all such entries and the entry can be removed without affecting the score's tombstone
- [ ] T113 [P] Add quota exceeded notification in `client/lib/features/sync/ui/sync_status_indicator.dart` — when `SyncService` receives `quota_exceeded` push result, display persistent banner: "Cloud storage full — new scores will not sync until storage is freed"; link to account settings stub
- [ ] T114 [P] Add max retry exhaustion notification in `client/lib/features/sync/ui/sync_status_indicator.dart` — when `sync_queue` entry reaches `attempt_count = 10` and is marked `failed`, surface in error log accessible from `SyncStatusIndicator` tap with operation details and "Remove from queue" option
- [ ] T115 [P] Run `flutter analyze` (zero warnings) and `dart format --set-exit-if-changed lib/ test/` across `client/` — fix any violations before marking phase complete
- [ ] T116 [P] Run `dotnet format --verify-no-changes` across `server/src/` — fix any violations
- [ ] T117 Validate developer quickstart end-to-end: `docker compose up -d` (server/) → `dotnet ef database update` → `dotnet run` → confirm Swagger at `https://localhost:7001/swagger`; then `flutter pub get && flutter run -d windows` → confirm app launches to library screen — update `quickstart.md` with any corrections found

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    └── Phase 2 (Foundational) ← BLOCKS all story phases
            ├── Phase 3 (US1 — P1) 🎯 MVP
            ├── Phase 4 (US2 — P2)  ← US1 strongly recommended first (library exists)
            ├── Phase 5 (US3 — P3)  ← US1 required (scores must exist for set lists)
            ├── Phase 6 (US4 — P4)  ← US1 required (reader must exist for annotations)
            ├── Phase 7 (US5 — P5)  ← All prior stories should be done (full sync scope)
            └── Phase 8 (US6 — P6)  ← US5 required (sync must exist to activate)
                    └── Phase 9 (Polish)
```

### User Story Inter-Dependencies

| Story | Hard Dependency | Soft Recommendation |
|-------|----------------|---------------------|
| US1 (Import & View) | Phase 2 complete | — |
| US2 (Folders & Tags) | Phase 2 complete | US1 (library must exist to organize) |
| US3 (Set Lists) | Phase 2 complete | US1 (scores must exist to add to set lists) |
| US4 (Annotation) | Phase 2 complete | US1 (reader screen must exist for overlay) |
| US5 (Sync) | Phase 2 complete | US1–US4 (all data types should exist for full sync coverage) |
| US6 (Auth) | Phase 2 complete | US5 (sync activation depends on auth) |

### Within Each User Story

1. Server entities → server repositories → server controllers
2. Client models → client repositories → client services → client UI
3. Parallelizable tasks ([P] marked) can run simultaneously across different files
4. Service tasks depend on model tasks; UI tasks depend on service tasks

### Parallel Opportunities

**Phase 1**: T003–T009 all parallelizable (independent files)  
**Phase 2**: T010–T014 parallelizable; T015–T016 sequential (DB schema then codegen); T019–T028 partially parallelizable after T021  
**Phase 3**: T029–T033 (server) parallelizable with T034–T038 (client models/repos); T039–T042 depend on prior  
**Phase 4**: T045–T054 mostly parallelizable within client/server split  
**Phase 6**: T055–T064 mostly parallelizable within client/server split  
**Phase 7**: T067–T075 — plugin (T065–T066) then annotation models/repo/services/UI  
**Phase 8**: T076–T088 — models first, then services, then UI  
**Phase 9**: T105–T116 all fully parallelizable (different files, polishing existing code)  

---

## Parallel Execution Examples

### Phase 2 — Foundational

```
Day 1 — All start in parallel:
  Dev A: T010 constants + T011 api_config + T012 theme tokens
  Dev B: T013 ClockService + T014 enums + T015 Drift schema
  Dev C: T021 .NET solution scaffold + T022 constants + T023 interfaces

Day 2 — After T015/T016:
  Dev A: T017 Drift codegen → T018 ErrorDisplayService → T019 ApiClient
  Dev B: T024 GlobalExceptionMiddleware → T025 RequestLoggingMiddleware → T026 Program.cs
  Dev C: T027 ApplicationDbContext → T028 EF migration
```

### Phase 3 — User Story 1 (MVP)

```
Server team (in parallel):
  T029 Score entity ──► T031 ScoreRepository ──► T032 ScoresController ──► T033 wire DI
  T030 AzureBlobStorageService (parallel with T029-T031)

Client team (in parallel with server):
  T034 ScoreModel ──┐
  T035 ScoreRepository (client) ──┤
                                  ├──► T036 ImportService ──► T037 ThumbnailService
  T038 ScoreCard ──┐              │
  T039 LibraryScreen ──┘          └──► T040 PdfPageView ──► T041 ReaderScreen ──► T042 routing
```

### Phase 6 — User Story 4 (Annotation)

```
  T065 Win32 plugin (C++) ──► T066 palm rejection  (blocks T073 AnnotationOverlay platform channel)

  In parallel with plugin work:
  T067 InkStroke model ──┐
  T068 AnnotationLayer model ──┤──► T070 AnnotationRepository ──► T071 AnnotationService
  T069 ToolSettings ──┘                                             └──► T072 InkRendererService

  After T065 + T071 + T072 complete:
  T073 AnnotationOverlay ──► T074 AnnotationToolbar ──► T075 integrate into ReaderScreen
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete **Phase 1** (Setup) — ~1–2 days
2. Complete **Phase 2** (Foundational) — ~2–3 days
3. Complete **Phase 3** (US1 — Import & View) — ~3–4 days
4. **STOP AND VALIDATE**: Import a real PDF → browse library grid → open full-screen → scroll all pages
5. **Demo / deploy** the working digital music stand

### Incremental Delivery

| Milestone | Phases | Delivers |
|-----------|--------|---------|
| MVP | 1 + 2 + 3 | Working PDF library and reader |
| v0.2 | + 4 | Folder organization + tag search |
| v0.3 | + 5 | Set lists + performance mode |
| v0.4 | + 6 | Surface Pen annotation |
| v0.5 | + 7 | Offline-first + cloud sync |
| v1.0 | + 8 + 9 | Auth + polish — full production release |

### Parallel Team Strategy

With three developers after Phase 2:

- **Dev A** → Phase 3 (US1) first, then Phase 6 (US4 — annotation, C++ expertise helpful)
- **Dev B** → Phase 4 (US2) then Phase 5 (US3)
- **Dev C** → Phase 7 (US5 — sync engine + server) then Phase 8 (US6 — auth)

Each developer owns their story end-to-end (server + client) for maximum context locality.

---

## Task Count Summary

| Phase | Tasks | Story |
|-------|-------|-------|
| Phase 1: Setup | T001–T009 | 9 tasks |
| Phase 2: Foundational | T010–T028 | 19 tasks |
| Phase 3: US1 — Import & View | T029–T042 | 14 tasks |
| Phase 4: US2 — Folders & Tags | T043–T054 | 12 tasks |
| Phase 5: US3 — Set Lists | T055–T064 | 10 tasks |
| Phase 6: US4 — Annotation | T065–T075 | 11 tasks |
| Phase 7: US5 — Sync | T076–T090 | 15 tasks |
| Phase 8: US6 — Auth | T091–T104 | 14 tasks |
| Phase 9: Polish | T105–T117 | 13 tasks |
| **Total** | **T001–T117** | **117 tasks** |

---

## Notes

- **[P]** tasks have different target files and no incomplete task dependencies — safe to run in parallel
- **[US#]** labels map every task to its user story for full traceability back to spec.md
- Each user story phase produces an independently testable increment — validate before moving to the next
- TDD: write failing tests first for every task; tests live in `client/test/unit/`, `client/test/integration/`, `server/tests/SheetShow.UnitTests/`, `server/tests/SheetShow.IntegrationTests/`
- Commit after each completed task or logical group; use conventional commits (`feat(US1): ...`)
- Stop at any phase checkpoint to validate the story works independently before starting the next priority
- The Drift schema (T015–T016) and EF Core migration (T028) are the highest-risk foundational tasks — prioritize reviewing these before building on top of them
