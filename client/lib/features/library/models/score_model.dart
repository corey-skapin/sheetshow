// T034: ScoreModel — immutable Dart class mapping to the scores Drift table.

/// Immutable model representing a PDF sheet music score.
class ScoreModel {
  const ScoreModel({
    required this.id,
    required this.title,
    required this.filename,
    required this.localFilePath,
    required this.totalPages,
    this.thumbnailPath,
    this.folderId,
    required this.importedAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String filename;
  final String localFilePath;
  final int totalPages;
  final String? thumbnailPath;
  final String? folderId;
  final DateTime importedAt;
  final DateTime updatedAt;

  ScoreModel copyWith({
    String? id,
    String? title,
    String? filename,
    String? localFilePath,
    int? totalPages,
    String? thumbnailPath,
    String? folderId,
    DateTime? importedAt,
    DateTime? updatedAt,
  }) =>
      ScoreModel(
        id: id ?? this.id,
        title: title ?? this.title,
        filename: filename ?? this.filename,
        localFilePath: localFilePath ?? this.localFilePath,
        totalPages: totalPages ?? this.totalPages,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        folderId: folderId ?? this.folderId,
        importedAt: importedAt ?? this.importedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
