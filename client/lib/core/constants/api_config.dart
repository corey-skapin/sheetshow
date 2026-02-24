// T011: API configuration.
// The base URL is provided via --dart-define=API_BASE_URL=... at build time.
// Falls back to localhost for local development.

/// Base URL for the SheetShow REST API.
/// Override at build time: flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://localhost:7001/api/v1',
);
