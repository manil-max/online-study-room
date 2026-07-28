class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.locale,
    required this.question,
    required this.answer,
    required this.sortOrder,
  });

  final String id;
  final String locale;
  final String question;
  final String answer;
  final int sortOrder;

  factory FaqEntry.fromMap(Map<String, dynamic> map) => FaqEntry(
    id: map['id'] as String,
    locale: map['locale'] as String,
    question: map['question'] as String,
    answer: map['answer'] as String,
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
  );
}
