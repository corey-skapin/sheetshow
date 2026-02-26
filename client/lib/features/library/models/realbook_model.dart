/// Immutable model representing a realbook — a large PDF containing many scores.
class RealbookModel {
  const RealbookModel({
    required this.id,
    required this.title,
    required this.filename,
    required this.localFilePath,
    required this.totalPages,
    required this.updatedAt,
    this.scoreCount = 0,
  });

  final String id;
  final String title;
  final String filename;
  final String localFilePath;
  final int totalPages;
  final DateTime updatedAt;

  /// Number of indexed scores within this realbook (denormalized for display).
  final int scoreCount;

  RealbookModel copyWith({
    String? id,
    String? title,
    String? filename,
    String? localFilePath,
    int? totalPages,
    DateTime? updatedAt,
    int? scoreCount,
  }) =>
      RealbookModel(
        id: id ?? this.id,
        title: title ?? this.title,
        filename: filename ?? this.filename,
        localFilePath: localFilePath ?? this.localFilePath,
        totalPages: totalPages ?? this.totalPages,
        updatedAt: updatedAt ?? this.updatedAt,
        scoreCount: scoreCount ?? this.scoreCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealbookModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
