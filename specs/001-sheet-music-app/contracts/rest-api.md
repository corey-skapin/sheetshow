# REST API Contract: SheetShow Cloud Backend

**Version**: v1  
**Base URL**: `https://api.sheetshow.app/api/v1`  
**Auth**: Bearer JWT (access token). Refresh via `/auth/refresh`.  
**Content-Type**: `application/json` unless noted.

---

## Authentication

### `POST /auth/register`

Create a new user account.

**Request**:
```json
{
  "email": "musician@example.com",
  "password": "••••••••",
  "displayName": "Jane Smith"
}
```

**Response 201**:
```json
{
  "userId": "uuid",
  "email": "musician@example.com",
  "accessToken": "eyJ...",
  "refreshToken": "opaque-token",
  "expiresAt": "2025-07-24T10:15:00Z"
}
```

**Errors**: `400` validation failure; `409` email already registered.

---

### `POST /auth/login`

Authenticate with email and password.

**Request**:
```json
{ "email": "musician@example.com", "password": "••••••••" }
```

**Response 200**: Same shape as `/auth/register` 201.

**Errors**: `400` validation; `401` invalid credentials.

---

### `POST /auth/refresh`

Exchange a refresh token for a new access token.

**Request**:
```json
{ "refreshToken": "opaque-token" }
```

**Response 200**:
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "new-opaque-token",
  "expiresAt": "2025-07-24T10:30:00Z"
}
```

**Errors**: `401` invalid or expired refresh token.

---

### `POST /auth/logout`

Revoke the current refresh token. 🔒 Authenticated.

**Request**: Empty body.

**Response 204**: No content.

---

### `POST /auth/forgot-password`

Initiate password reset. Sends email with reset link.

**Request**:
```json
{ "email": "musician@example.com" }
```

**Response 202**: Always returns 202 (avoids user enumeration).

---

### `POST /auth/reset-password`

Complete password reset using token from email link.

**Request**:
```json
{
  "email": "musician@example.com",
  "token": "reset-token-from-email",
  "newPassword": "••••••••"
}
```

**Response 200**: `{ "message": "Password reset successfully." }`

**Errors**: `400` token invalid or expired.

---

## Scores

### `GET /scores` 🔒

List all non-deleted scores for the authenticated user.

**Query params**: `?folderId=uuid` (filter by folder); `?since=ISO8601` (for incremental sync).

**Response 200**:
```json
{
  "scores": [
    {
      "id": "uuid",
      "title": "Clair de Lune",
      "filename": "clair-de-lune.pdf",
      "totalPages": 12,
      "folderId": "uuid-or-null",
      "tags": ["classical", "key:Db", "difficulty:advanced"],
      "version": 3,
      "createdAt": "2025-07-20T08:00:00Z",
      "updatedAt": "2025-07-22T14:30:00Z"
    }
  ],
  "total": 1
}
```

---

### `POST /scores` 🔒

Create a new score metadata record. File upload is separate (see `/scores/{id}/upload-url`).

**Request**:
```json
{
  "clientId": "client-generated-uuid",
  "title": "Clair de Lune",
  "filename": "clair-de-lune.pdf",
  "totalPages": 12,
  "folderId": "uuid-or-null",
  "tags": ["classical", "key:Db"],
  "importedAt": "2025-07-24T08:00:00Z"
}
```

**Response 201**:
```json
{
  "id": "server-uuid",
  "clientId": "client-generated-uuid",
  "version": 1,
  "createdAt": "2025-07-24T08:00:00Z"
}
```

**Errors**: `400` validation; `409` `clientId` already exists.

---

### `GET /scores/{id}` 🔒

Get a single score by server ID.

**Response 200**: Single score object (same shape as array item above, plus `blobDownloadUrl` with 15-minute SAS expiry).

**Errors**: `404` not found or not owned by user.

---

### `PUT /scores/{id}` 🔒

Update score metadata (title, folder, tags).

**Request**:
```json
{
  "title": "Clair de Lune — Debussy",
  "folderId": "uuid-or-null",
  "tags": ["classical", "key:Db", "difficulty:advanced"],
  "clientVersion": 3
}
```

`clientVersion` is used for optimistic concurrency — if the server version differs, a `409` conflict is returned.

**Response 200**: Updated score object with new `version`.

**Errors**: `404` not found; `409` version conflict (returns `serverVersion` and `serverUpdatedAt`).

---

### `DELETE /scores/{id}` 🔒

Soft-delete a score. Blob retained for 90 days.

**Response 204**: No content.

---

### `POST /scores/{id}/upload-url` 🔒

Generate a pre-signed Azure Blob Storage URL for direct PDF upload from the client.

**Request**:
```json
{ "contentLength": 2097152, "contentType": "application/pdf" }
```

**Response 200**:
```json
{
  "uploadUrl": "https://sheetshow.blob.core.windows.net/scores/...?sas=...",
  "expiresAt": "2025-07-24T08:15:00Z"
}
```

---

### `GET /scores/{id}/download-url` 🔒

Generate a pre-signed URL for direct PDF download.

**Response 200**:
```json
{
  "downloadUrl": "https://sheetshow.blob.core.windows.net/scores/...?sas=...",
  "expiresAt": "2025-07-24T08:15:00Z"
}
```

---

## Folders

### `GET /folders` 🔒

List all folders for the authenticated user.

**Response 200**:
```json
{
  "folders": [
    {
      "id": "uuid",
      "name": "Jazz Standards",
      "parentFolderId": null,
      "version": 1,
      "createdAt": "...",
      "updatedAt": "..."
    }
  ]
}
```

---

### `POST /folders` 🔒

Create a new folder.

**Request**:
```json
{ "clientId": "uuid", "name": "Jazz Standards", "parentFolderId": null }
```

**Response 201**: Created folder with `id`, `version`, `createdAt`.

---

### `PUT /folders/{id}` 🔒

Rename a folder or move it to a new parent.

**Request**:
```json
{ "name": "Jazz", "parentFolderId": "uuid-or-null", "clientVersion": 1 }
```

**Response 200**: Updated folder. **Errors**: `409` version conflict.

---

### `DELETE /folders/{id}` 🔒

Soft-delete a folder. Scores inside are moved to root (not deleted).

**Response 204**.

---

## Set Lists

### `GET /setlists` 🔒

List all set lists.

**Response 200**:
```json
{
  "setLists": [
    {
      "id": "uuid",
      "name": "Friday Night Gig",
      "entries": [
        { "id": "uuid", "scoreId": "uuid", "orderIndex": 0 }
      ],
      "version": 2,
      "createdAt": "...",
      "updatedAt": "..."
    }
  ]
}
```

---

### `POST /setlists` 🔒

Create a set list.

**Request**:
```json
{
  "clientId": "uuid",
  "name": "Friday Night Gig",
  "entries": [
    { "id": "uuid", "scoreId": "uuid", "orderIndex": 0 }
  ]
}
```

**Response 201**: Created set list with server `id` and `version`.

---

### `PUT /setlists/{id}` 🔒

Update a set list name and/or entries (full replacement of entries array).

**Request**:
```json
{
  "name": "Friday Night Gig — Updated",
  "entries": [ ... ],
  "clientVersion": 2
}
```

**Response 200**: Updated set list. **Errors**: `409` conflict.

---

### `DELETE /setlists/{id}` 🔒

Soft-delete a set list. Does not affect the referenced scores.

**Response 204**.

---

## Annotations

### `PUT /scores/{scoreId}/annotations/{pageNumber}` 🔒

Create or replace the annotation layer for a specific page.

**Request**:
```json
{
  "strokesJson": "[{ \"id\": \"uuid\", \"tool\": \"pen\", ... }]",
  "clientVersion": 0
}
```

`clientVersion: 0` on first create; otherwise the client's last known server version.

**Response 200**:
```json
{ "version": 1, "updatedAt": "2025-07-24T10:30:00Z" }
```

**Errors**: `409` conflict — returns `serverVersion`, `serverUpdatedAt`, and `serverStrokesJson` for use in the merge editor.

---

### `GET /scores/{scoreId}/annotations` 🔒

Get all annotation layers for a score.

**Response 200**:
```json
{
  "layers": [
    {
      "pageNumber": 1,
      "strokesJson": "[...]",
      "version": 3,
      "updatedAt": "..."
    }
  ]
}
```

---

## Error Schema

All error responses follow this shape:

```json
{
  "type": "https://sheetshow.app/errors/validation-failed",
  "title": "Validation Failed",
  "status": 400,
  "detail": "The field 'title' must not be empty.",
  "traceId": "00-abc123-def456-00"
}
```

| Status | Meaning |
|--------|---------|
| `400` | Validation failure; see `detail` |
| `401` | Unauthenticated — refresh or re-login |
| `403` | Authenticated but not authorised for this resource |
| `404` | Resource not found or soft-deleted |
| `409` | Optimistic concurrency conflict; see `serverVersion` field |
| `413` | File too large or storage quota exceeded |
| `429` | Rate limited; see `Retry-After` header |
| `500` | Internal server error; safe to retry with backoff |

---

## Rate Limits

| Endpoint group | Limit |
|----------------|-------|
| Auth endpoints | 10 req/min per IP |
| Upload URL generation | 30 req/min per user |
| All other authenticated endpoints | 300 req/min per user |
