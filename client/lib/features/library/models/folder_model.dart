// T045: FolderModel — maps to the folders Drift table.

/// Immutable model representing a score library folder.
class FolderModel {
  const FolderModel({
    required this.id,
    required this.name,
    this.parentFolderId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentFolderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      FolderModel(
        id: id ?? this.id,
        name: name ?? this.name,
        parentFolderId: parentFolderId ?? this.parentFolderId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FolderModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
