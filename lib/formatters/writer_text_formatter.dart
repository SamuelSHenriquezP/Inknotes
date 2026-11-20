import 'package:intl/intl.dart';

class ChecklistItem {
  final int lineIndex;
  final bool isChecked;
  final String text;
  final String leadingWhitespace;

  const ChecklistItem({
    required this.lineIndex,
    required this.isChecked,
    required this.text,
    this.leadingWhitespace = '',
  });
}

class WriterTextFormatter {
  static final RegExp _checklistLineRegex = RegExp(
    r'^(\s*)(?:-\s)?\[([ xX])\](?:\s(.*))?$',
  );

  /// Parsea una línea individual si corresponde a un ítem `- [ ] ` o `- [x] `.
  static ChecklistItem? parseChecklistLine(String line, int lineIndex) {
    final cleanLine = line.replaceAll('\r', '');
    final match = _checklistLineRegex.firstMatch(cleanLine);
    if (match == null) return null;
    final indent = match.group(1) ?? '';
    final mark = match.group(2) ?? ' ';
    final text = match.group(3) ?? '';
    return ChecklistItem(
      lineIndex: lineIndex,
      isChecked: mark.toLowerCase() == 'x',
      text: text,
      leadingWhitespace: indent,
    );
  }

  /// Extrae todos los ítems de checklist presentes en el contenido.
  static List<ChecklistItem> parseChecklistItems(String content) {
    if (content.isEmpty) return const [];
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final items = <ChecklistItem>[];
    for (int i = 0; i < lines.length; i++) {
      final parsed = parseChecklistLine(lines[i], i);
      if (parsed != null) items.add(parsed);
    }
    return items;
  }

  /// Indica si el contenido contiene al menos un ítem de checklist `- [ ]` / `- [x]`.
  static bool hasChecklist(String content) {
    if (content.isEmpty) return false;
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    return lines.any((line) => _checklistLineRegex.hasMatch(line));
  }

  /// Devuelve el conteo de tareas completadas y totales.
  static ({int checked, int total}) checklistProgress(String content) {
    final items = parseChecklistItems(content);
    final checked = items.where((i) => i.isChecked).length;
    return (checked: checked, total: items.length);
  }

  /// Alterna entre `- [ ] ` y `- [x] ` en la línea indicada conservando el resto del texto.
  static String toggleChecklistLine(String content, int lineIndex) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return content;

    final parsed = parseChecklistLine(lines[lineIndex], lineIndex);
    if (parsed == null) return content;

    final nextMark = parsed.isChecked ? ' ' : 'x';
    // Only replace the marker, keeping offsets for selections and highlights stable.
    lines[lineIndex] = lines[lineIndex].replaceFirst(
      RegExp(r'\[[ xX]\]'),
      '[$nextMark]',
    );
    return lines.join('\n');
  }

  /// Agrega una nueva tarea `- [ ] texto` al final del contenido.
  static String appendChecklistItem(String content, String taskText) {
    final cleanTask = taskText.trim();
    if (cleanTask.isEmpty) return content;
    if (content.trim().isEmpty) {
      return '- [ ] $cleanTask';
    }
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final separator = normalized.endsWith('\n') ? '' : '\n';
    return '$normalized$separator- [ ] $cleanTask';
  }

  static int countWords(String text) {
    if (text.isEmpty) return 0;
    int count = 0;
    bool inWord = false;
    final len = text.length;
    for (int i = 0; i < len; i++) {
      final code = text.codeUnitAt(i);
      if (code <= 32 || code == 0x00A0) {
        inWord = false;
      } else if (!inWord) {
        inWord = true;
        count++;
      }
    }
    return count;
  }

  static int estimateReadingTime(String text) {
    final words = countWords(text);
    if (words == 0) return 0;
    return (words / 200).ceil();
  }

  static String formatSpanishDate(
    DateTime date, {
    String format = 'EEEE, d MMMM',
  }) {
    try {
      return DateFormat(format, 'es_ES').format(date);
    } catch (_) {
      final days = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      final months = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
    }
  }

  static String formatSpanishRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDay = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(noteDay).inDays;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (diffDays == 0) {
      return 'Hoy, $hour:$minute';
    } else if (diffDays == 1) {
      return 'Ayer, $hour:$minute';
    } else if (now.year == date.year) {
      return formatSpanishDate(date, format: 'd MMM');
    } else {
      return formatSpanishDate(date, format: 'd MMM yyyy');
    }
  }

  /// Determina si una línea pertenece a una lista (viñeta, casilla o número)
  static bool isListItem(String line) {
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('•') ||
        trimmed.startsWith('☐') ||
        trimmed.startsWith('☑') ||
        trimmed.startsWith('- ') ||
        trimmed.startsWith('* ')) {
      return true;
    }
    return RegExp(r'^\d+[\.\)]\s').hasMatch(trimmed);
  }

  /// Formatea y separa párrafos con una línea en blanco si no la tienen,
  /// respetando los elementos de listas para que permanezcan juntos,
  /// y normalizando saltos de línea excesivos a un único renglón en blanco.
  static String formatParagraphs(String text) {
    if (text.trim().isEmpty) return text;

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');

    final List<String> resultLines = [];
    bool previousWasEmpty = false;

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trimRight();
      final isCurrentEmpty = line.trim().isEmpty;

      if (isCurrentEmpty) {
        if (!previousWasEmpty && resultLines.isNotEmpty) {
          resultLines.add('');
          previousWasEmpty = true;
        }
        continue;
      }

      if (resultLines.isNotEmpty && !previousWasEmpty) {
        final prevLine = resultLines.last;
        final prevIsList = isListItem(prevLine);
        final currIsList = isListItem(line);

        if (prevIsList && currIsList) {
          // Mantener elementos de lista continuos sin línea en blanco entre ellos
        } else {
          // Es cambio de párrafo (párrafo a párrafo, párrafo a lista o lista a párrafo):
          // Añadir línea en blanco si no la tenían
          resultLines.add('');
        }
      }

      resultLines.add(line);
      previousWasEmpty = false;
    }

    // Quitar líneas vacías al inicio y final
    while (resultLines.isNotEmpty && resultLines.first.isEmpty) {
      resultLines.removeAt(0);
    }
    while (resultLines.isNotEmpty && resultLines.last.isEmpty) {
      resultLines.removeLast();
    }

    return resultLines.join('\n');
  }
}
