import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ink_notes/controllers/notes_controller.dart';
import 'package:ink_notes/controllers/theme_controller.dart';
import 'package:ink_notes/models/note_attachment_model.dart';
import 'package:ink_notes/models/note_highlight_model.dart';
import 'package:ink_notes/models/note_model.dart';
import 'package:ink_notes/screens/note_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'new installations contain no voice demo or promise of recording',
    () async {
      final notes = NotesController();
      await notes.ready;
      expect(notes.notes.any((n) => n.id == 'note_voice'), isFalse);
      expect(
        notes.notes
            .expand((n) => n.attachments)
            .any((a) => a.type == AttachmentType.audio),
        isFalse,
      );
      expect(
        notes.notes.firstWhere((n) => n.id == 'note_welcome').content,
        isNot(contains('notas de voz')),
      );
      await notes.flushPendingChanges();
      notes.dispose();
    },
  );

  test(
    'welcome migration preserves user notes and shifts existing highlights',
    () async {
      const content =
          'Bienvenido\n• Graba notas de voz directas con reproductor integrado.\n• Inserta imágenes en cualquier nota.';
      final now = DateTime(2026, 11, 20);
      final welcome = NoteModel(
        id: 'note_welcome',
        title: 'Bienvenida',
        content: content,
        highlights: [
          NoteHighlightModel(
            start: content.indexOf('imágenes'),
            end: content.indexOf('imágenes') + 8,
            colorValue: 0xFFFFCC80,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final personal = NoteModel(
        id: 'personal',
        title: 'Mi recuerdo',
        content: 'Graba mis ideas en papel',
        createdAt: now,
        updatedAt: now,
      );
      final demo = NoteModel(
        id: 'note_voice',
        title: 'Recordatorio rápido de voz 🎙️',
        content:
            'Audio con los pendientes de la semana y detalles importantes que no quiero olvidar.',
        attachments: [
          NoteAttachmentModel(
            id: 'sample_audio_1',
            type: AttachmentType.audio,
            data: 'sample_audio_memo',
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'ink_notes_folders': '[]',
        'ink_notes_notes': jsonEncode([
          welcome.toMap(),
          personal.toMap(),
          demo.toMap(),
        ]),
      });
      final notes = NotesController();
      await notes.ready;
      final migrated = notes.notes.firstWhere((n) => n.id == 'note_welcome');
      expect(migrated.content, isNot(contains('Graba notas de voz')));
      expect(
        migrated.content.substring(
          migrated.highlights.single.start,
          migrated.highlights.single.end,
        ),
        'imágenes',
      );
      expect(notes.notes.any((n) => n.id == 'note_voice'), isFalse);
      expect(
        notes.notes.firstWhere((n) => n.id == 'personal').content,
        personal.content,
      );
      await notes.flushPendingChanges();
      notes.dispose();
    },
  );

  testWidgets(
    'legacy voice attachments keep their note without player or microphone',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final notes = NotesController();
      await tester.runAsync(() => notes.ready);
      final note = notes.createNote(
        title: 'Anterior',
        content: 'Mi texto se conserva',
        attachments: [
          NoteAttachmentModel(
            id: 'old_audio',
            type: AttachmentType.audio,
            data: 'audio_payload_old',
            createdAt: DateTime(2026),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: notes),
            ChangeNotifierProvider(create: (_) => ThemeController()),
          ],
          child: MaterialApp(home: NoteEditorScreen(noteId: note.id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Grabar nota de voz'), findsNothing);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byTooltip('Insertar imagen'), findsOneWidget);
      expect(find.byTooltip('Añadir boceto o dibujo'), findsOneWidget);
      expect(find.text('Mi texto se conserva'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(notes.flushPendingChanges);
      expect(
        notes.notes.firstWhere((n) => n.id == note.id).attachments.single.data,
        'audio_payload_old',
      );
      notes.dispose();
    },
  );
}
