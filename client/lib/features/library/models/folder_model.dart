import 'package:sheetshow/core/models/enums.dart';

// T045: FolderModel — maps to the folders Drift table.

/// Immutable model representing a score library folder.
class FolderModel {
  const FolderModel({
    required this.id,
    required this.name,
    this.parentFolderId,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    this.cloudId,
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final String? cloudId;
  final bool isDeleted;

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentFolderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
    String? cloudId,
    bool? isDeleted,
  }) =>
      FolderModel(
        id: id ?? this.id,
        name: name ?? this.name,
        parentFolderId: parentFolderId ?? this.parentFolderId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncState: syncState ?? this.syncState,
        cloudId: cloudId ?? this.cloudId,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentFolderId': parentFolderId,
        'updatedAt': updatedAt.toIso8601String(),
        'cloudId': cloudId,
      };

  factory FolderModel.fromJson(Map<String, dynamic> json) => FolderModel(
        id: json['id'] as String,
        name: json['name'] as String,
        parentFolderId: json['parentFolderId'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        syncState: SyncState.synced,
        cloudId: json['id'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FolderModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
