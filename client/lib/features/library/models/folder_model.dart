// T045: FolderModel — maps to the folders Drift table.

/// Immutable model representing a score library folder.
class FolderModel {
  const FolderModel({
    required this.id,
    required this.name,
    this.parentFolderId,
    required this.createdAt,
    required this.updatedAt,
    this.diskPath,
  });

  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Absolute path of the corresponding directory on disk, or `null` if this
  /// folder was created entirely within the app.
  final String? diskPath;

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentFolderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? diskPath,
  }) =>
      FolderModel(
        id: id ?? this.id,
        name: name ?? this.name,
        parentFolderId: parentFolderId ?? this.parentFolderId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        diskPath: diskPath ?? this.diskPath,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FolderModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
