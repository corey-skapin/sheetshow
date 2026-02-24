// T058: SetListEntryModel — a single ordered score entry in a set list.

/// An entry in a set list, referencing a score at a specific position.
class SetListEntryModel {
  const SetListEntryModel({
    required this.id,
    required this.setListId,
    required this.scoreId,
    required this.orderIndex,
    required this.addedAt,
  });

  final String id;
  final String setListId;
  final String scoreId;
  final int orderIndex;
  final DateTime addedAt;

  SetListEntryModel copyWith({
    String? id,
    String? setListId,
    String? scoreId,
    int? orderIndex,
    DateTime? addedAt,
  }) =>
      SetListEntryModel(
        id: id ?? this.id,
        setListId: setListId ?? this.setListId,
        scoreId: scoreId ?? this.scoreId,
        orderIndex: orderIndex ?? this.orderIndex,
        addedAt: addedAt ?? this.addedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'setListId': setListId,
        'scoreId': scoreId,
        'orderIndex': orderIndex,
        'addedAt': addedAt.toIso8601String(),
      };

  factory SetListEntryModel.fromJson(Map<String, dynamic> json) =>
      SetListEntryModel(
        id: json['id'] as String,
        setListId: json['setListId'] as String,
        scoreId: json['scoreId'] as String,
        orderIndex: json['orderIndex'] as int,
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
