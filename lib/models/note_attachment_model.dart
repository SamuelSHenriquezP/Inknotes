import 'dart:convert';

// Audio is retained only to decode older backups; it has no editor or player.
enum AttachmentType { image, audio, drawing }

class NoteAttachmentModel {
  final String id;
  final AttachmentType type;
  /// Base64 payload or local file path
  final String data;
  final String? name;
  final int? durationSeconds;
  final DateTime createdAt;

  const NoteAttachmentModel({
    required this.id,
    required this.type,
    required this.data,
    this.name,
    this.durationSeconds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'data': data,
      'name': name,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NoteAttachmentModel.fromMap(Map<String, dynamic> map) {
    return NoteAttachmentModel(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: AttachmentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AttachmentType.image,
      ),
      data: map['data'] as String? ?? '',
      name: map['name'] as String?,
      durationSeconds: map['durationSeconds'] as int?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory NoteAttachmentModel.fromJson(String source) =>
      NoteAttachmentModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
