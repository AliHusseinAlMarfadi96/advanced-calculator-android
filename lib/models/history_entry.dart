class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.expression,
    required this.result,
    required this.createdAt,
  });

  final String id;
  final String expression;
  final String result;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'expression': expression,
        'result': result,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        expression: json['expression'] as String,
        result: json['result'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
