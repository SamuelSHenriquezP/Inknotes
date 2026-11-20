import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ink_notes/controllers/notes_controller.dart';
import 'package:ink_notes/controllers/theme_controller.dart';
import 'package:ink_notes/screens/note_editor_screen.dart';

void main() {
  testWidgets('tapping checklist keeps prose and persists checked state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    final notes = NotesController();
    await tester.runAsync(() => notes.ready);
    final note = notes.createNote(title: 'Mi día', content: '[ ] Leer\nUna reflexión\n- [x] Escribir');
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<NotesController>.value(value: notes),
      ChangeNotifierProvider(create: (_) => ThemeController()),
    ], child: MaterialApp(home: NoteEditorScreen(noteId: note.id))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tareas 1/2'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text('Una reflexión'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(notes.notes.firstWhere((n) => n.id == note.id).content,
      '[x] Leer\nUna reflexión\n- [x] Escribir');
    await tester.pumpWidget(const SizedBox.shrink());
    notes.dispose();
  });
}
