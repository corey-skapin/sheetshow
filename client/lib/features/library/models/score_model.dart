import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/models/enums.dart';

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
    required this.syncState,
    this.cloudId,
    this.serverVersion = 0,
    this.isDeleted = false,
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
  final SyncState syncState;
  final String? cloudId;
  final int serverVersion;
  final bool isDeleted;

  /// Create a copy with changed fields.
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
    SyncState? syncState,
    String? cloudId,
    int? serverVersion,
    bool? isDeleted,
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
        syncState: syncState ?? this.syncState,
        cloudId: cloudId ?? this.cloudId,
        serverVersion: serverVersion ?? this.serverVersion,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  /// Serialize to JSON for sync payloads.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filename': filename,
        'totalPages': totalPages,
        'folderId': folderId,
        'updatedAt': updatedAt.toIso8601String(),
        'cloudId': cloudId,
        'serverVersion': serverVersion,
      };

  /// Deserialize from sync API response JSON.
  factory ScoreModel.fromJson(Map<String, dynamic> json) => ScoreModel(
        id: json['id'] as String,
        title: json['title'] as String,
        filename: json['filename'] as String,
        localFilePath: '',
        totalPages: json['totalPages'] as int? ?? 0,
        folderId: json['folderId'] as String?,
        importedAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        syncState: SyncState.synced,
        cloudId: json['id'] as String?,
        serverVersion: json['version'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
