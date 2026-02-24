# Sync Protocol: SheetShow

**Version**: v1  
**Date**: 2025-07-24  
**Mechanism**: REST polling (pull + push) with exponential backoff

---

## Overview

SheetShow uses a two-phase sync protocol on every sync cycle:

1. **Pull** — fetch all server changes since the last successful sync
2. **Push** — send all locally queued operations to the server
3. **Conflict resolution** — any conflicts returned during push are presented to the user in the merge editor

The client is offline-first: all user operations write to the local Drift/SQLite database immediately and are enqueued in `sync_queue`. Sync is opportunistic — it runs automatically when the device has network connectivity, but is never required for normal use.

---

## Sync Trigger Schedule

| Trigger | Behavior |
|---------|----------|
| App foreground (online) | Immediate sync |
| Periodic timer (online) | Every 30 seconds |
| Network reconnect event | Immediate sync after 2-second debounce |
| Manual pull-to-refresh | Immediate sync |
| Failure backoff | 5s → 10s → 20s → 40s → ... → cap 5 min |
| Offline (no network) | No sync; queue accumulates locally |

---

## Phase 1: Pull — `POST /api/v1/sync/pull`

The client sends its last known sync state; the server returns everything that changed since then.

### Request

```json
{
  "deviceId": "win-device-uuid",
  "since": "2025-07-23T18:00:00Z",
  "entityTypes": ["score", "folder", "set_list", "annotation_layer"]
}
```

`since` is the `serverTimestamp` returned by the last successful sync (stored in `sync_meta`). On first sync, send `null` to receive the full dataset.

### Response 200

```json
{
  "serverTimestamp": "2025-07-24T10:00:00Z",
  "hasMore": false,
  "changes": [
    {
      "entityType": "score",
      "entityId": "uuid",
      "operation": "update",
      "version": 4,
      "payload": { /* full score object */ },
      "changedAt": "2025-07-24T09:55:00Z"
    },
    {
      "entityType": "score",
      "entityId": "uuid-2",
      "operation": "delete",
      "version": 2,
      "payload": null,
      "changedAt": "2025-07-24T09:50:00Z"
    }
  ]
}
```

If `hasMore: true`, repeat the pull with `since` set to the last `changedAt` in the current batch (pagination).

### Client merge logic (pull)

For each incoming change:

| Server operation | Local state | Action |
|-----------------|-------------|--------|
| `create` | Not present | Insert entity |
| `create` | Present (synced) | Update if server version > local |
| `update` | `synced` | Update to server version |
| `update` | `pending_update` | **Conflict** — skip; will be resolved during push phase |
| `update` | `pending_delete` | Ignore (local delete wins; will push delete) |
| `delete` | Any non-pending | Mark `is_deleted`, remove from view |
| `delete` | `pending_update` | Present conflict: "This score was deleted on another device. Keep local changes or discard?" |

---

## Phase 2: Push — `POST /api/v1/sync/push`

The client sends its queue of pending operations. Operations are batched and ordered by `created_at`.

### Request

```json
{
  "deviceId": "win-device-uuid",
  "batchId": "uuid",
  "operations": [
    {
      "operationId": "op-uuid",
      "entityType": "score",
      "entityId": "uuid",
      "operation": "create",
      "clientVersion": 0,
      "payload": { /* full entity snapshot */ },
      "queuedAt": "2025-07-24T09:45:00Z"
    },
    {
      "operationId": "op-uuid-2",
      "entityType": "annotation_layer",
      "entityId": "uuid",
      "operation": "update",
      "clientVersion": 2,
      "payload": {
        "scoreId": "uuid",
        "pageNumber": 1,
        "strokesJson": "[...]"
      },
      "queuedAt": "2025-07-24T09:46:00Z"
    }
  ]
}
```

### Response 200

```json
{
  "batchId": "uuid",
  "serverTimestamp": "2025-07-24T10:00:05Z",
  "results": [
    {
      "operationId": "op-uuid",
      "entityId": "server-uuid",
      "status": "accepted",
      "serverVersion": 1
    },
    {
      "operationId": "op-uuid-2",
      "entityId": "uuid",
      "status": "conflict",
      "serverVersion": 4,
      "serverPayload": { /* server's current version */ },
      "conflictType": "annotation_modified"
    }
  ]
}
```

### Operation result statuses

| Status | Meaning | Client action |
|--------|---------|---------------|
| `accepted` | Applied to server | Mark queue entry `synced`; update `server_version` |
| `conflict` | Server version newer | Mark entity `conflict`; enqueue for merge editor |
| `not_found` | Entity doesn't exist on server (deleted by another device) | Prompt: "Keep local?" or discard |
| `quota_exceeded` | User storage quota full | Mark `failed`; notify user |
| `validation_error` | Server rejected payload | Mark `failed`; log error; do not retry automatically |

---

## Conflict Resolution Protocol

Conflicts are collected after each push cycle and presented to the user one at a time in the **Merge Editor** (FR-024).

### Conflict types

| Type | Description | Merge strategy |
|------|-------------|---------------|
| `metadata_modified` | Score title/folder/tags edited on two devices | Side-by-side field diff; user picks per-field |
| `annotation_modified` | Annotation layer edited on two devices | Stroke union preview; user picks Take Local / Take Server / Merge |
| `delete_vs_update` | Score deleted on device A; annotated on device B | User picks: Restore (keep local changes) or Confirm delete |
| `set_list_modified` | Set list order changed on two devices | Side-by-side order diff; drag to resolve |

### Annotation merge editor interaction

```
┌─────────────────────────────────────────────────────────────────┐
│  Conflict: "Clair de Lune" — Page 3 annotations               │
│  Local (modified 10:46am)    │   Cloud (modified 11:02am)      │
│  ┌──────────────────────┐   │   ┌──────────────────────┐      │
│  │  [PDF page preview   │   │   │  [PDF page preview   │      │
│  │   with local ink]    │   │   │   with cloud ink]    │      │
│  └──────────────────────┘   │   └──────────────────────┘      │
│                                                                 │
│  [Take Local]  [Merge Both ✓ Recommended]  [Take Cloud]        │
└─────────────────────────────────────────────────────────────────┘
```

**Merge Both** produces the union of all strokes from both versions. Duplicate strokes (same `id`) deduplicate automatically.

### Post-resolution

After the user resolves a conflict:
1. The resolved entity is written to local DB with `sync_state = pending_update`
2. The resolved version is pushed in the next sync cycle with `clientVersion = serverVersion` (signals intentional overwrite)
3. Server accepts the resolved version unconditionally when `clientVersion == serverVersion`

---

## Device Identity

Each installation generates a stable `deviceId` UUID (stored in `sync_meta`) on first launch. This ID is included in every push and pull request to:
- Allow the server to skip sending back the device's own changes during pull (using `sync_log.DeviceId` filtering)
- Enable per-device conflict attribution in the merge editor

---

## File Sync (PDF Blobs)

PDF files are synced separately from metadata:

1. **Upload** (client → cloud):
   - Request pre-signed upload URL: `POST /scores/{id}/upload-url`
   - Client streams PDF directly to Azure Blob Storage
   - On success, mark score `sync_state = synced`

2. **Download** (cloud → client):
   - Pull phase returns `score.version` change
   - Client requests download URL: `GET /scores/{id}/download-url`
   - Client streams PDF to local file system
   - Large files (>10 MB) download in background; UI shows sync-in-progress indicator

3. **Soft-delete**:
   - Server marks blob for deletion after 90-day tombstone period
   - Client removes local PDF file immediately on delete; blob removal is server-managed

---

## Sync Status Indicator (FR-022)

The client maintains a `SyncStatus` value observable by the UI:

| State | Display |
|-------|---------|
| `idle` | "Synced — [timestamp]" |
| `syncing` | Spinner + "Syncing…" |
| `conflict` | Warning badge + "N conflicts to resolve" |
| `offline` | Cloud icon with slash + "Offline — changes saved locally" |
| `error` | Error icon + "Sync failed — tap to retry" |

---

## Error Handling and Retry

| Error | Behaviour |
|-------|----------|
| Network timeout | Mark batch `pending`; retry with backoff |
| `500` server error | Mark batch `in_flight` → `pending`; retry with backoff |
| `401` auth error | Attempt token refresh; if refresh fails, pause sync and prompt re-login |
| `409` conflict | Mark affected entities `conflict`; continue processing rest of batch |
| `quota_exceeded` | Pause upload queue; notify user with storage usage details |
| Max retries exceeded (10) | Mark operation `failed`; surface in error log; user must manually retry |
