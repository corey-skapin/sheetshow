import '../../../core/models/enums.dart';

// T077: ConflictInfo — describes a sync conflict for the merge editor.

/// The type of conflict detected.
enum ConflictType {
  metadataModified,
  annotationModified,
  deleteVsUpdate,
  setListModified,
}

/// Information about a sync conflict needing user resolution.
class ConflictInfo {
  const ConflictInfo({
    required this.entityType,
    required this.entityId,
    required this.conflictType,
    required this.localPayload,
    required this.serverPayload,
    required this.serverVersion,
  });

  final SyncEntityType entityType;
  final String entityId;
  final ConflictType conflictType;
  final String localPayload;
  final String serverPayload;
  final int serverVersion;
}
