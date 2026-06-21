import 'package:flutter/foundation.dart';

/// Ders renk paleti — tasarım referansıyla aynı (bkz. project.md §3.7).
/// Renkler token adı olarak saklanır; tema bu token'ı gerçek renge çevirir.
const List<String> kSubjectColorTokens = <String>[
  'chart-1', // mavi
  'chart-2', // yeşil
  'chart-3', // sarı
  'chart-4', // mor
  'chart-5', // kırmızı
];

/// Kullanıcının tanımladığı bir ders (kategori). Supabase `subjects` tablosuna
/// karşılık gelir (bkz. project.md §3.7, §6). Kişiye özeldir.
@immutable
class Subject {
  const Subject({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
  });

  final String id;
  final String userId;
  final String name;

  /// Renk token'ı (`chart-1`..`chart-5`). Bkz. [kSubjectColorTokens].
  final String color;

  Subject copyWith({String? name, String? color}) {
    return Subject(
      id: id,
      userId: userId,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      // Eski/eksik kayıtlarda renk boş olabilir → varsayılan ilk palet rengi.
      color: (map['color'] as String?) ?? kSubjectColorTokens.first,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'color': color,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Subject &&
      other.id == id &&
      other.userId == userId &&
      other.name == name &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, userId, name, color);
}
