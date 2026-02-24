# Feature Specification: SheetShow — Windows Sheet Music Manager

**Feature Branch**: `001-sheet-music-app`  
**Created**: 2025-07-24  
**Status**: Draft  
**Input**: User description: "I want to build a windows desktop application that is connected to a cloud backend that helps me to store, view and edit sheet music pdf files. It needs to support the easy creation of set lists through both drag and drop and also searching, folders to organize the sheet music by, and tagging to help with searching. I want to be able to easily make edits to the pdf with my surface pen. The desktop application should be fully standalone and save a copy of the sheet music/set lists locally so that it works without an internet connection. A user should be able to log in through the desktop application and it should then sync with the cloud backend. We can use the application Forescore for inspiration."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Import and View Sheet Music (Priority: P1)

A musician imports PDF sheet music files into the application and views them on their device. They can browse their full library, open any score, and navigate multi-page documents with ease. This is the foundation of the app — everything else depends on having music in the library.

**Why this priority**: Without the ability to store and view sheet music, the application has no value. This story delivers the core reading experience and forms the basis for all other features.

**Independent Test**: Can be fully tested by importing a PDF, browsing the library, and opening/scrolling the document — delivering a usable digital music stand with no other features needed.

**Acceptance Scenarios**:

1. **Given** the user opens the app for the first time, **When** they import a PDF file from their device, **Then** the file appears in the library with its filename as the title and can be opened immediately.
2. **Given** a multi-page PDF is open, **When** the user scrolls or swipes between pages, **Then** all pages render clearly and page turns are smooth.
3. **Given** the library contains multiple scores, **When** the user opens the library view, **Then** scores are displayed with thumbnails and titles for easy identification.
4. **Given** a large PDF file (50+ pages), **When** the user opens it, **Then** the document is fully navigable with no visible rendering lag.

---

### User Story 2 - Organize with Folders and Tags (Priority: P2)

A musician organizes their growing library by creating folders (e.g., "Jazz Standards", "Classical", "Hymns") and assigning tags (e.g., "upbeat", "ballad", "key:G", "difficulty:beginner") to individual scores. They can then filter and search by folder or tag to quickly locate any piece.

**Why this priority**: Once a library grows beyond a handful of scores, organization becomes essential. Folders and tags together provide both hierarchical structure and flexible cross-cutting search.

**Independent Test**: Can be fully tested by creating folders, moving scores into them, adding tags to scores, then searching by tag and browsing by folder — delivering meaningful library organization independent of set lists or sync.

**Acceptance Scenarios**:

1. **Given** the user has scores in the library, **When** they create a folder and drag scores into it, **Then** those scores appear inside that folder and remain browsable.
2. **Given** a score in the library, **When** the user adds one or more tags to it, **Then** the tags are saved and displayed on the score card.
3. **Given** the user enters a tag name in the search field, **When** they execute the search, **Then** all scores with that tag are returned in the results.
4. **Given** a folder structure with nested folders, **When** the user navigates into a sub-folder, **Then** only the scores within that sub-folder are shown.
5. **Given** a search query that matches both a score title and a tag, **When** the user searches, **Then** all matching scores are shown regardless of match type.

---

### User Story 3 - Create and Use Set Lists (Priority: P3)

A musician builds a set list for an upcoming performance by searching for scores and dragging them into an ordered playlist. They can reorder items within the list by drag and drop, rename the set list, and open it during a performance to step through pieces in order.

**Why this priority**: Set lists are a key performance workflow that differentiates this app from a basic PDF viewer. They build directly on the library and organization features.

**Independent Test**: Can be fully tested by creating a set list, adding and reordering scores, then opening the set list in "performance mode" to page through scores in sequence.

**Acceptance Scenarios**:

1. **Given** the user creates a new set list, **When** they drag a score from the library into the set list, **Then** the score appears as an ordered entry in the set list.
2. **Given** a set list with multiple entries, **When** the user drags an entry to a new position, **Then** the order updates immediately.
3. **Given** the user types in the set list search bar, **When** results appear, **Then** they can click or tap a result to add it to the set list without leaving the set list view.
4. **Given** an open set list, **When** the user activates performance mode and advances to the next piece, **Then** the corresponding score opens full-screen at its first page.
5. **Given** a set list, **When** the user renames or deletes it, **Then** the change is reflected immediately and previously added scores are not affected.

---

### User Story 4 - Annotate Sheet Music with Surface Pen (Priority: P4)

A musician annotates a score directly on-screen using their Surface Pen — writing fingering marks, dynamic changes, bowing indications, and personal notes. Annotations are saved per-score and persist across sessions. They can undo mistakes and clear all annotations if needed.

**Why this priority**: Pen annotation is a high-value differentiator for Surface device users, closely mirroring how musicians mark up physical sheet music. It does not block the other stories and can be developed independently.

**Independent Test**: Can be fully tested by opening a score, making pen annotations, closing the app, reopening the score, and confirming annotations are preserved exactly as drawn.

**Acceptance Scenarios**:

1. **Given** a score is open and pen annotation mode is active, **When** the user draws with the Surface Pen, **Then** ink strokes appear overlaid on the score at the correct position.
2. **Given** the user made an annotation error, **When** they tap the undo button, **Then** the last stroke is removed without affecting other annotations.
3. **Given** a score with annotations, **When** the user closes and reopens the app, **Then** all annotations are restored exactly as drawn.
4. **Given** the user selects "Clear All Annotations" for a score, **When** they confirm, **Then** all ink strokes are removed and the score returns to its original clean state.
5. **Given** the user switches between annotation tools (pen, highlighter, eraser), **When** they draw, **Then** each tool produces visually distinct marks appropriate to its type.

---

### User Story 5 - Offline-First with Cloud Sync (Priority: P5)

A musician uses the app without an internet connection during a rehearsal — all their scores, set lists, folders, and annotations are available locally. When they reconnect and log in, the app automatically syncs any changes (new imports, annotations, set list edits) to the cloud backend, and pulls down any changes made on other sessions.

**Why this priority**: Offline reliability is a non-negotiable requirement for live performance scenarios. Cloud sync extends this to multi-device and backup use cases. This builds on all other stories being fully local-first.

**Independent Test**: Can be fully tested by using the app offline to import a score and annotate it, then connecting and verifying the changes appear in the cloud-backed account.

**Acceptance Scenarios**:

1. **Given** the device has no internet connection, **When** the user opens the app, **Then** all previously synced scores, set lists, and annotations are fully accessible.
2. **Given** the user imports a new score while offline, **When** the device reconnects, **Then** the new score is automatically uploaded to the cloud backend without user action.
3. **Given** the user is logged in and connected, **When** they open the app, **Then** any scores or set lists added from other devices (or the cloud) are downloaded and appear in the library.
4. **Given** a sync is in progress, **When** the user views the sync status indicator, **Then** they can see that sync is active and when it last completed.
5. **Given** the user is not logged in, **When** they use the app, **Then** all features work locally and they are prompted to log in only when they choose to enable cloud sync.

---

### User Story 6 - User Account and Authentication (Priority: P6)

A musician creates an account, logs in through the desktop application, and securely links their local library to their cloud account. They can log out (which retains local copies but stops syncing) and log back in to resume syncing.

**Why this priority**: Authentication gates cloud sync and cross-device access. It is intentionally lower priority because the app works fully offline without it.

**Independent Test**: Can be fully tested by creating an account, logging in, verifying the library syncs, logging out, and confirming local data is still accessible.

**Acceptance Scenarios**:

1. **Given** a new user, **When** they register with an email and password, **Then** an account is created and they are logged in on the desktop app.
2. **Given** a returning user, **When** they enter valid credentials and log in, **Then** cloud sync activates and their library begins syncing.
3. **Given** a logged-in user, **When** they log out, **Then** cloud sync stops but all locally cached scores, set lists, and annotations remain accessible.
4. **Given** a user enters incorrect credentials, **When** they attempt to log in, **Then** a clear error message is shown and no data is modified.
5. **Given** a user has forgotten their password, **When** they request a reset, **Then** they receive a reset link via email and can set a new password.

---

### Edge Cases

- What happens when a PDF import fails (corrupted file, unsupported format)?
- How does the app handle a score that exists in both the local library and the cloud with conflicting annotation states? The user is prompted via a merge editor: both the local version and the cloud version are presented side-by-side (similar to a code merge editor), allowing the user to selectively accept changes from either side or combine elements from both before confirming the resolved version.
- What happens when available local storage is nearly full and a new score is imported?
- What happens when a sync is interrupted mid-transfer (network drops during upload)?
- How are scores that have been deleted on one device handled when syncing with another device that still has them?
- What happens when a set list references a score that has been deleted from the library?
- How does the app behave when the PDF contains non-standard page sizes or landscape/portrait mixed layouts?

## Requirements *(mandatory)*

### Functional Requirements

**Library Management**

- **FR-001**: Users MUST be able to import PDF files from their local file system into the application library.
- **FR-002**: The system MUST store a local copy of every imported score so the library is fully accessible without an internet connection.
- **FR-003**: Users MUST be able to view any score from the library in a full-screen reading view with smooth page navigation.
- **FR-004**: Users MUST be able to create, rename, and delete folders to organize their scores.
- **FR-005**: Users MUST be able to move scores between folders using drag and drop.
- **FR-006**: Users MUST be able to add, edit, and remove one or more tags on any score.
- **FR-007**: Users MUST be able to search their library by score title and by tag, with results shown in real time as they type.
- **FR-008**: Users MUST be able to rename and delete scores from the library.

**Set Lists**

- **FR-009**: Users MUST be able to create, rename, and delete set lists.
- **FR-010**: Users MUST be able to add scores to a set list by dragging from the library or by searching within the set list builder.
- **FR-011**: Users MUST be able to reorder scores within a set list using drag and drop.
- **FR-012**: Users MUST be able to remove individual scores from a set list without deleting the score from the library.
- **FR-013**: The system MUST support a performance mode that opens scores in a set list sequentially, advancing to the next piece on demand.

**Annotation**

- **FR-014**: Users MUST be able to activate a pen annotation mode while viewing any score.
- **FR-015**: The system MUST support at minimum three annotation tools: freehand ink pen, highlighter, and eraser.
- **FR-016**: Annotations MUST be stored separately from the original PDF so the source file is never modified.
- **FR-017**: Users MUST be able to undo the most recent annotation strokes individually.
- **FR-018**: Users MUST be able to clear all annotations on a score with a single confirmed action.
- **FR-019**: The annotation layer MUST be optimized for Surface Pen input, supporting palm rejection while drawing.

**Offline and Sync**

- **FR-020**: The application MUST function fully without an internet connection, including all library, set list, and annotation features.
- **FR-021**: When connected and authenticated, the application MUST automatically sync all scores, annotations, set lists, folders, and tags with the cloud backend.
- **FR-022**: The application MUST display a sync status indicator showing the current sync state and timestamp of last successful sync.
- **FR-023**: The application MUST queue offline changes (imports, edits, deletions) and apply them to the cloud on the next successful connection.
- **FR-024**: When a sync conflict is detected (the same score, annotation set, or set list has been modified on multiple devices since the last sync), the application MUST present a merge editor interface. The merge editor MUST display the local version and the cloud version side-by-side, allow the user to accept changes from either version selectively or combine content from both, and save the resolved version as the new canonical state across all devices.

**Authentication**

- **FR-025**: Users MUST be able to register a new account with an email address and password from within the desktop application.
- **FR-026**: Users MUST be able to log in and log out of their cloud account from within the desktop application.
- **FR-027**: The system MUST support password reset via email.
- **FR-028**: Authentication state MUST persist across app restarts so the user is not required to log in every session.
- **FR-029**: The application MUST continue to operate in full offline-only mode if the user chooses not to log in or has no account.

### Key Entities

- **Score**: A single sheet music document. Has a title, one or more source PDF pages, an annotation layer, zero or more tags, a parent folder (optional), timestamps, and a sync state.
- **Folder**: A named container for organizing scores. Can be nested. Belongs to a user's library.
- **Tag**: A user-defined label string associated with one or more scores. Supports free-text entry.
- **Set List**: An ordered collection of score references belonging to a user. Has a name, creation date, and an ordered list of score IDs.
- **Annotation Layer**: A per-page, per-score collection of ink strokes, highlights, and erasures. Stored independently of the source PDF.
- **User Account**: Represents an authenticated user. Links a local library to a cloud identity. Stores credentials securely.
- **Sync Queue**: A local record of pending changes (create, update, delete operations) to be applied to the cloud backend on next connection.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can import a PDF, add tags, assign it to a folder, and view it in under 60 seconds from first launch.
- **SC-002**: A user can build a set list of 10 songs using drag and drop in under 2 minutes.
- **SC-003**: Opening a score and navigating between pages takes no more than 1 second per page turn on a standard Surface device.
- **SC-004**: All scores, set lists, and annotations are fully accessible within 5 seconds of opening the app while offline.
- **SC-005**: After reconnecting to the internet, pending offline changes are synced to the cloud within 30 seconds without user intervention.
- **SC-006**: Pen annotations are visible on-screen within 50 milliseconds of the pen stroke, with no perceptible lag during writing.
- **SC-007**: A search query against a library of 500 scores returns results in under 1 second.
- **SC-008**: No data loss occurs for any locally stored score or annotation after an app crash or forced close.

## Assumptions

- The application targets individual musicians (single-user per account); multi-user collaboration and shared libraries are out of scope for this version.
- PDF is the only supported file format for sheet music; image-based formats (JPG, PNG) and MusicXML are not in scope.
- Annotations are ink-only overlays; full PDF text/object editing is not in scope.
- Cloud storage per user will follow a reasonable personal-use quota (e.g., similar to cloud storage services offering 5–15 GB free); specific quota limits will be determined during planning.
- The app targets Windows 10 and Windows 11 only; no mobile or web client is in scope for this version.
- Internet connectivity is detected automatically; the user does not need to manually toggle online/offline modes.
- Scores deleted by the user are soft-deleted during the sync grace period to allow recovery from accidental deletion across devices.
