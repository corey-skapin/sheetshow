# Quickstart: SheetShow Developer Setup

**Date**: 2025-07-24  
**Audience**: Developers setting up the SheetShow project for the first time.

---

## Prerequisites

### All platforms

| Tool | Version | Install |
|------|---------|---------|
| Git | Latest | https://git-scm.com |
| Docker Desktop | Latest | https://www.docker.com/products/docker-desktop |
| VS Code or JetBrains Rider | Latest | (editor preference) |

### Client (Flutter)

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | 3.24+ | https://docs.flutter.dev/get-started/install/windows/desktop |
| Dart SDK | 3.5+ | Bundled with Flutter |
| Visual Studio 2022 | Community+ | Required for Flutter Windows runner build (C++ workload) |
| Windows 10 SDK | 10.0.19041+ | Via Visual Studio Installer |

Verify Flutter setup:
```powershell
flutter doctor
# All checkmarks for Windows development required
```

### Server (.NET)

| Tool | Version | Install |
|------|---------|---------|
| .NET SDK | 8.0+ | https://dotnet.microsoft.com/download/dotnet/8 |
| PostgreSQL | 16 (local dev) | Via Docker (see below) |

---

## Repository Structure

```
sheetshow/
├── client/          # Flutter desktop app
├── server/          # .NET 8 Web API
└── specs/           # Design artifacts (this directory)
```

---

## 1. Server Setup

### Start local dependencies

```powershell
# From repo root — starts PostgreSQL + Azure Storage emulator (Azurite)
docker compose up -d
```

The `docker-compose.yml` in `server/` starts:
- **PostgreSQL 16** on `localhost:5432` (user: `sheetshow`, password: `sheetshow_dev`, db: `sheetshow`)
- **Azurite** (Azure Blob Storage emulator) on `localhost:10000`

### Configure secrets (local dev)

```powershell
cd server
dotnet user-secrets set "Jwt:SecretKey" "your-256-bit-local-dev-key-here" --project src/SheetShow.Api
dotnet user-secrets set "Email:SmtpPassword" "unused-for-local-dev" --project src/SheetShow.Api
```

`appsettings.Development.json` handles all other local configuration (connection strings, Azurite endpoint).

### Apply database migrations

```powershell
cd server/src/SheetShow.Api
dotnet ef database update
```

### Run the API

```powershell
cd server
dotnet run --project src/SheetShow.Api
# API available at: https://localhost:7001
# Swagger UI: https://localhost:7001/swagger
```

### Run server tests

```powershell
cd server
dotnet test --collect:"XPlat Code Coverage"
# Coverage report generated in tests/*/TestResults/
```

---

## 2. Client Setup

### Install Flutter dependencies

```powershell
cd client
flutter pub get
```

### Configure local API endpoint

Copy the example config file:
```powershell
cp client/lib/core/constants/api_config.example.dart \
   client/lib/core/constants/api_config.dart
```

Edit `api_config.dart` to point to your local server:
```dart
const String kApiBaseUrl = 'https://localhost:7001/api/v1';
```

> **Note**: On Windows, the Flutter app trusts the dev certificate automatically via `localhost`. If you encounter SSL errors, run `dotnet dev-certs https --trust`.

### Run the app (Windows desktop)

```powershell
cd client
flutter run -d windows
```

### Run client tests

```powershell
cd client
flutter test --coverage
# Coverage report: coverage/lcov.info
# Open with: genhtml coverage/lcov.info -o coverage/html && start coverage/html/index.html
```

### Run integration tests

```powershell
cd client
flutter test integration_test/
```

---

## 3. Linting & Formatting

### Client

```powershell
cd client
flutter analyze          # Run linter (zero warnings policy)
dart format --set-exit-if-changed lib/ test/   # Check formatting
dart format lib/ test/   # Auto-format
```

### Server

```powershell
cd server
dotnet format --verify-no-changes   # Check formatting
dotnet format                        # Auto-format
```

---

## 4. CI Pipeline Overview

| Pipeline | File | Trigger |
|----------|------|---------|
| Client CI | `.github/workflows/client-ci.yml` | Push / PR to any branch |
| Server CI | `.github/workflows/server-ci.yml` | Push / PR to any branch |

**Client CI steps**: `flutter analyze` → `flutter test --coverage` → `lcov` coverage gate → `flutter build windows`  
**Server CI steps**: `dotnet format --verify-no-changes` → `dotnet test` → coverage gate → `docker build`

---

## 5. Azure Deployment (Production)

### Prerequisites

- Azure CLI installed and logged in (`az login`)
- Access to the `sheetshow-prod` Azure subscription

### One-time resource provisioning

```powershell
cd server/infra   # Bicep/ARM templates
az deployment group create \
  --resource-group sheetshow-prod-rg \
  --template-file main.bicep \
  --parameters environment=prod
```

This provisions:
- Azure Container Registry
- Azure Container Apps environment
- Azure Database for PostgreSQL Flexible Server
- Azure Blob Storage account
- Azure Key Vault

### Deploy a new server image

```powershell
cd server
docker build -t sheetshow-api:latest .
az acr build --registry sheetshowacrprod --image sheetshow-api:latest .
az containerapp update --name sheetshow-api --resource-group sheetshow-prod-rg \
  --image sheetshowacrprod.azurecr.io/sheetshow-api:latest
```

### Build the Windows installer

```powershell
cd client
flutter build windows --release
# Output: client/build/windows/x64/runner/Release/
# Package with MSIX: flutter pub run msix:create
```

---

## 6. Useful Commands Reference

| Task | Command |
|------|---------|
| Run everything locally | `docker compose up -d && dotnet run (server) && flutter run -d windows (client)` |
| Reset local database | `dotnet ef database drop && dotnet ef database update` |
| Generate Drift schema | `dart run build_runner build --delete-conflicting-outputs` (in `client/`) |
| Generate EF migration | `dotnet ef migrations add <Name> --project src/SheetShow.Infrastructure` |
| View API docs | Open `https://localhost:7001/swagger` |
| Check storage quota (dev) | `az storage blob list --account-name devstoreaccount1 --container-name scores --connection-string "UseDevelopmentStorage=true"` |

---

## 7. Troubleshooting

**Flutter Windows build fails with "missing Windows SDK"**  
→ Open Visual Studio Installer → Modify → ensure "Desktop development with C++" workload is installed.

**`flutter doctor` shows Cocoapods warning on Windows**  
→ Ignore — Cocoapods is only needed for iOS builds.

**PostgreSQL connection refused**  
→ Ensure Docker Desktop is running: `docker compose ps` should show `sheetshow-db` as `Up`.

**Azure Blob Storage 404 in dev**  
→ Azurite may need container creation: `az storage container create --name scores --connection-string "UseDevelopmentStorage=true"`.

**`flutter analyze` reports warnings as errors**  
→ This is intentional (zero-warnings policy). Fix all warnings before committing.
