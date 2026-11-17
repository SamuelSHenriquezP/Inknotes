import 'package:intl/intl.dart';

class WriterTextFormatter {
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

  static String formatSpanishDate(DateTime date, {String format = 'EEEE, d MMMM'}) {
    try {
      return DateFormat(format, 'es_ES').format(date);
    } catch (_) {
      final days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      final months = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
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
