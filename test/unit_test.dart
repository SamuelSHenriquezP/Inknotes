import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ink_notes/controllers/security_controller.dart';
import 'package:ink_notes/models/note_model.dart';
import 'package:ink_notes/models/folder_model.dart';
import 'package:ink_notes/models/note_highlight_model.dart';
import 'package:ink_notes/models/note_history_model.dart';
import 'package:ink_notes/theme/app_theme.dart';
import 'package:ink_notes/formatters/writer_text_formatter.dart';
import 'package:ink_notes/formatters/highlighted_text_controller.dart';
import 'package:ink_notes/controllers/editor_undo_manager.dart';
import 'package:ink_notes/controllers/notes_controller.dart';

void main() {
  group('WriterTextFormatter Tests', () {
    test('countWords returns accurate word count', () {
      expect(WriterTextFormatter.countWords(''), 0);
      expect(WriterTextFormatter.countWords('   '), 0);
      expect(WriterTextFormatter.countWords('Hola mundo'), 2);
      expect(WriterTextFormatter.countWords('Hola, esto es inkNotes! 📝'), 5);
    });

    test('estimateReadingTime calculates reasonable minutes', () {
      expect(WriterTextFormatter.estimateReadingTime(''), 0);
      final text100Words = List.generate(100, (i) => 'palabra').join(' ');
      expect(WriterTextFormatter.estimateReadingTime(text100Words), 1);
    });

    test('formatSpanishDate formats accurately', () {
      final date = DateTime(2026, 11, 9);
      final formatted =
          WriterTextFormatter.formatSpanishDate(date, format: 'd MMM');
      expect(formatted.isNotEmpty, true);
    });

    test('formatSpanishRelativeDate formats accurately', () {
      final now = DateTime.now();
      expect(
          WriterTextFormatter.formatSpanishRelativeDate(now).startsWith('Hoy,'),
          true);
      final yesterday = now.subtract(const Duration(days: 1));
      expect(
          WriterTextFormatter.formatSpanishRelativeDate(yesterday)
              .startsWith('Ayer,'),
          true);
    });
  });

  group('Model Serialization Tests', () {
    test('FolderModel serialization roundtrip', () {
      final folder = FolderModel(
        id: 'f_test',
        name: 'Proyectos',
        colorValue: 0xFF10B981,
        iconCode: 0xe362,
        createdAt: DateTime(2026, 11, 9),
      );
      final json = folder.toJson();
      final decoded = FolderModel.fromJson(json);

      expect(decoded.id, 'f_test');
      expect(decoded.name, 'Proyectos');
      expect(decoded.colorValue, 0xFF10B981);
    });

    test('NoteModel serialization roundtrip with history', () {
      final snapshot = NoteHistorySnapshot(
        timestamp: DateTime(2026, 11, 9, 10, 0),
        title: 'Versión inicial',
        content: 'Borrador',
        wordCount: 1,
      );

      final note = NoteModel(
        id: 'n_test',
        folderId: 'general',
        title: 'Mi nota de prueba',
        content: 'Contenido con resaltados',
        isPinned: true,
        highlights: [
          const NoteHighlightModel(start: 0, end: 9, colorValue: 0xFFFEF08A),
        ],
        history: [snapshot],
        createdAt: DateTime(2026, 11, 9),
        updatedAt: DateTime(2026, 11, 9),
      );
      final json = note.toJson();
      final decoded = NoteModel.fromJson(json);

      expect(decoded.id, 'n_test');
      expect(decoded.title, 'Mi nota de prueba');
      expect(decoded.isPinned, true);
      expect(decoded.highlights.length, 1);
      expect(decoded.history.length, 1);
      expect(decoded.history.first.title, 'Versión inicial');
    });
  });

  group('Theme & Typography Presets Tests', () {
    test('All theme presets have valid colors and labels', () {
      for (final preset in AppThemePreset.values) {
        expect(preset.label.isNotEmpty, true);
        expect(preset.description.isNotEmpty, true);
        expect(preset.bgPrimary(false), isNotNull);
        expect(preset.bgPrimary(true), isNotNull);
      }
    });

    test('All font families have valid styles and labels', () {
      for (final font in NoteFontFamily.values) {
        expect(font.label.isNotEmpty, true);
        expect(font.category.isNotEmpty, true);
      }
    });
  });

  group('HighlightedTextEditingController Tests', () {
    test('buildHighlightedTextSpan creates correct spans for highlights', () {
      const text = 'Hola mundo brillante';
      final highlights = [
        const NoteHighlightModel(start: 5, end: 10, colorValue: 0xFFFFE082),
      ];

      final span = buildHighlightedTextSpan(text: text, highlights: highlights);
      expect(span.children?.length, 3);
    });

    test('applyHighlightColor adds and removes highlights without modifying raw text', () {
      const text = 'Este es un texto de prueba';
      final controller = HighlightedTextEditingController(text: text);
      // Select "un texto" (indices 8 to 16)
      controller.selection = const TextSelection(baseOffset: 8, extentOffset: 16);
      controller.applyHighlightColor(0xFFFFE082);

      // Text must remain 100% clean plain text with no delimiters or code words
      expect(controller.text, 'Este es un texto de prueba');
      expect(controller.highlights.length, 1);
      expect(controller.highlights.first.start, 8);
      expect(controller.highlights.first.end, 16);

      // Toggling off exact selection
      controller.applyHighlightColor(0xFFFFE082);
      expect(controller.highlights.isEmpty, true);
    });

    test('updateHighlightsOnTextChange shifts highlights when typing before them', () {
      const oldText = 'Este es un texto';
      const newText = 'Nuevo Este es un texto';
      final highlights = [
        const NoteHighlightModel(start: 8, end: 16, colorValue: 0xFFFFE082),
      ];

      final updated = updateHighlightsOnTextChange(
        oldText: oldText,
        newText: newText,
        highlights: highlights,
      );

      expect(updated.length, 1);
      expect(updated.first.start, 14); // Shifted by +6
      expect(updated.first.end, 22);
    });

    test('cleanMarkdownDelimiters heals broken words and extracts clean text', () {
      const broken = '==Espacio minimalista y rápido dis==eñado para tomar notas.\n• ==[mint]Resalta== fragmentos con tonos ==past==el==es.';
      final cleaned = cleanMarkdownDelimiters(broken);

      expect(cleaned.text.contains('=='), false);
      expect(cleaned.text.contains('[mint]'), false);
      expect(cleaned.text.contains('diseñado'), true);
      expect(cleaned.text.contains('pasteles'), true);
      expect(cleaned.highlights.isNotEmpty, true);
    });

    test('stripHighlightDelimiters cleans delimiters for word counting', () {
      const text = '==Espacio minimalista== y rápido diseñado';
      expect(stripHighlightDelimiters(text), 'Espacio minimalista y rápido diseñado');
    });

    test('formatParagraphs separates paragraphs but keeps lists and avoids duplicates', () {
      // Caso 1: Párrafos pegados reciben línea en blanco
      const inputSingle = 'Párrafo uno.\nPárrafo dos.\nPárrafo tres.';
      final formattedSingle = WriterTextFormatter.formatParagraphs(inputSingle);
      expect(formattedSingle, 'Párrafo uno.\n\nPárrafo dos.\n\nPárrafo tres.');

      // Caso 2: Párrafos que ya tienen línea en blanco NO se duplican
      const inputDouble = 'Párrafo uno.\n\nPárrafo dos.\n\nPárrafo tres.';
      final formattedDouble = WriterTextFormatter.formatParagraphs(inputDouble);
      expect(formattedDouble, 'Párrafo uno.\n\nPárrafo dos.\n\nPárrafo tres.');

      // Caso 3: Saltos excesivos se normalizan
      const inputExcess = 'Párrafo uno.\n\n\n\nPárrafo dos.';
      final formattedExcess = WriterTextFormatter.formatParagraphs(inputExcess);
      expect(formattedExcess, 'Párrafo uno.\n\nPárrafo dos.');

      // Caso 4: Listas se mantienen compactas pero separadas de párrafos
      const inputList = 'Introducción a la lista:\n• Elemento 1\n• Elemento 2\nConclusión final.';
      final formattedList = WriterTextFormatter.formatParagraphs(inputList);
      expect(formattedList, 'Introducción a la lista:\n\n• Elemento 1\n• Elemento 2\n\nConclusión final.');
    });

    test('parseMarkdownSpans and controller parse bold and italic without visible asterisks', () {
      const text = 'Texto con **negrita** y con *cursiva* y ***ambas***.';
      final editorSpans = parseMarkdownSpans(text: text, isEditor: true);
      expect(editorSpans.isNotEmpty, true);

      // Los delimitadores asterisco se ocultan tanto en el editor como en las tarjetas para una lectura limpia
      final editorText = editorSpans.map((s) => (s as TextSpan).text ?? '').join();
      expect(editorText, 'Texto con negrita y con cursiva y ambas.');

      final cardSpans = parseMarkdownSpans(text: text, isEditor: false);
      final cardText = cardSpans.map((s) => (s as TextSpan).text ?? '').join();
      expect(cardText, 'Texto con negrita y con cursiva y ambas.');
    });

    test('toggleBold and toggleItalic format text cleanly without asterisks in raw text', () {
      const raw = 'Hola mundo';
      final controller = HighlightedTextEditingController(text: raw);
      // Select "mundo" (indices 5 to 10)
      controller.selection = const TextSelection(baseOffset: 5, extentOffset: 10);
      controller.toggleBold();

      // Raw text has ZERO asterisks
      expect(controller.text, 'Hola mundo');
      expect(controller.highlights.length, 1);
      expect(controller.highlights.first.isBold, true);
      expect(controller.highlights.first.start, 5);
      expect(controller.highlights.first.end, 10);

      // Toggle bold off
      controller.toggleBold();
      expect(controller.highlights.isEmpty, true);

      // Toggle italic
      controller.toggleItalic();
      expect(controller.text, 'Hola mundo');
      expect(controller.highlights.length, 1);
      expect(controller.highlights.first.isItalic, true);
    });
  });

  group('EditorUndoManager Tests', () {
    test('initial state has canUndo false and canRedo false', () {
      final manager = EditorUndoManager();
      manager.initialize(const EditorHistoryEntry(
        title: 'Título inicial',
        content: 'Contenido inicial',
        selection: TextSelection.collapsed(offset: 0),
        highlights: [],
      ));

      expect(manager.canUndo, false);
      expect(manager.canRedo, false);
      expect(manager.historyLength, 1);
    });

    test('pushSnapshot enables undo and undo returns previous state', () {
      final manager = EditorUndoManager();
      manager.initialize(const EditorHistoryEntry(
        title: 'Nota',
        content: 'Hola',
        selection: TextSelection.collapsed(offset: 4),
        highlights: [],
      ));

      // Añadir segundo estado
      manager.pushSnapshot(const EditorHistoryEntry(
        title: 'Nota',
        content: 'Hola mundo',
        selection: TextSelection.collapsed(offset: 10),
        highlights: [
          NoteHighlightModel(start: 5, end: 10, colorValue: 0xFFFFE082),
        ],
      ));

      expect(manager.canUndo, true);
      expect(manager.canRedo, false);

      // Deshacer
      final previous = manager.undo();
      expect(previous, isNotNull);
      expect(previous!.content, 'Hola');
      expect(previous.highlights.isEmpty, true);
      expect(manager.canUndo, false);
      expect(manager.canRedo, true);

      // Rehacer
      final next = manager.redo();
      expect(next, isNotNull);
      expect(next!.content, 'Hola mundo');
      expect(next.highlights.length, 1);
      expect(manager.canUndo, true);
      expect(manager.canRedo, false);
    });

    test('pushing new state after undo discards future redo stack', () {
      final manager = EditorUndoManager();
      manager.initialize(const EditorHistoryEntry(
        title: 'Nota',
        content: 'A',
        selection: TextSelection.collapsed(offset: 1),
        highlights: [],
      ));

      manager.pushSnapshot(const EditorHistoryEntry(
        title: 'Nota',
        content: 'B',
        selection: TextSelection.collapsed(offset: 1),
        highlights: [],
      ));

      manager.undo(); // Vuelve a 'A'
      expect(manager.canRedo, true);

      // Escribir nueva rama 'C'
      manager.pushSnapshot(const EditorHistoryEntry(
        title: 'Nota',
        content: 'C',
        selection: TextSelection.collapsed(offset: 1),
        highlights: [],
      ));

      expect(manager.canRedo, false);
      expect(manager.canUndo, true);
      expect(manager.historyLength, 2);
    });

    test('duplicate snapshots are ignored', () {
      final manager = EditorUndoManager();
      manager.initialize(const EditorHistoryEntry(
        title: 'Nota',
        content: 'A',
        selection: TextSelection.collapsed(offset: 1),
        highlights: [],
      ));

      manager.pushSnapshot(const EditorHistoryEntry(
        title: 'Nota',
        content: 'A',
        selection: TextSelection.collapsed(offset: 1),
        highlights: [],
      ));

      expect(manager.historyLength, 1);
      expect(manager.canUndo, false);
    });
  });

  group('Sort & Filter Tests', () {
    test('All SortCriteria options have valid labels and icons', () {
      for (final criteria in SortCriteria.values) {
        expect(criteria.label.isNotEmpty, true);
        expect(criteria.icon, isNotNull);
      }
    });

    test('All SortDirection options have valid labels and icons', () {
      for (final direction in SortDirection.values) {
        expect(direction.label.isNotEmpty, true);
        expect(direction.icon, isNotNull);
      }
    });

    test('All FilterType options have valid labels and icons', () {
      for (final filter in FilterType.values) {
        expect(filter.label.isNotEmpty, true);
        expect(filter.icon, isNotNull);
      }
    });

    test('isFilterActive reports true when any option is non-default and false on reset', () {
      WidgetsFlutterBinding.ensureInitialized();
      final controller = NotesController();
      expect(controller.isFilterActive, false);

      controller.setSortBy(SortCriteria.name);
      expect(controller.isFilterActive, true);

      controller.resetSortAndFilter();
      expect(controller.isFilterActive, false);

      controller.setSortDirection(SortDirection.ascending);
      expect(controller.isFilterActive, true);

      controller.resetSortAndFilter();
      expect(controller.isFilterActive, false);

      controller.setFilterType(FilterType.notes);
      expect(controller.isFilterActive, true);

      controller.resetSortAndFilter();
      expect(controller.isFilterActive, false);
    });

    test('Batch deletion and move operations work properly', () {
      WidgetsFlutterBinding.ensureInitialized();
      final controller = NotesController();
      final n1 = controller.createNote(title: 'Nota 1');
      final n2 = controller.createNote(title: 'Nota 2');

      controller.moveNotesToFolder([n1.id, n2.id], 'ideas');
      expect(controller.notes.firstWhere((n) => n.id == n1.id).folderId, 'ideas');
      expect(controller.notes.firstWhere((n) => n.id == n2.id).folderId, 'ideas');

      controller.deleteNotes([n1.id, n2.id]);
      expect(controller.notes.any((n) => n.id == n1.id), false);
      expect(controller.notes.any((n) => n.id == n2.id), false);
    });

    test('History snapshot deletion and clear work properly', () {
      WidgetsFlutterBinding.ensureInitialized();
      final controller = NotesController();
      final note = controller.createNote(title: 'Nota Historial', content: 'Contenido A');

      controller.addHistorySnapshot(note.id);
      final withHistory = controller.notes.firstWhere((n) => n.id == note.id);
      expect(withHistory.history.isNotEmpty, true);

      controller.deleteHistorySnapshot(note.id, 0);
      final afterDelete = controller.notes.firstWhere((n) => n.id == note.id);
      expect(afterDelete.history.isEmpty, true);

      controller.addHistorySnapshot(note.id);
      controller.clearHistory(note.id);
      final afterClear = controller.notes.firstWhere((n) => n.id == note.id);
      expect(afterClear.history.isEmpty, true);
    });
  });

  group('Security & Backup Tests', () {
    test('Welcome note highlights match supported features', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = NotesController();
      await Future.delayed(const Duration(milliseconds: 50));

      final welcome = controller.notes.firstWhere((n) => n.id == 'note_welcome');
      final highlightedWords = welcome.highlights
          .map((h) => welcome.content.substring(h.start, h.end))
          .toList();

      expect(highlightedWords.contains('Resalta'), true);
      expect(highlightedWords.contains('dibujos'), true);
      expect(welcome.content, isNot(contains('Graba notas de voz')));
    });

    test('Manual export and import roundtrip restores notes and folders', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = NotesController();
      await Future.delayed(const Duration(milliseconds: 50));

      controller.createNote(title: 'Backup Test Note', content: 'Contenido clave');
      final jsonBackup = controller.buildBackupJson();
      final preview = controller.previewBackupJson(jsonBackup);
      expect(preview, isNotNull);
      expect(preview!.notesCount >= 1, true);

      await controller.clearAllData();
      expect(controller.notes.isEmpty, true);

      final result = await controller.importBackupJson(jsonBackup, merge: false);
      expect(result.success, true);
      expect(controller.notes.any((n) => n.title == 'Backup Test Note'), true);
    });

    test('SecurityController PIN hashing, verification, and lock state work properly', () async {
      SharedPreferences.setMockInitialValues({});
      final sec = SecurityController();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(sec.pinEnabled, false);
      await sec.setPin('4829');
      expect(sec.pinEnabled, true);
      expect(sec.verifyPin('0000'), false);
      expect(sec.verifyPin('4829'), true);

      sec.lockNow();
      expect(sec.isLocked, true);
      expect(sec.unlockWithPin('1234'), false);
      expect(sec.isLocked, true);
      expect(sec.unlockWithPin('4829'), true);
      expect(sec.isLocked, false);

      await sec.disablePin();
      expect(sec.pinEnabled, false);
    });
  });
}
