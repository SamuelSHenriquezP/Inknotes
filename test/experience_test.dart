import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ink_notes/controllers/notes_controller.dart';
import 'package:ink_notes/formatters/writer_text_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('clearing all data remains empty after reopening', () async {
    final notes = NotesController();
    await notes.ready;
    await notes.clearAllData();
    await notes.flushPendingChanges();
    final reopened = NotesController();
    await reopened.ready;
    expect(reopened.notes, isEmpty);
    expect(reopened.folders, isEmpty);
    notes.dispose();
    reopened.dispose();
  });

  test('invalid backup import preserves existing notes', () async {
    final notes = NotesController();
    await notes.ready;
    final original = notes.createNote(title: 'Conservar', content: 'Mi texto');
    final result = await notes.importBackupJson('{broken', merge: false);
    expect(result.success, isFalse);
    expect(
      notes.notes.firstWhere((n) => n.id == original.id).content,
      'Mi texto',
    );
    await notes.flushPendingChanges();
    notes.dispose();
  });

  test('bare checkboxes preserve prose, indentation and character offsets', () {
    const original = 'Mi día\n  [ ] Leer\n- [X] Escribir\nUna reflexión';
    final changed = WriterTextFormatter.toggleChecklistLine(original, 1);
    expect(changed, 'Mi día\n  [x] Leer\n- [X] Escribir\nUna reflexión');
    expect(changed.length, original.length);
    expect(WriterTextFormatter.checklistProgress(changed).checked, 2);
    expect(WriterTextFormatter.toggleChecklistLine(changed, 0), changed);
  });

  test(
    'inline tags cross folders and trashed pinned notes can be restored',
    () async {
      final notes = NotesController();
      await notes.ready;
      final first = notes.createNote(
        folderId: 'one',
        content: 'Pensar #ideas #Ánimo',
      );
      final second = notes.createNote(folderId: 'two', content: 'Crear #ideas');
      notes.setSelectedFolder('one');
      notes.setSelectedTagFilter('ideas');
      expect(
        notes.filteredNotes.map((n) => n.id),
        containsAll([first.id, second.id]),
      );
      expect(first.tags, contains('Ánimo'));
      notes.togglePin(first.id);
      expect(notes.filteredNotes.first.id, first.id);
      notes.deleteNote(first.id);
      expect(notes.notes.any((n) => n.id == first.id), isFalse);
      expect(notes.trashedNotes.any((n) => n.id == first.id), isTrue);
      notes.restoreNote(first.id);
      await notes.flushPendingChanges();
      final reopened = NotesController();
      await reopened.ready;
      expect(
        reopened.notes.firstWhere((n) => n.id == first.id).isPinned,
        isTrue,
      );
      notes.dispose();
      reopened.dispose();
    },
  );
}
