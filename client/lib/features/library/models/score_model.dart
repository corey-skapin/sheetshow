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
    required this.updatedAt,
    this.effectiveTags = const [],
    this.realbookId,
    this.startPage,
    this.endPage,
    this.realbookTitle,
  });

  final String id;
  final String title;
  final String filename;
  final String localFilePath;
  final int totalPages;
  final String? thumbnailPath;
  final DateTime updatedAt;

  /// Own tags merged with tags inherited from all folders this score belongs to.
  final List<String> effectiveTags;

  /// If set, this score is an excerpt from a realbook.
  final String? realbookId;

  /// First page of this score in the realbook PDF (1-indexed).
  final int? startPage;

  /// Last page of this score in the realbook PDF (1-indexed).
  final int? endPage;

  /// Denormalized title of the parent realbook for display.
  final String? realbookTitle;

  /// Whether this score is a realbook excerpt.
  bool get isRealbookExcerpt => realbookId != null;

  ScoreModel copyWith({
    String? id,
    String? title,
    String? filename,
    String? localFilePath,
    int? totalPages,
    String? thumbnailPath,
    DateTime? updatedAt,
    List<String>? effectiveTags,
    String? realbookId,
    int? startPage,
    int? endPage,
    String? realbookTitle,
  }) =>
      ScoreModel(
        id: id ?? this.id,
        title: title ?? this.title,
        filename: filename ?? this.filename,
        localFilePath: localFilePath ?? this.localFilePath,
        totalPages: totalPages ?? this.totalPages,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        updatedAt: updatedAt ?? this.updatedAt,
        effectiveTags: effectiveTags ?? this.effectiveTags,
        realbookId: realbookId ?? this.realbookId,
        startPage: startPage ?? this.startPage,
        endPage: endPage ?? this.endPage,
        realbookTitle: realbookTitle ?? this.realbookTitle,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
