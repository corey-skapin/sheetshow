// T014: Shared enums used across all features.

/// Sync state for a locally-owned entity.
enum SyncState {
  /// Entity is in sync with the cloud.
  synced,

  /// Entity has been created locally and needs to be uploaded.
  pendingUpload,

  /// Entity has been modified locally and needs to be pushed.
  pendingUpdate,

  /// Entity has been soft-deleted locally and the deletion needs to be pushed.
  pendingDelete,

  /// Entity has a version conflict with the server — user must resolve.
  conflict,
}

/// Annotation tool selection.
enum AnnotationTool {
  /// Fine ink pen (black, 2.5 px, opacity 1.0).
  pen,

  /// Broad highlighter (yellow, 12 px, opacity 0.4).
  highlighter,

  /// Eraser tool (uses BlendMode.clear).
  eraser,
}

/// Type of sync operation in the sync queue.
enum SyncOperationType {
  /// Create a new entity on the server.
  create,

  /// Update an existing entity on the server.
  update,

  /// Soft-delete an entity on the server.
  delete,
}

/// Entity type discriminator for the sync queue.
enum SyncEntityType {
  score,
  folder,
  setList,
  setListEntry,
  annotationLayer,
}
