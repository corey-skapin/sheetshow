# Research: SheetShow Implementation Planning

**Phase**: Phase 0 — Research  
**Date**: 2025-07-24  
**Status**: Complete — all NEEDS CLARIFICATION resolved

---

## 1. Client Framework

**Decision**: Flutter 3.x (Dart 3.5)

**Rationale**: Flutter is the only tier-1 cross-platform framework that delivers a single Dart codebase targeting Windows, iOS, and Android with native (compiled) performance. It avoids the runtime overhead of Electron/Tauri (which use a web renderer) and surpasses .NET MAUI in iOS/Android maturity. React Native Windows (via `react-native-windows`) is community-maintained and lags significantly behind its iOS/Android counterpart. Flutter's `CustomPainter` API and `Listener` widget give direct access to pointer events (pressure, tilt) needed for annotation, and the Windows runner supports Win32 platform channels for Surface Pen integration.

**Alternatives considered**:
- **.NET MAUI**: Best Windows-native feel and Ink API integration, but iOS/Android support is less polished and the ecosystem is smaller. Would force a rewrite or heavy platform-specific code for future mobile ports.
- **React Native (+ react-native-windows)**: Mature iOS/Android story, but the Windows port is community-maintained and annotation/PDF performance is a concern.
- **Electron/Tauri**: Cross-platform via WebView. Electron is too heavy; Tauri has no stable mobile target yet. Neither gives the annotation performance needed (≤50ms ink latency).

---

## 2. PDF Rendering

**Decision**: `pdfrx` (v2.x, MIT license, PDFium-based)

**Rationale**: `pdfrx` is built on Google's PDFium engine — the same renderer used in Chrome — giving it battle-tested multi-page performance and cross-platform consistency. It provides lazy/virtual rendering suitable for 50+ page documents, built-in thumbnail generation, and is actively maintained (v2.2.15 as of research). Its MIT license avoids the paid licensing required by Syncfusion. It supports Windows, macOS, Linux, iOS, and Android from a single API surface.

**Alternatives considered**:
- **syncfusion_flutter_pdfviewer**: Feature-rich but requires a paid licence for commercial use. Proprietary rendering engine vs PDFium.
- **pdfx**: PDFium-based (good) but less actively maintained and lacks built-in thumbnail generation.
- **flutter_pdfview**: WebView-based on Windows, causing layout and performance issues with multi-page documents.

---

## 3. Surface Pen Annotation Architecture

**Decision**: Win32 Windows Ink API via Flutter platform channel (C++) + Flutter `CustomPainter` for rendering

**Rationale**: Flutter's built-in pointer events (`Listener` widget, `PointerEvent`) do not expose stylus pressure or tilt on Windows — Flutter issue #65248 has been open since 2020 with P3 priority. True Surface Pen fidelity (pressure-sensitive strokes, tilt-angle shading, palm rejection) requires hooking Win32 `WM_POINTER` messages and calling `IInkPresenter` / `GetPointerPenInfo`. A `MethodChannel` plugin in C++ bridges native pointer data to Dart, where `CustomPainter` renders ink strokes over the `pdfrx` viewer. This is a one-time investment: iOS and Android have native Flutter stylus pressure support via `PointerEvent.pressure` without a platform channel.

**Key implementation detail**: Palm rejection is achieved by filtering `WM_POINTER` events where `pointerType == PT_TOUCH` while pen is in proximity (detected by `GetPointerType`).

**Alternatives considered**:
- **Pure Dart `Listener` + CustomPainter**: Fast to implement but cannot access pressure/tilt on Windows, violating SC-006 (≤50ms ink) and the annotation quality requirement.
- **flutter_drawing_board**: Open-source drawing library, but does not solve the Windows pressure/tilt gap.
- **Embed WinUI InkCanvas as platform view**: More integrated but Flutter's Windows platform view support is still maturing; adds a heavy WinUI dependency.

---

## 4. Local Storage

**Decision**: Drift 2.x (type-safe SQLite ORM for Flutter) with FTS5 virtual table for search

**Rationale**: Drift provides compile-time type-safe SQL queries over SQLite, reactive streams for live UI updates, built-in migration support, and native FTS5 integration for real-time title+tag search across 500 scores. SQLite in WAL mode satisfies SC-008 (no data loss on crash). Drift works identically on Windows, iOS, and Android with the same Dart code. The annotation layer (ink strokes) is stored as a JSON blob per page within the `annotation_layers` table — this avoids over-normalization of variable-length point arrays while keeping retrieval in a single query.

**Alternatives considered**:
- **Isar**: Excellent mobile performance, but Windows support lags Drift; no built-in FTS5.
- **ObjectBox**: Strong performance, but no FTS support (a disqualifier given FR-007 real-time search).
- **sqflite**: Mature but no code generation, no type safety, no built-in FTS — produces manual SQL maintenance burden at scale.
- **Hive**: Simple key-value; insufficient for relational queries (folders, set list ordering, tag filtering).

---

## 5. Backend Framework

**Decision**: .NET 8 ASP.NET Core Web API with Clean Architecture (Core / Infrastructure / Api layers)

**Rationale**: ASP.NET Core is a natural fit for Azure-first deployment while remaining fully portable (runs in Docker containers deployable anywhere). Clean Architecture enforces dependency inversion at the infrastructure boundary — storage, email, and secrets adapters are behind interfaces and never referenced by domain logic. C# 12 + EF Core 8 give strong type safety and excellent PostgreSQL support via Npgsql.

**Alternatives considered**:
- **Node.js / NestJS**: Strong ecosystem but less type safety for complex sync logic; TypeScript inference gaps at runtime.
- **Python / FastAPI**: Excellent for ML workloads but less suited to stateful sync engine and long-running connection management.
- **Go**: Great performance but smaller ORM ecosystem; EF Core's migration tooling is a productivity win for this project.

---

## 6. Authentication

**Decision**: ASP.NET Core Identity + JWT access tokens + refresh token rotation (stored in `flutter_secure_storage`)

**Rationale**: ASP.NET Core Identity is fully cloud-agnostic (no vendor SDK), provides email/password auth, email confirmation, and password reset out of the box. JWT access tokens (15-minute expiry) + long-lived refresh tokens (90 days, rotated on use) keep sessions alive across app restarts (FR-028) without requiring re-login. Refresh tokens are stored in the OS keychain via `flutter_secure_storage` (Windows Credential Manager / iOS Keychain / Android Keystore). Password reset uses a transactional email service abstracted behind `IEmailService`.

**Alternatives considered**:
- **Azure AD B2C**: Azure-specific; violates cloud-agnosticism requirement. Adds per-MAU costs at scale.
- **Auth0**: Cloud-agnostic SaaS identity, but adds a third-party dependency and per-MAU costs. Overkill for single-user-per-account scenario with simple email/password flows.
- **Keycloak**: Self-hosted, fully portable — viable, but adds operational complexity (another service to run/maintain) for a feature set covered by ASP.NET Core Identity.

---

## 7. Cloud Database

**Decision**: PostgreSQL 16 (Azure Database for PostgreSQL Flexible Server) via EF Core 8 + Npgsql

**Rationale**: PostgreSQL is the most portable relational database — available on Azure, AWS RDS, GCP Cloud SQL, and as self-hosted Docker. EF Core migrations abstract the schema from any provider-specific dialect. Flexible Server on Azure is cost-effective for the expected load (single-user accounts, ~500 scores per user at launch). Full-text search capabilities in PostgreSQL provide a backend analogue to the client's FTS5 search.

**Alternatives considered**:
- **Azure Cosmos DB**: Azure-exclusive; document model is poorly suited to relational sync metadata (set list ordering, folder trees). No EF Core migrations support.
- **Azure SQL / SQL Server**: Portable but requires SQL Server licence; PostgreSQL has better cost profile and community tooling.
- **SQLite (server-side)**: Insufficient for multi-user concurrent writes; not a managed cloud database.

---

## 8. Cloud File Storage Architecture

**Decision**: `IFileStorageService` interface with `AzureBlobStorageService` as initial implementation; future `S3StorageAdapter` / `GcsStorageAdapter` via DI swap

**Rationale**: The Repository Pattern at the infrastructure boundary means the domain and API layers never reference Azure SDK types directly. Swapping to a different cloud provider requires only registering a different `IFileStorageService` implementation — no core logic changes. Azure Blob Storage provides hot-tier access for frequently-viewed PDFs, SAS token generation for direct client downloads, and lifecycle management for soft-deleted blobs.

**File upload flow**: Client uploads PDF → server generates a pre-signed upload URL → client streams directly to Blob Storage → server records blob path in PostgreSQL. This avoids routing large PDFs through the API server.

**Alternatives considered**:
- **Direct Azure SDK use throughout**: Simple initially but creates deep vendor coupling; ruled out by cloud-agnosticism requirement.
- **Server-side proxy for all file I/O**: Simpler auth but adds unnecessary bandwidth cost routing large PDFs through the API server.

---

## 9. Deployment Architecture

**Decision**: Azure Container Apps (backend API) + Azure Container Registry + Azure Database for PostgreSQL Flexible Server + Azure Blob Storage + Azure Key Vault

**Rationale**: Container Apps is the managed, serverless container platform that handles auto-scaling, ingress, TLS, and health probes without the operational overhead of AKS. Docker images make the backend portable to AWS ECS, GCP Cloud Run, or any Kubernetes cluster. Key Vault secrets are injected as environment variables at container startup, abstracted via `ISecretsManager` so the same code works with AWS Secrets Manager or GCP Secret Manager by swapping the implementation.

**Cost estimate (initial scale)**: Container Apps consumption plan ~$20-50/mo; PostgreSQL Flexible Server (B2ms) ~$30/mo; Blob Storage ~$5-10/mo at 50GB. Total: ~$55-90/mo.

**Alternatives considered**:
- **Azure App Service**: Simpler but not as portable as Docker containers; no consumption-based scaling.
- **AKS**: Kubernetes-portable but $300+/mo minimum and high ops burden for a solo/small-team project.
- **Azure Functions**: Serverless but cold-start latency is incompatible with sync polling SLA (<30s).

---

## 10. Sync Strategy

**Decision**: Hybrid event log (for metadata) + timestamp-based conflict detection (for annotation layers), REST polling with exponential backoff

**Rationale**: REST polling is simpler than WebSocket/SignalR, more resilient to intermittent connectivity, and sufficient for a single-user scenario where <30s sync lag is acceptable (SC-005). The sync queue is a local SQLite table of pending `create/update/delete` operations per entity. On reconnect, the client POSTs a batch to `/api/sync/push` and receives back any conflicts (entities where the server's `updatedAt` is newer than the client's `knownServerTimestamp`). Soft-delete tombstones with a 90-day retention window satisfy the spec's recovery requirement.

**CRDT evaluation**: CRDTs are practical for metadata (tag sets, set list ordering — additive structures), but impractical for ink annotation layers. Annotation conflicts (same page annotated on two offline devices) are rare; when they occur, a merge editor showing a stroke union is more appropriate than automatic CRDT merging that could produce visually incoherent results.

**Polling schedule**: On app foreground, sync immediately. Then poll every 30 seconds while connected. On failure, exponential backoff: 5s → 10s → 20s → ... → 5-minute cap. 

**Alternatives considered**:
- **Pure event sourcing**: 3-5× storage overhead per annotation stroke; excessive replay complexity on conflict resolution.
- **WebSocket / SignalR**: Real-time but adds persistent connection management; no benefit for single-user scenario with 30s lag tolerance.
- **CRDTs throughout**: Practical for tags/set-list ordering but not for annotation layers; adds library dependency (Yjs/Automerge) with non-trivial Dart binding complexity.

---

## 11. Annotation Conflict Resolution

**Decision**: Merge editor presenting local and cloud annotation layers side-by-side, offering: Take Local, Take Server, or Merge (union of both stroke sets)

**Rationale**: The spec (FR-024, edge cases) explicitly requires a merge editor. The "Merge" option is implementable for annotations because ink strokes are append-only immutable objects — combining both sets produces a visually coherent result (all marks from both sessions appear). The common ancestor (last synced version) allows three-way diff: "strokes added since last sync on device A" and "strokes added since last sync on device B" can be unioned. ForScore only offers binary "Use Local / Use iCloud" — our merge is a UX improvement.

**Alternatives considered**:
- **Automatic CRDT merge**: Technically possible but could produce visually incoherent results for erasure operations (an erase on device A should suppress a stroke on device B — hard to represent in a CRDT).
- **Last-write-wins automatic**: Silently discards one user's annotations — unacceptable data loss.

---

## 12. Annotation Data Format

**Decision**: SVG path data encoded as JSON array of stroke objects, stored as a text blob per annotation layer (one layer = one page of one score)

**Rationale**: SVG paths are compact (a typical fingering annotation = 200-500 bytes), human-readable for debugging, and natively renderable via Flutter's `Path` API in `CustomPainter`. Each stroke object carries: `id`, `tool` (pen/highlighter/eraser), `color`, `strokeWidth`, `opacity`, `points[]` (normalised 0–1 coordinates relative to page dimensions), `createdAt`. Normalised coordinates mean annotations scale correctly when the PDF page is rendered at different zoom levels or on different screen sizes. For annotation layers >100KB, the server stores the blob in Azure Blob Storage rather than the PostgreSQL row.

**Alternatives considered**:
- **Binary format (e.g., Protocol Buffers)**: More compact but loses human-readability; Dart protobuf support adds build complexity.
- **Normalised points table**: A SQL row per stroke point causes millions of rows for a heavily annotated score; single-query retrieval is lost.
- **XAML InkStroke format**: Windows-only; not portable to iOS/Android.
