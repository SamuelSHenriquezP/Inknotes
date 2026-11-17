import 'package:flutter/material.dart';
import '../models/note_highlight_model.dart';

Color getHighlightColor(String? colorTag) {
  switch (colorTag?.toLowerCase()) {
    case 'mint':
    case 'verde':
      return const Color(0xFFA5D6A7); // Pastel Sage Mint
    case 'sky':
    case 'azul':
      return const Color(0xFF90CAF9); // Pastel Celestial Sky
    case 'lavender':
    case 'morado':
    case 'lila':
      return const Color(0xFFCE93D8); // Pastel Soft Lavender
    case 'peach':
    case 'naranja':
      return const Color(0xFFFFAB91); // Pastel Warm Peach
    case 'yellow':
    case 'amarillo':
    default:
      return const Color(0xFFFFE082); // Pastel Warm Amber/Yellow
  }
}

bool _isBoundaryChar(String char) {
  return char == ' ' ||
      char == '\n' ||
      char == '\t' ||
      char == '\r' ||
      char == '=' ||
      char == '*' ||
      char == '.' ||
      char == ',' ||
      char == ';' ||
      char == ':' ||
      char == '!' ||
      char == '?' ||
      char == '(' ||
      char == ')' ||
      char == '"' ||
      char == '•';
}

/// Limpia cualquier delimitador '==', '***', '**' o '*' del texto
String stripHighlightDelimiters(String text) {
  return text
      .replaceAll(RegExp(r'==(?:\[[a-zA-Z]+\])?'), '')
      .replaceAll('==', '')
      .replaceAll('***', '')
      .replaceAll('**', '');
}

class CleanedHighlightText {
  final String text;
  final List<NoteHighlightModel> highlights;
  const CleanedHighlightText(this.text, this.highlights);
}

/// Extrae resaltados, negritas y cursivas de texto markdown y devuelve el texto puro y limpio
/// sin ningún delimitador visible ('**', '*', '==').
CleanedHighlightText cleanMarkdownDelimiters(
  String rawText, {
  List<NoteHighlightModel>? existing,
}) {
  if (!rawText.contains('==') && !rawText.contains('*')) {
    return CleanedHighlightText(rawText, existing ?? const []);
  }

  // Coincide con ==[tag]texto== o ==texto==, negrita-cursiva ***texto***, negrita **texto**, cursiva *texto*
  final regex = RegExp(
    r'(==(?:\[([a-zA-Z]+)\])?([^=\n]+)==|\*\*\*([^\s\*\n](?:[^\*\n]*?[^\s\*\n])?)\*\*\*|\*\*([^\s\*\n](?:[^\*\n]*?[^\s\*\n])?)\*\*|\*([^\s\*\n](?:[^\*\n]*?[^\s\*\n])?)\*)',
  );

  final matches = regex.allMatches(rawText).toList();
  if (matches.isEmpty) {
    return CleanedHighlightText(rawText, existing ?? const []);
  }

  final List<NoteHighlightModel> extracted = List.from(existing ?? []);
  final buffer = StringBuffer();
  int cursor = 0;

  for (final m in matches) {
    if (m.start > cursor) {
      buffer.write(stripHighlightDelimiters(rawText.substring(cursor, m.start)));
    }

    final highlightTag = m.group(2);
    final highlightText = m.group(3);
    final boldItalicText = m.group(4);
    final boldText = m.group(5);
    final italicText = m.group(6);

    final start = buffer.length;

    if (highlightText != null) {
      final cleanInner = stripHighlightDelimiters(highlightText);
      buffer.write(cleanInner);
      final end = buffer.length;
      if (end > start) {
        extracted.add(NoteHighlightModel(
          start: start,
          end: end,
          colorValue: getHighlightColor(highlightTag).toARGB32(),
        ));
      }
    } else if (boldItalicText != null) {
      final cleanInner = stripHighlightDelimiters(boldItalicText);
      buffer.write(cleanInner);
      final end = buffer.length;
      if (end > start) {
        extracted.add(NoteHighlightModel(
          start: start,
          end: end,
          isBold: true,
          isItalic: true,
        ));
      }
    } else if (boldText != null) {
      final cleanInner = stripHighlightDelimiters(boldText);
      buffer.write(cleanInner);
      final end = buffer.length;
      if (end > start) {
        extracted.add(NoteHighlightModel(
          start: start,
          end: end,
          isBold: true,
        ));
      }
    } else if (italicText != null) {
      final cleanInner = stripHighlightDelimiters(italicText);
      buffer.write(cleanInner);
      final end = buffer.length;
      if (end > start) {
        extracted.add(NoteHighlightModel(
          start: start,
          end: end,
          isItalic: true,
        ));
      }
    }

    cursor = m.end;
  }

  if (cursor < rawText.length) {
    buffer.write(stripHighlightDelimiters(rawText.substring(cursor)));
  }

  final finalText = buffer.toString();
  return CleanedHighlightText(
    finalText,
    mergeHighlights(extracted, finalText.length),
  );
}

/// Une resaltados contiguos o solapados del mismo estilo y los ordena por inicio
List<NoteHighlightModel> mergeHighlights(List<NoteHighlightModel> list, int maxLen) {
  if (list.isEmpty) return const [];

  final valid = list
      .where((h) => h.start < maxLen && h.end > h.start && h.start >= 0)
      .map((h) => h.copyWith(
            start: h.start.clamp(0, maxLen),
            end: h.end.clamp(0, maxLen),
          ))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  if (valid.length <= 1) return valid;

  final List<NoteHighlightModel> merged = [];
  for (final h in valid) {
    if (merged.isEmpty) {
      merged.add(h);
      continue;
    }
    final last = merged.last;
    if (last.colorValue == h.colorValue &&
        last.isBold == h.isBold &&
        last.isItalic == h.isItalic &&
        h.start <= last.end) {
      merged[merged.length - 1] = last.copyWith(
        end: last.end > h.end ? last.end : h.end,
      );
    } else {
      merged.add(h);
    }
  }
  return merged;
}

/// Actualiza matemáticamente la posición de los estilos ante inserciones o borrados
List<NoteHighlightModel> updateHighlightsOnTextChange({
  required String oldText,
  required String newText,
  required List<NoteHighlightModel> highlights,
}) {
  if (newText.isEmpty) return const [];
  if (highlights.isEmpty) return const [];

  int p = 0;
  while (p < oldText.length && p < newText.length && oldText[p] == newText[p]) {
    p++;
  }

  int s = 0;
  while (s < (oldText.length - p) &&
      s < (newText.length - p) &&
      oldText[oldText.length - 1 - s] == newText[newText.length - 1 - s]) {
    s++;
  }

  final deletedLen = oldText.length - s - p;
  final insertedLen = newText.length - s - p;
  final delta = insertedLen - deletedLen;
  final editStart = p;
  final editEnd = p + deletedLen;

  final List<NoteHighlightModel> updated = [];

  for (final h in highlights) {
    final start = h.start;
    final end = h.end;

    if (end <= editStart) {
      updated.add(h);
    } else if (start >= editEnd) {
      final newStart = start + delta;
      final newEnd = end + delta;
      if (newEnd > newStart && newStart >= 0 && newEnd <= newText.length) {
        updated.add(h.copyWith(start: newStart, end: newEnd));
      }
    } else {
      if (editStart <= start && editEnd >= end) {
        continue;
      } else if (editStart >= start && editEnd <= end) {
        final newEnd = end + delta;
        if (newEnd > start && start >= 0 && newEnd <= newText.length) {
          updated.add(h.copyWith(start: start, end: newEnd));
        }
      } else if (editStart < start) {
        final newStart = editStart + insertedLen;
        final newEnd = end + delta;
        if (newEnd > newStart && newStart >= 0 && newEnd <= newText.length) {
          updated.add(h.copyWith(start: newStart, end: newEnd));
        }
      } else {
        final newEnd = editStart;
        if (newEnd > start && start >= 0 && newEnd <= newText.length) {
          updated.add(h.copyWith(start: start, end: newEnd));
        }
      }
    }
  }

  return mergeHighlights(updated, newText.length);
}

/// Construye spans dividiendo el texto en segmentos según los límites de los estilos activos
List<InlineSpan> buildStyledSpans({
  required String text,
  required List<NoteHighlightModel> highlights,
  TextStyle? baseStyle,
  bool isDark = false,
}) {
  if (text.isEmpty) return const [];
  final effectiveBase = baseStyle ?? const TextStyle();

  final len = text.length;
  final valid = highlights
      .where((h) => h.start < len && h.end > h.start && h.start >= 0)
      .toList();

  if (valid.isEmpty) {
    return [TextSpan(text: text, style: effectiveBase)];
  }

  final Set<int> boundaries = {0, len};
  for (final h in valid) {
    boundaries.add(h.start.clamp(0, len));
    boundaries.add(h.end.clamp(0, len));
  }
  final sortedBoundaries = boundaries.toList()..sort();

  final List<InlineSpan> spans = [];

  for (int i = 0; i < sortedBoundaries.length - 1; i++) {
    final start = sortedBoundaries[i];
    final end = sortedBoundaries[i + 1];
    if (start >= end) continue;

    final segment = text.substring(start, end);

    bool isBold = false;
    bool isItalic = false;
    int colorValue = 0;

    for (final h in valid) {
      if (h.start <= start && h.end >= end) {
        if (h.isBold) isBold = true;
        if (h.isItalic) isItalic = true;
        if (h.hasColor) colorValue = h.colorValue;
      }
    }

    TextStyle segStyle = effectiveBase;
    if (isBold) {
      segStyle = segStyle.copyWith(fontWeight: FontWeight.w700);
    }
    if (isItalic) {
      segStyle = segStyle.copyWith(fontStyle: FontStyle.italic);
    }
    if (colorValue != 0) {
      final col = Color(colorValue);
      segStyle = segStyle.copyWith(
        backgroundColor: col.withValues(alpha: isDark ? 0.35 : 0.45),
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      );
    }

    spans.add(TextSpan(text: segment, style: segStyle));
  }

  return spans;
}

class HighlightedTextEditingController extends TextEditingController {
  List<NoteHighlightModel> highlights;
  bool isDark;

  HighlightedTextEditingController({
    super.text,
    List<NoteHighlightModel>? highlights,
    this.isDark = false,
  }) : highlights = List.from(highlights ?? []);

  void setHighlights(List<NoteHighlightModel> newHighlights) {
    highlights = mergeHighlights(newHighlights, text.length);
    notifyListeners();
  }

  void setIsDark(bool dark) {
    if (isDark != dark) {
      isDark = dark;
      notifyListeners();
    }
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;

    if (oldText != newText && highlights.isNotEmpty) {
      highlights = updateHighlightsOnTextChange(
        oldText: oldText,
        newText: newText,
        highlights: highlights,
      );
    }

    super.value = newValue;
  }

  /// Alterna negrita en el texto seleccionado o la palabra actual sin insertar asteriscos
  void toggleBold() {
    _toggleStyle(bold: true);
  }

  /// Alterna cursiva en el texto seleccionado o la palabra actual sin insertar asteriscos
  void toggleItalic() {
    _toggleStyle(italic: true);
  }

  void _toggleStyle({bool bold = false, bool italic = false}) {
    final currentText = text;
    if (currentText.isEmpty) return;

    int start;
    int end;

    if (selection.isValid && selection.start != selection.end) {
      start = selection.start.clamp(0, currentText.length);
      end = selection.end.clamp(0, currentText.length);
      if (start > end) {
        final temp = start;
        start = end;
        end = temp;
      }
    } else {
      final cursor = (selection.isValid ? selection.start : currentText.length)
          .clamp(0, currentText.length);
      start = cursor;
      while (start > 0 && !_isBoundaryChar(currentText[start - 1])) {
        start--;
      }
      end = cursor;
      while (end < currentText.length && !_isBoundaryChar(currentText[end])) {
        end++;
      }
    }

    if (end <= start) return;

    final isCurrentlyActive = highlights.any((h) =>
        h.start <= start &&
        h.end >= end &&
        (bold ? h.isBold : h.isItalic));

    List<NoteHighlightModel> next = List.from(highlights);

    if (isCurrentlyActive) {
      final List<NoteHighlightModel> modified = [];
      for (final h in next) {
        final matchesStyle = bold ? h.isBold : h.isItalic;
        if (matchesStyle && h.start < end && h.end > start) {
          if (h.start < start) {
            modified.add(h.copyWith(end: start));
          }
          if (h.end > end) {
            modified.add(h.copyWith(start: end));
          }
          final keepColor = h.hasColor;
          final keepOtherStyle = bold ? h.isItalic : h.isBold;
          if (keepColor || keepOtherStyle) {
            final middleStart = h.start > start ? h.start : start;
            final middleEnd = h.end < end ? h.end : end;
            if (middleEnd > middleStart) {
              modified.add(h.copyWith(
                start: middleStart,
                end: middleEnd,
                isBold: bold ? false : h.isBold,
                isItalic: italic ? false : h.isItalic,
              ));
            }
          }
        } else {
          modified.add(h);
        }
      }
      next = modified;
    } else {
      next.add(NoteHighlightModel(
        start: start,
        end: end,
        isBold: bold,
        isItalic: italic,
      ));
    }

    highlights = mergeHighlights(next, currentText.length);
    notifyListeners();
  }

  /// Aplica o alterna el resaltado de color sobre la selección o palabra actual
  void applyHighlightColor(int colorValue) {
    final currentText = text;
    if (currentText.isEmpty) return;

    int start;
    int end;

    if (selection.isValid && selection.start != selection.end) {
      start = selection.start.clamp(0, currentText.length);
      end = selection.end.clamp(0, currentText.length);
      if (start > end) {
        final temp = start;
        start = end;
        end = temp;
      }
    } else {
      final cursor = (selection.isValid ? selection.start : currentText.length)
          .clamp(0, currentText.length);
      start = cursor;
      while (start > 0 && !_isBoundaryChar(currentText[start - 1])) {
        start--;
      }
      end = cursor;
      while (end < currentText.length && !_isBoundaryChar(currentText[end])) {
        end++;
      }
    }

    if (end <= start) return;

    final existingIndex = highlights.indexWhere(
      (h) => h.start == start && h.end == end && h.colorValue == colorValue,
    );

    List<NoteHighlightModel> next = List.from(highlights);
    if (existingIndex != -1) {
      next.removeAt(existingIndex);
    } else {
      next.removeWhere((h) => h.start >= start && h.end <= end && !h.isBold && !h.isItalic);
      next.add(NoteHighlightModel(start: start, end: end, colorValue: colorValue));
    }

    highlights = mergeHighlights(next, currentText.length);
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final spans = buildStyledSpans(
      text: text,
      highlights: highlights,
      baseStyle: style,
      isDark: isDark,
    );

    return TextSpan(style: style, children: spans);
  }
}

/// Compatibilidad: Parsea texto extrayendo estilos y limpiando asteriscos
List<InlineSpan> parseMarkdownSpans({
  required String text,
  TextStyle? baseStyle,
  bool isEditor = false,
  Color? highlightColor,
  bool isDark = false,
}) {
  final cleaned = cleanMarkdownDelimiters(text);
  final List<NoteHighlightModel> list = List.from(cleaned.highlights);
  if (highlightColor != null) {
    list.add(NoteHighlightModel(
      start: 0,
      end: cleaned.text.length,
      colorValue: highlightColor.toARGB32(),
    ));
  }
  return buildStyledSpans(
    text: cleaned.text,
    highlights: list,
    baseStyle: baseStyle,
    isDark: isDark,
  );
}

/// Renderiza TextSpan para las tarjetas de notas o vistas estáticas sin ningún carácter de código
TextSpan buildHighlightedTextSpan({
  required String text,
  required List<NoteHighlightModel> highlights,
  TextStyle? baseStyle,
  bool isDark = false,
}) {
  if (text.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  if (text.contains('==') || text.contains('*')) {
    final cleaned = cleanMarkdownDelimiters(text, existing: highlights);
    return buildHighlightedTextSpan(
      text: cleaned.text,
      highlights: cleaned.highlights,
      baseStyle: baseStyle,
      isDark: isDark,
    );
  }

  final spans = buildStyledSpans(
    text: text,
    highlights: highlights,
    baseStyle: baseStyle,
    isDark: isDark,
  );

  return TextSpan(style: styleOrDefault(baseStyle), children: spans);
}

TextStyle styleOrDefault(TextStyle? style) => style ?? const TextStyle();
