# Data Model: SheetShow

**Phase**: Phase 1 — Design  
**Date**: 2025-07-24  
**Source**: `spec.md` (Key Entities section) + `research.md`

---

## Overview

The data model spans two storage layers:

1. **Client (Drift / SQLite)** — local-first store on the device; source of truth when offline
2. **Server (EF Core / PostgreSQL)** — cloud-authoritative store; holds canonical versions after sync

All IDs are UUIDs (String on client, `Guid` on server). Timestamps are stored as UTC.

---

## Client Schema (Drift / SQLite)

### `scores`

Primary entity for a sheet music document.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PK | UUID v4, generated on client |
| `title` | TEXT | NOT NULL | Display name; defaults to filename stem |
| `filename` | TEXT | NOT NULL | Original imported filename |
| `local_file_path` | TEXT | NOT NULL | Absolute path to local PDF copy |
| `total_pages` | INTEGER | NOT NULL, ≥1 | Extracted from PDF on import |
| `thumbnail_path` | TEXT | NULLABLE | Path to generated first-page thumbnail |
| `folder_id` | TEXT | FK → `folders.id`, NULLABLE | NULL = root library |
| `imported_at` | INTEGER | NOT NULL | Unix epoch ms |
| `updated_at` | INTEGER | NOT NULL | Unix epoch ms; updated on metadata change |
| `sync_state` | TEXT | NOT NULL | Enum: `synced \| pending_upload \| pending_update \| pending_delete \| conflict` |
| `cloud_id` | TEXT | NULLABLE | Server-assigned UUID after first sync |
| `server_version` | INTEGER | NULLABLE | Last known server version for conflict detection |
| `is_deleted` | INTEGER | NOT NULL, DEFAULT 0 | Soft-delete flag (0/1) |
| `deleted_at` | INTEGER | NULLABLE | Unix epoch ms |

**FTS5 virtual table** `score_search (title, tags_flat)` — rebuilt on score create/update for real-time search (FR-007).

**Validation rules**:
- `title` must not be empty after trim
- `total_pages` ≥ 1
- `local_file_path` must point to an existing file (validated on import)

---

### `folders`

Hierarchical containers for scores. Supports arbitrary nesting (FR-004, FR-005).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PK | UUID v4 |
| `name` | TEXT | NOT NULL | Must be unique within `parent_folder_id` scope |
| `parent_folder_id` | TEXT | FK → `folders.id`, NULLABLE | NULL = top-level folder |
| `created_at` | INTEGER | NOT NULL | |
| `updated_at` | INTEGER | NOT NULL | |
| `sync_state` | TEXT | NOT NULL | Same enum as `scores.sync_state` |
| `cloud_id` | TEXT | NULLABLE | |
| `is_deleted` | INTEGER | NOT NULL, DEFAULT 0 | |
| `deleted_at` | INTEGER | NULLABLE | |

**Validation rules**:
- `name` must not be empty after trim
- Circular parent references are prohibited (enforced in service layer, not DB constraint)
- Max nesting depth: 10 levels (constant `kMaxFolderDepth`)

---

### `score_tags`

Many-to-many join between scores and free-text tags (FR-006).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `score_id` | TEXT | PK (composite), FK → `scores.id` | |
| `tag` | TEXT | PK (composite) | Lowercase-normalised on write |

**Note**: The `score_search` FTS5 table stores a flattened `tags_flat` column (space-separated) for multi-tag search queries.

---

### `set_lists`

Named, ordered collections of score references (FR-009).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PK | UUID v4 |
| `name` | TEXT | NOT NULL | |
| `created_at` | INTEGER | NOT NULL | |
| `updated_at` | INTEGER | NOT NULL | |
| `sync_state` | TEXT | NOT NULL | |
| `cloud_id` | TEXT | NULLABLE | |
| `is_deleted` | INTEGER | NOT NULL, DEFAULT 0 | |
| `deleted_at` | INTEGER | NULLABLE | |

---

### `set_list_entries`

Ordered entries within a set list (FR-010, FR-011).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PK | UUID v4 |
| `set_list_id` | TEXT | NOT NULL, FK → `set_lists.id` | Cascade delete |
| `score_id` | TEXT | NOT NULL, FK → `scores.id` | Score may be deleted (entry becomes orphaned — displayed as "Score not found") |
| `order_index` | INTEGER | NOT NULL | 0-based; unique within set list |
| `added_at` | INTEGER | NOT NULL | |

**Validation rules**:
- `order_index` must be unique within a `set_list_id` scope (enforced in service layer before write)
- Orphaned entries (score soft-deleted) are retained in the set list but rendered with a warning (FR-012 edge case)

---

### `annotation_layers`

Per-page ink annotation data for a score (FR-014–FR-019).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PK | UUID v4 |
| `score_id` | TEXT | NOT NULL, FK → `scores.id` | Cascade delete |
| `page_number` | INTEGER | NOT NULL | 1-based |
| `strokes_json` | TEXT | NOT NULL, DEFAULT '[]' | JSON array of `InkStroke` objects (see below) |
| `updated_at` | INTEGER | NOT NULL | |
| `sync_state` | TEXT | NOT NULL | |
| `server_version` | INTEGER | NULLABLE | |

**Composite unique index**: `(score_id, page_number)` — one layer per page per score.

**InkStroke JSON schema** (stored inside `strokes_json` array):

```json
{
  "id": "uuid",
  "tool": "pen | highlighter | eraser",
  "color": "#FF0000",
  "stroke_width": 2.5,
  "opacity": 1.0,
  "points": [
    { "x": 0.312, "y": 0.145, "pressure": 0.72 }
  ],
  "created_at": "2025-07-24T10:30:00Z"
}
```

- `x`, `y` are normalised to [0, 1] relative to page dimensions (scale-independent)
- `pressure` in [0, 1] (0.5 default when pressure unavailable)
- Erasure strokes have `tool: "eraser"` and are applied as clip regions during rendering

---

### `sync_queue`

Local operation log of pending changes to sync to the server (FR-023).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PK | UUID v4 |
| `entity_type` | TEXT | NOT NULL | Enum: `score \| folder \| set_list \| set_list_entry \| annotation_layer` |
| `entity_id` | TEXT | NOT NULL | UUID of the affected entity |
| `operation` | TEXT | NOT NULL | Enum: `create \| update \| delete` |
| `payload_json` | TEXT | NOT NULL | Full entity JSON snapshot at time of change |
| `status` | TEXT | NOT NULL | Enum: `pending \| in_flight \| synced \| conflict \| failed` |
| `created_at` | INTEGER | NOT NULL | |
| `attempt_count` | INTEGER | NOT NULL, DEFAULT 0 | |
| `last_attempt_at` | INTEGER | NULLABLE | |
| `error_message` | TEXT | NULLABLE | Last error from server |

**Deduplication rule**: If a newer `update` operation exists for the same `entity_id`, older `update` entries are collapsed into it before the push batch is sent. `delete` operations always take precedence over pending `create` or `update` for the same entity.

---

### `sync_meta`

Key-value store for sync state metadata.

| Column | Type | Notes |
|--------|------|-------|
| `key` | TEXT PK | e.g., `device_id`, `last_sync_at`, `server_timestamp`, `user_id` |
| `value` | TEXT | |

---

## Server Schema (EF Core / PostgreSQL)

### `users` (extends ASP.NET Core Identity `AspNetUsers`)

| Column | Type | Notes |
|--------|------|-------|
| `Id` | UUID PK | Identity field |
| `Email` | TEXT | Identity field; unique index |
| `DisplayName` | TEXT NULLABLE | |
| `StorageQuotaBytes` | BIGINT | Default: 10 GB |
| `UsedStorageBytes` | BIGINT | Updated on upload/delete |
| `CreatedAt` | TIMESTAMPTZ | |
| `LastSyncAt` | TIMESTAMPTZ NULLABLE | |

---

### `scores`

| Column | Type | Notes |
|--------|------|-------|
| `Id` | UUID PK | |
| `UserId` | UUID FK → `users.Id` | |
| `Title` | TEXT NOT NULL | |
| `Filename` | TEXT NOT NULL | |
| `BlobPath` | TEXT NOT NULL | Azure Blob container-relative path |
| `TotalPages` | INT NOT NULL | |
| `FolderId` | UUID FK → `folders.Id` NULLABLE | |
| `Version` | INT NOT NULL DEFAULT 1 | Incremented on every update; used for conflict detection |
| `IsDeleted` | BOOL NOT NULL DEFAULT FALSE | Soft delete |
| `DeletedAt` | TIMESTAMPTZ NULLABLE | |
| `CreatedAt` | TIMESTAMPTZ NOT NULL | |
| `UpdatedAt` | TIMESTAMPTZ NOT NULL | |

---

### `score_tags`

| Column | Type | Notes |
|--------|------|-------|
| `ScoreId` | UUID FK → `scores.Id` | Composite PK |
| `Tag` | TEXT NOT NULL | Lowercase-normalised; Composite PK |

---

### `folders`

| Column | Type | Notes |
|--------|------|-------|
| `Id` | UUID PK | |
| `UserId` | UUID FK → `users.Id` | |
| `Name` | TEXT NOT NULL | |
| `ParentFolderId` | UUID FK → `folders.Id` NULLABLE | |
| `Version` | INT NOT NULL DEFAULT 1 | |
| `IsDeleted` | BOOL NOT NULL DEFAULT FALSE | |
| `DeletedAt` | TIMESTAMPTZ NULLABLE | |
| `CreatedAt` | TIMESTAMPTZ NOT NULL | |
| `UpdatedAt` | TIMESTAMPTZ NOT NULL | |

---

### `set_lists`

| Column | Type | Notes |
|--------|------|-------|
| `Id` | UUID PK | |
| `UserId` | UUID FK → `users.Id` | |
| `Name` | TEXT NOT NULL | |
| `Version` | INT NOT NULL DEFAULT 1 | |
| `IsDeleted` | BOOL NOT NULL DEFAULT FALSE | |
| `DeletedAt` | TIMESTAMPTZ NULLABLE | |
| `CreatedAt` | TIMESTAMPTZ NOT NULL | |
| `UpdatedAt` | TIMESTAMPTZ NOT NULL | |

---

### `set_list_entries`

| Column | Type | Notes |
|--------|------|-------|
| `Id` | UUID PK | |
| `SetListId` | UUID FK → `set_lists.Id` | Cascade delete |
| `ScoreId` | UUID FK → `scores.Id` | |
| `OrderIndex` | INT NOT NULL | 0-based; unique within SetListId |

---

### `annotation_layers`

Annotation layers where `StrokesJson` is ≤64 KB are stored inline; larger layers are offloaded to Blob Storage.

| Column | Type | Notes |
|--------|------|-------|
| `Id` | UUID PK | |
| `ScoreId` | UUID FK → `scores.Id` | |
| `PageNumber` | INT NOT NULL | 1-based |
| `StrokesJson` | TEXT NULLABLE | Inline for ≤64 KB; NULL when offloaded |
| `BlobPath` | TEXT NULLABLE | Non-NULL when StrokesJson is offloaded |
| `Version` | INT NOT NULL DEFAULT 1 | |
| `UpdatedAt` | TIMESTAMPTZ NOT NULL | |

**Composite unique index**: `(ScoreId, PageNumber)`.

---

### `sync_log`

Audit trail for conflict detection. Retains the last 90 days of operations per user.

| Column | Type | Notes |
|--------|------|-------|
| `Id` | UUID PK | |
| `UserId` | UUID FK → `users.Id` | Indexed |
| `DeviceId` | TEXT NOT NULL | Client-generated device identifier |
| `EntityType` | TEXT NOT NULL | Enum: score, folder, set_list, set_list_entry, annotation_layer |
| `EntityId` | UUID NOT NULL | |
| `Operation` | TEXT NOT NULL | Enum: create, update, delete |
| `AppliedAt` | TIMESTAMPTZ NOT NULL | Server timestamp (authoritative) |
| `EntityVersion` | INT NOT NULL | Version of the entity after this operation |

---

## State Transitions

### `sync_state` (client-side)

```
[imported/created locally]
        │
        ▼
  pending_upload ──(sync push accepted)──► synced
        │                                      │
        │                          (local edit while synced)
        │                                      │
        │                                      ▼
        │                              pending_update ──(sync push accepted)──► synced
        │
        └──(conflict detected during push)──► conflict
                                                  │
                                    (user resolves in merge editor)
                                                  │
                                                  ▼
                                          pending_update ──► synced

[user deletes score]
        │
        ▼
  pending_delete ──(sync push accepted)──► (removed from local DB)
```

### Score life cycle (soft delete)

1. User deletes → `is_deleted = true`, `deleted_at = now`, `sync_state = pending_delete`
2. On sync push → server marks `IsDeleted = true`, retains for 90 days
3. After 90 days → server hard-deletes + blob purge via lifecycle policy

---

## Relationships Diagram

```
users
 └─< scores >─── score_tags
      │
      └─< annotation_layers

users
 └─< folders >─< folders (self-referential nesting)
      └─< scores (via folder_id)

users
 └─< set_lists >─< set_list_entries >── scores
```
