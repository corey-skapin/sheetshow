// T010: Shared application constants.
// All configurable values are defined here — no magic numbers in production logic.

/// Sync engine poll interval in seconds.
const int kSyncPollIntervalSec = 30;

/// Maximum exponential backoff cap for sync retries in seconds.
const int kSyncBackoffCapSec = 300;

/// Maximum folder nesting depth.
const int kMaxFolderDepth = 10;

/// Threshold above which annotation data is stored separately (65 KB).
const int kAnnotationSizeThresholdBytes = 65536;

/// Days after which soft-deleted records are eligible for hard deletion.
const int kTombstoneDays = 90;

/// Access token expiry in minutes.
const int kAccessTokenExpiryMin = 15;

/// Refresh token expiry in days.
const int kRefreshTokenExpiryDays = 90;

/// Debounce duration for FTS5 search queries in milliseconds.
const int kSearchDebounceMs = 200;

/// File size threshold above which a file is considered "large" (10 MB).
const int kLargeFileThresholdBytes = 10485760;

/// Minimum free space buffer required before importing a file (50 MB).
const int kMinFreeSpaceBufferBytes = 52428800;

/// Undo stack maximum size for annotation strokes.
const int kUndoStackMaxSize = 50;

/// Sync batch size — maximum operations per push or pull call.
const int kSyncMaxBatchSize = 100;

/// Maximum sync retry attempts before marking an operation as failed.
const int kSyncMaxRetries = 10;

/// Initial backoff delay for sync retries in seconds.
const int kSyncInitialBackoffSec = 5;

/// Pre-signed URL expiry for blob upload/download in minutes.
const int kBlobUrlExpiryMinutes = 15;
