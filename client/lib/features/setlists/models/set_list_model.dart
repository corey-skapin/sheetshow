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
  });

  final String id;
  final String name;
  final List<SetListEntryModel> entries;
  final DateTime createdAt;
  final DateTime updatedAt;

  SetListModel copyWith({
    String? id,
    String? name,
    List<SetListEntryModel>? entries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      SetListModel(
        id: id ?? this.id,
        name: name ?? this.name,
        entries: entries ?? this.entries,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SetListModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
