// T010: Shared application constants.
// All configurable values are defined here — no magic numbers in production logic.

/// Maximum folder nesting depth.
const int kMaxFolderDepth = 10;

/// Threshold above which annotation data is stored separately (65 KB).
const int kAnnotationSizeThresholdBytes = 65536;

/// Debounce duration for FTS5 search queries in milliseconds.
const int kSearchDebounceMs = 200;

/// File size threshold above which a file is considered "large" (10 MB).
const int kLargeFileThresholdBytes = 10485760;

/// Minimum free space buffer required before importing a file (50 MB).
const int kMinFreeSpaceBufferBytes = 52428800;

/// Undo stack maximum size for annotation strokes.
const int kUndoStackMaxSize = 50;
