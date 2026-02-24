import 'package:sheetshow/core/models/enums.dart';
import 'package:sheetshow/features/setlists/models/set_list_entry_model.dart';

// T057: SetListModel — ordered set list of scores.

/// An ordered, named set list of score entries.
class SetListModel {
  const SetListModel({
    required this.id,
    required this.name,
    required this.entries,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    this.cloudId,
    this.serverVersion = 0,
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final List<SetListEntryModel> entries;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final String? cloudId;
  final int serverVersion;
  final bool isDeleted;

  SetListModel copyWith({
    String? id,
    String? name,
    List<SetListEntryModel>? entries,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
    String? cloudId,
    int? serverVersion,
    bool? isDeleted,
  }) =>
      SetListModel(
        id: id ?? this.id,
        name: name ?? this.name,
        entries: entries ?? this.entries,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncState: syncState ?? this.syncState,
        cloudId: cloudId ?? this.cloudId,
        serverVersion: serverVersion ?? this.serverVersion,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'cloudId': cloudId,
        'serverVersion': serverVersion,
      };

  factory SetListModel.fromJson(Map<String, dynamic> json) => SetListModel(
        id: json['id'] as String,
        name: json['name'] as String,
        entries: (json['entries'] as List? ?? [])
            .map((e) => SetListEntryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        syncState: SyncState.synced,
        cloudId: json['cloudId'] as String?,
        serverVersion: json['serverVersion'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SetListModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
