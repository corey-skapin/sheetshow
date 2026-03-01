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
    this.pageOffset = 0,
    this.needsReview = false,
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

  /// Denormalized page offset from the parent realbook.
  final int pageOffset;

  /// Whether this score needs manual review (title from OCR, not matched).
  final bool needsReview;

  /// Whether this score is a realbook excerpt.
  bool get isRealbookExcerpt => realbookId != null;

  /// The book page number (startPage minus the realbook's page offset).
  /// Returns null for standalone scores or if startPage is not set.
  int? get bookPage => startPage != null ? startPage! - pageOffset : null;

  /// The book end page number (endPage minus the realbook's page offset).
  int? get bookEndPage => endPage != null ? endPage! - pageOffset : null;

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
    int? pageOffset,
    bool? needsReview,
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
        pageOffset: pageOffset ?? this.pageOffset,
        needsReview: needsReview ?? this.needsReview,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
