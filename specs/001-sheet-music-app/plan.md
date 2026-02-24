# Implementation Plan: SheetShow — Windows Sheet Music Manager

**Branch**: `001-sheet-music-app` | **Date**: 2025-07-24 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/001-sheet-music-app/spec.md`

## Summary

SheetShow is an **offline-first Windows desktop application** for musicians to import, view, annotate, and organize PDF sheet music, build performance set lists, and sync everything to a personal cloud account. The application is built on **Flutter 3.x (Dart)** for Windows-first delivery with clean portability to iOS and Android in a future phase, backed by a **.NET 8 ASP.NET Core** cloud API deployed on **Azure** using Clean Architecture for cloud-agnosticism.

Key architectural pillars:

- **Flutter desktop client** with `pdfrx` (PDFium-based) for PDF rendering and a Win32 platform channel plugin for Surface Pen pressure, tilt, and palm-rejection via the Windows Ink API
- **Drift (SQLite) + FTS5** for local-first data access with real-time full-text search across 500+ scores — all features work offline
- **Hybrid event-log + server-timestamp sync** via REST polling with exponential backoff; annotation conflicts are resolved in a side-by-side merge editor
- **ASP.NET Core Identity + JWT** for cloud-agnostic authentication; **PostgreSQL + EF Core** for relational data; **`IFileStorageService` abstraction** over Azure Blob Storage for portability
- Deployed on **Azure Container Apps** + **Azure Database for PostgreSQL Flexible Server** + **Azure Blob Storage**

## Technical Context

**Language/Version**: Dart 3.5 / Flutter 3.24 (client); C# 12 / .NET 8 (server)  
**Primary Dependencies**: `pdfrx` 2.x, `drift` 2.x, `flutter_secure_storage`, `riverpod`; ASP.NET Core Identity, EF Core 8, Npgsql, `Azure.Storage.Blobs`  
**Storage**: Drift/SQLite (local); Azure Database for PostgreSQL Flexible Server + Azure Blob Storage (cloud)  
**Testing**: `flutter_test` + `integration_test`; xUnit 2 + Moq + `WebApplicationFactory`  
**Target Platform**: Windows 10/11 (primary); iOS 16+ / Android 10+ (future — architecture supports, out of current scope)  
**Project Type**: Desktop app (Flutter) + cloud REST API (.NET 8)  
**Performance Goals**: Ink latency ≤ 50 ms (SC-006); page turn ≤ 1 s (SC-003); search < 1 s on 500 scores (SC-007); app ready offline < 5 s (SC-004); sync on reconnect < 30 s (SC-005)  
**Constraints**: Fully offline-capable; no data loss on crash (SQLite WAL mode, SC-008); source PDFs never modified (FR-016); single-user per account  
**Scale/Scope**: ~500 scores per library; 6 user stories; single-user accounts; Azure-first with cloud-agnostic interfaces

## Constitution Check

*GATE: All principles evaluated. No blocking violations. Two metric adaptations documented for desktop context.*

### I. Code Quality — ✅ PASS

| Principle | Status | Implementation Commitment |
|-----------|--------|---------------------------|
| Single Responsibility | ✅ Pass | Clean Architecture on server (Core / Infrastructure / Api); feature modules on client (`library`, `reader`, `setlists`, `sync`, `auth`) — each with isolated models/services/ui |
| Readable by Default (≤50 lines, ≤3 nesting) | ✅ Pass | `flutter_lints` + `dart_code_metrics` enforced in CI; sync engine decomposed into `SyncQueue`, `ConflictDetector`, `MergeEditorService` sub-units |
| No Magic Values | ✅ Pass | `client/lib/core/constants/` for all timeouts, limits, keys; `server/src/SheetShow.Core/Constants/` for all literals |
| Dead-Code Free | ✅ Pass | `flutter analyze` (zero-warnings policy) + `dotnet format --verify-no-changes` in CI blocks merge on violations |
| Documented Public API | ✅ Pass | All exported Flutter services/models carry `///` doc comments; all C# public types carry XML `<summary>` doc comments |
| Linting & Formatting | ✅ Pass | `flutter_lints` + `dart format --set-exit-if-changed`; `dotnet format --verify-no-changes` + `StyleCop.Analyzers` |
| Complexity Cap (cyclomatic ≤ 10) | ✅ Pass | `dart_code_metrics` cyclomatic check in CI; complex sync/merge logic deliberately split into small named functions |

### II. Testing Standards — ✅ PASS

| Principle | Status | Implementation Commitment |
|-----------|--------|---------------------------|
| Test-First (TDD) | ✅ Pass | Red → Green → Refactor cycle; tests present in PR before implementation reviewed |
| Coverage ≥ 80% | ✅ Pass | `flutter test --coverage` + `lcov` threshold; `dotnet-coverage collect` + report threshold — both block merge below 80% |
| Independence | ✅ Pass | Drift in-memory DB for client unit tests; `WebApplicationFactory` with isolated test DB for server integration tests |
| Determinism | ✅ Pass | `IClock` / `ClockService` abstraction — no `DateTime.now()` in production logic; no network calls in unit tests |
| Integration Coverage | ✅ Pass | Sync push/pull, auth flows (register/login/refresh/reset), file upload/download covered by integration test suite |
| Test Naming | ✅ Pass | `given_<state>_when_<action>_then_<outcome>` convention in both Dart and C# test projects |

### III. User Experience Consistency — ✅ PASS

| Principle | Status | Implementation Commitment |
|-----------|--------|---------------------------|
| Design System First | ✅ Pass | Flutter `ThemeData` with shared design tokens (colours, spacing, typography, radii) in `core/theme/`; inline ad-hoc style values prohibited |
| Human-Readable Errors | ✅ Pass | `ErrorDisplayService` maps all technical errors → user-readable strings with corrective actions; no stack traces in UI |
| Always Communicate State | ✅ Pass | All operations >200 ms display skeleton/progress widget; sync, PDF load, search have dedicated loading states |
| Consistent Patterns | ✅ Pass | Drag-and-drop, modals, search bar, performance mode patterns defined in design system before feature work begins |
| Accessibility (WCAG 2.1 AA) | ✅ Pass | Flutter `Semantics` widgets on all interactive elements; colour contrast validated via design tokens; keyboard navigation covered in integration tests |

### IV. Performance Requirements — ✅ PASS (with documented desktop adaptations)

| Principle | Status | Note |
|-----------|--------|------|
| FCP < 2 s / TTI < 3 s | ✅ **Adapted** | Web metric. Desktop adaptation: "App Ready" (library rendered, interaction enabled) ≤ 3 s on a mid-range Surface device; measured via Flutter DevTools frame timeline in CI. Aligns with SC-004 (full offline access ≤ 5 s). |
| Interaction < 100 ms feedback | ✅ Pass | Ink ≤ 50 ms (SC-006 — stricter than constitution); all button/nav interactions produce visible feedback ≤ 100 ms |
| Bundle discipline (≤10 kB JS growth) | ✅ **Adapted** | Web metric. Desktop adaptation: all new Flutter/Dart packages require documented size-impact review; APK/EXE size must not grow by > 500 KB per PR without explicit approval |
| No Memory Leaks | ✅ Pass | Flutter `dispose()` enforced; Drift stream subscriptions cancelled on widget dispose; `flutter_test` memory leak assertions in integration tests |
| Regression Gate (> 10% blocks) | ✅ Pass | Flutter DevTools benchmark suite in CI; `BenchmarkDotNet` on server sync hot paths; > 10% regression blocks merge |

### Quality Gates — ✅ ALL MAPPED

| Gate | Tool | Blocks Merge? |
|------|------|---------------|
| Linting & formatting | `flutter analyze` + `dart format` + `dotnet format` | Yes |
| Unit test coverage ≥ 80% | `lcov` + `dotnet-coverage` in CI | Yes |
| All tests pass | `flutter test` + `xUnit` CI suite | Yes |
| Dependency size delta | Flutter APK size diff (> 500 kB new dep = review required) | Yes |
| Performance baseline | Flutter DevTools benchmarks + `BenchmarkDotNet` | Yes (> 10% regression) |
| Accessibility scan | Flutter `AccessibilityTester`; `axe` on any web views | Yes (new violations) |
| Peer code review | ≥ 1 approval from a team member | Yes |

## Project Structure

### Documentation (this feature)

```text
specs/001-sheet-music-app/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0: tech stack decisions with rationale
├── data-model.md        # Phase 1: entity schemas (client SQLite + server PostgreSQL)
├── quickstart.md        # Phase 1: developer setup guide
├── contracts/
│   ├── rest-api.md      # REST API endpoint contracts (auth, scores, folders, set lists, annotations)
│   └── sync-protocol.md # Sync push/pull/conflict protocol specification
└── tasks.md             # Phase 2 output (/speckit.tasks command — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
sheetshow/
│
├── client/                                  # Flutter desktop + future mobile app
│   ├── lib/
│   │   ├── features/
│   │   │   ├── library/                     # US1 + US2: Score import, browse, folders, tags
│   │   │   │   ├── models/                  # ScoreModel, FolderModel, TagModel
│   │   │   │   ├── repositories/            # ScoreRepository, FolderRepository (Drift)
│   │   │   │   ├── services/                # ImportService, ThumbnailService, SearchService
│   │   │   │   └── ui/                      # LibraryScreen, ScoreCard, FolderTree, SearchBar
│   │   │   ├── reader/                      # US1 + US4: PDF viewer + pen annotation
│   │   │   │   ├── models/                  # AnnotationLayer, InkStroke, ToolSettings
│   │   │   │   ├── repositories/            # AnnotationRepository (Drift)
│   │   │   │   ├── services/                # AnnotationService, InkRendererService
│   │   │   │   └── ui/                      # ReaderScreen, PdfPageView, AnnotationOverlay, Toolbar
│   │   │   ├── setlists/                    # US3: Set list builder + performance mode
│   │   │   │   ├── models/                  # SetListModel, SetListEntryModel
│   │   │   │   ├── repositories/            # SetListRepository (Drift)
│   │   │   │   └── ui/                      # SetListsScreen, SetListBuilder, PerformanceModeScreen
│   │   │   ├── sync/                        # US5: Sync engine + conflict resolution
│   │   │   │   ├── models/                  # SyncQueueEntry, ConflictInfo, SyncStatus
│   │   │   │   ├── services/                # SyncService, ConflictDetector, SyncQueueProcessor
│   │   │   │   └── ui/                      # SyncStatusIndicator, MergeEditorScreen
│   │   │   └── auth/                        # US6: Authentication + account
│   │   │       ├── models/                  # AuthToken, UserProfile
│   │   │       ├── services/                # AuthService, TokenStorageService
│   │   │       └── ui/                      # LoginScreen, RegisterScreen, ForgotPasswordScreen
│   │   ├── core/
│   │   │   ├── database/                    # Drift schema: all tables, DAOs, migrations, FTS5
│   │   │   ├── models/                      # Shared enums: SyncState, AnnotationTool
│   │   │   ├── services/                    # ApiClient, ErrorDisplayService, ClockService
│   │   │   ├── constants/                   # kApiBaseUrl, kMaxFolderDepth, kSyncPollInterval, etc.
│   │   │   └── theme/                       # ThemeData, AppColors, AppSpacing, AppTypography
│   │   └── main.dart
│   ├── windows/
│   │   └── runner/
│   │       └── windows_ink_plugin/          # Win32 C++ platform channel: WM_POINTER → pressure/tilt/palm rejection
│   ├── test/
│   │   ├── unit/                            # Per-feature unit tests (in-memory Drift, mocked services)
│   │   └── integration/                     # Flutter integration tests (library import, sync flow, auth)
│   ├── integration_test/                    # Flutter integration_test package (device/emulator tests)
│   ├── analysis_options.yaml                # flutter_lints + dart_code_metrics (complexity cap)
│   └── pubspec.yaml
│
├── server/                                  # .NET 8 Web API — Clean Architecture
│   ├── src/
│   │   ├── SheetShow.Core/                  # Domain layer — zero infrastructure dependencies
│   │   │   ├── Entities/                    # Score, Folder, SetList, AnnotationLayer, SyncLog, User
│   │   │   ├── Interfaces/                  # IFileStorageService, IEmailService, ISecretsManager, IScoreRepository
│   │   │   ├── Services/                    # SyncService, ConflictDetectionService, StorageQuotaService
│   │   │   └── Constants/                   # QuotaLimits, TombstoneDays, TokenExpiry, etc.
│   │   ├── SheetShow.Infrastructure/        # Infrastructure layer — implements Core interfaces
│   │   │   ├── Persistence/                 # ApplicationDbContext, EF Core migrations, repository implementations
│   │   │   ├── Azure/                       # AzureBlobStorageService, AzureKeyVaultSecretsManager
│   │   │   ├── Email/                       # SmtpEmailService (IEmailService)
│   │   │   └── Identity/                    # ASP.NET Core Identity configuration, JWT token service
│   │   └── SheetShow.Api/                   # Presentation layer — controllers, middleware, DI root
│   │       ├── Controllers/                 # AuthController, ScoresController, FoldersController, SetListsController, SyncController
│   │       ├── Middleware/                  # GlobalExceptionMiddleware, RequestLoggingMiddleware
│   │       ├── Program.cs                   # DI composition root + middleware pipeline
│   │       └── appsettings.{env}.json
│   ├── tests/
│   │   ├── SheetShow.UnitTests/             # Domain service unit tests (no DB, no HTTP)
│   │   └── SheetShow.IntegrationTests/      # Full API tests via WebApplicationFactory + test PostgreSQL
│   ├── docker-compose.yml                   # Local dev: PostgreSQL 16 + Azurite
│   ├── Dockerfile                           # Multi-stage build for Container Apps deployment
│   └── SheetShow.sln
│
├── specs/
│   └── 001-sheet-music-app/                 # This feature's design artifacts (above)
│
└── .github/
    └── workflows/
        ├── client-ci.yml                    # Flutter: analyze → test → coverage → build windows
        └── server-ci.yml                    # .NET: format → test → coverage → docker build
```

**Structure Decision**: Two top-level projects (`client/` + `server/`) reflect the hard boundary between the Flutter desktop app and the .NET cloud API. The `windows/runner/windows_ink_plugin/` sub-directory is a Win32 C++ platform channel living inside the client project — not a separate project — since it is a client-side input concern. Clean Architecture within `server/` enforces that `SheetShow.Core` has zero dependencies on Azure or EF Core, making cloud-provider swap a matter of registering different `SheetShow.Infrastructure` implementations.

## Complexity Tracking

No constitution violations requiring justification. All architectural decisions fall within constitutional bounds.

The two metric adaptations (web FCP/TTI → desktop "App Ready" ≤ 3 s; JS bundle size → APK/EXE delta review) are domain-appropriate translations of web-centric constitution language to a native desktop application. They are not weakening of the intent — performance regression gates and dependency size discipline are preserved in equivalent form.
