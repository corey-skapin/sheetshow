# 🎵 SheetShow

**SheetShow** is an offline Windows desktop app for managing, viewing and performing from your sheet music PDF collection. Organise your scores into folders, tag them, build set lists for gigs and rehearsals, annotate pages with a pen, and run a distraction-free performance mode — all without an internet connection.

## Features

- **PDF Library** — Import individual files or entire folder trees. SheetShow references your PDFs in-place, so nothing gets moved or copied.
- **Folders & Tags** — Organise scores in nested folders. Apply tags to individual scores or whole folders — folder tags are automatically inherited by every score inside.
- **Full-text Search** — Find any score instantly by title or tag.
- **Set Lists** — Build ordered playlists of scores for a gig, rehearsal or practice session. Drag to reorder, add from search results.
- **Performance Mode** — Full-screen, distraction-free reading. Tap the left/right edge or swipe to move between scores. A sidebar shows the full set list with your current position.
- **Pen Annotations** — Draw on any page with pen or highlighter. Choose colours, adjust stroke width, undo and clear. Annotations are saved per page and persist across sessions.
- **File Watching** — SheetShow watches your workspace folder for changes. Add, rename or delete a PDF on disk and the library updates automatically.
- **Portable Data** — All app data (database, annotations) lives inside a `.sheetshow` folder in your workspace. Back up the workspace folder and you back up everything. Re-import the same folder on a fresh install and all your set lists, tags and annotations come back.

## Getting Started

### Install

Download the latest release from the [Releases page](https://github.com/corey-skapin/sheetshow/releases):

- **`SheetShow-x.y.z-setup.exe`** — Standard Windows installer. Adds a Start Menu shortcut and optionally a desktop icon.
- **`SheetShow-x.y.z-windows-x64-portable.zip`** — Portable version. Extract anywhere and run `sheetshow.exe`.

> **Note:** Windows may show a SmartScreen warning on first launch since the app isn't code-signed. Click **More info → Run anyway**.

### First Launch

1. **Choose a workspace folder** — Pick the top-level folder where your sheet music PDFs live. SheetShow will scan it recursively and import everything it finds.
2. **Browse your library** — Scores appear in the main library view, organised by the folder structure on disk.
3. **Start organising** — Add tags, create set lists, open a score to read or annotate.

### Workflow

| Task | How |
|------|-----|
| Import more scores | Drop new PDFs into your workspace folder — they appear automatically |
| Tag scores | Select one or more scores → click the tag icon |
| Tag a folder | Right-click a folder → Tags (all scores inside inherit the tag) |
| Create a set list | Go to **Set Lists** → **+ New** → search and add scores |
| Perform | Open a set list → click **Play** → full-screen mode with edge-tap navigation |
| Annotate | Open a score → click the pen icon → draw, highlight, undo |
| Exit workspace | Menu (⋮) → **Exit Workspace** (data is preserved for re-entry) |

## Architecture

SheetShow is a Flutter Windows desktop application following a **feature-first** architecture with clean separation of concerns.

### Project Structure

```
client/
├── lib/
│   ├── main.dart                  # Entry point, router, workspace gate
│   ├── core/                      # Shared infrastructure
│   │   ├── database/              # Drift (SQLite) schema & migrations
│   │   ├── services/              # ClockService, WorkspaceService, FolderWatchService
│   │   ├── constants/             # App-wide constants
│   │   └── theme/                 # Material Design theming
│   └── features/                  # Feature modules
│       ├── workspace/             # Workspace setup screen
│       ├── library/               # Score browsing, folders, tags, import
│       │   ├── ui/                # Screens & widgets
│       │   ├── repositories/      # ScoreRepository, FolderRepository
│       │   ├── services/          # ImportService, SearchService
│       │   └── models/            # ScoreModel, FolderModel
│       ├── reader/                # PDF viewer & annotations
│       │   ├── ui/                # ReaderScreen, AnnotationOverlay, toolbar
│       │   ├── repositories/      # AnnotationRepository
│       │   ├── services/          # AnnotationService (StateNotifier)
│       │   └── models/            # InkStroke, AnnotationLayer, ToolSettings
│       └── setlists/              # Set lists & performance mode
│           ├── ui/                # SetListBuilder, PerformanceModeScreen
│           ├── repositories/      # SetListRepository
│           └── models/            # SetListModel, SetListEntryModel
├── test/                          # Unit & integration tests
├── windows/                       # Native Windows runner (C++)
└── installer.iss                  # Inno Setup installer script
```

### Technology Stack

| Layer | Technology |
|-------|-----------|
| **UI Framework** | Flutter 3.24 (Windows desktop) |
| **State Management** | Riverpod 2 (providers, StateNotifier) |
| **Database** | Drift (SQLite) with FTS5 full-text search |
| **PDF Rendering** | pdfrx (PDFium-based) |
| **Routing** | GoRouter |
| **Build & Release** | GitHub Actions, Inno Setup |

### Key Design Decisions

- **Offline-first** — No internet required, ever. All data lives on disk alongside your PDFs.
- **In-place references** — Scores are never copied. The database stores the original file path, so your existing folder structure stays untouched.
- **Workspace gate** — The app won't render the main UI until a workspace is configured and the database is ready. This is enforced by a `_WorkspaceGate` widget that shows a setup screen, loading spinner, or error state as needed.
- **ClockService abstraction** — All production code uses an injected `ClockService` instead of `DateTime.now()`, making timestamps deterministic in tests.
- **Inherited tags** — Tags on a folder automatically apply to every score inside it. This is computed via SQL joins at query time, so moving a score between folders instantly changes its effective tags.
- **Rename rollback** — When renaming a score or folder, the file/directory is renamed on disk first, then the database is updated. If the database write fails, the rename is rolled back to keep filesystem and database consistent.
- **File watching** — `FolderWatchService` uses `Directory.watch()` to detect filesystem changes in real time, plus a full `scanWorkspace()` on startup to catch anything that changed while the app was closed.

### Data Storage

```
your-music-folder/
├── Classical/
│   ├── Moonlight Sonata.pdf
│   └── Clair de Lune.pdf
├── Jazz/
│   └── Autumn Leaves.pdf
└── .sheetshow/              ← created by SheetShow
    └── data.db              ← SQLite database (scores, tags, set lists, annotations)
```

The `.sheetshow` directory contains the entire application state. To back up or migrate your library, just copy your workspace folder.

## Development

### Prerequisites

- Flutter 3.24+ (stable channel)
- Visual Studio 2022 with C++ desktop development workload
- Windows 10/11

### Build & Run

```bash
cd client
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # generate Drift code
flutter run -d windows
```

### Test

```bash
cd client
flutter test test/
```

### Release

Push a version tag to trigger the release workflow:

```bash
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

This runs CI checks, builds a Windows release, creates an Inno Setup installer and a portable ZIP, and publishes them as a GitHub Release.

## Licence

This project is not currently published under an open-source licence. All rights reserved.
