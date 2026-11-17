import 'dart:convert';

class NoteHistorySnapshot {
  final DateTime timestamp;
  final String title;
  final String content;
  final int wordCount;

  const NoteHistorySnapshot({
    required this.timestamp,
    required this.title,
    required this.content,
    required this.wordCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'content': content,
      'wordCount': wordCount,
    };
  }

  factory NoteHistorySnapshot.fromMap(Map<String, dynamic> map) {
    return NoteHistorySnapshot(
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      wordCount: map['wordCount'] as int? ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory NoteHistorySnapshot.fromJson(String source) =>
      NoteHistorySnapshot.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
