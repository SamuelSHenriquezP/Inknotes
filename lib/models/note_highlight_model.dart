import 'dart:convert';
import 'package:flutter/material.dart';

class NoteHighlightModel {
  final int start;
  final int end;
  final int colorValue; // 0 = sin color de fondo (solo estilo negrita/cursiva)
  final bool isBold;
  final bool isItalic;

  const NoteHighlightModel({
    required this.start,
    required this.end,
    this.colorValue = 0,
    this.isBold = false,
    this.isItalic = false,
  });

  bool get hasColor => colorValue != 0;
  Color get color => Color(colorValue);

  NoteHighlightModel copyWith({
    int? start,
    int? end,
    int? colorValue,
    bool? isBold,
    bool? isItalic,
  }) {
    return NoteHighlightModel(
      start: start ?? this.start,
      end: end ?? this.end,
      colorValue: colorValue ?? this.colorValue,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      'colorValue': colorValue,
      'isBold': isBold,
      'isItalic': isItalic,
    };
  }

  factory NoteHighlightModel.fromMap(Map<String, dynamic> map) {
    return NoteHighlightModel(
      start: map['start'] as int? ?? 0,
      end: map['end'] as int? ?? 0,
      colorValue: map['colorValue'] as int? ?? 0,
      isBold: map['isBold'] as bool? ?? false,
      isItalic: map['isItalic'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory NoteHighlightModel.fromJson(String source) =>
      NoteHighlightModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
