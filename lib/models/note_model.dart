import 'dart:convert';
import 'note_attachment_model.dart';
import 'note_highlight_model.dart';
import 'note_history_model.dart';

class NoteModel {
  final String id;
  final String? folderId;
  final String title;
  final String content;
  final bool isPinned;
  final List<NoteAttachmentModel> attachments;
  final List<NoteHighlightModel> highlights;
  final List<NoteHistorySnapshot> history;
  final int? colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    this.folderId,
    required this.title,
    required this.content,
    this.isPinned = false,
    this.attachments = const [],
    this.highlights = const [],
    this.history = const [],
    this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  NoteModel copyWith({
    String? id,
    String? folderId,
    bool clearFolder = false,
    String? title,
    String? content,
    bool? isPinned,
    List<NoteAttachmentModel>? attachments,
    List<NoteHighlightModel>? highlights,
    List<NoteHistorySnapshot>? history,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      attachments: attachments ?? this.attachments,
      highlights: highlights ?? this.highlights,
      history: history ?? this.history,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folderId': folderId,
      'title': title,
      'content': content,
      'isPinned': isPinned,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'highlights': highlights.map((h) => h.toMap()).toList(),
      'history': history.map((s) => s.toMap()).toList(),
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      folderId: map['folderId'] as String?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      isPinned: map['isPinned'] as bool? ?? false,
      attachments: (map['attachments'] as List<dynamic>?)
              ?.map(
                (e) => NoteAttachmentModel.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      highlights: (map['highlights'] as List<dynamic>?)
              ?.map(
                (e) => NoteHighlightModel.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      history: (map['history'] as List<dynamic>?)
              ?.map(
                (e) => NoteHistorySnapshot.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      colorValue: map['colorValue'] as int?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory NoteModel.fromJson(String source) =>
      NoteModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
