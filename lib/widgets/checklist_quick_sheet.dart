import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/notes_controller.dart';
import '../controllers/theme_controller.dart';
import '../formatters/writer_text_formatter.dart';
import '../screens/note_editor_screen.dart';
import '../theme/app_theme.dart';

/// Panel rápido interactivo para marcar y desmarcar tareas desde el dashboard.
class ChecklistQuickSheet extends StatelessWidget {
  final String noteId;

  const ChecklistQuickSheet({super.key, required this.noteId});

  static Future<void> show(BuildContext context, {required String noteId}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChecklistQuickSheet(noteId: noteId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NotesController>(context);
    final theme = Provider.of<ThemeController>(context);
    final isDark = theme.isDarkMode;

    final note = controller.notes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) {
      return const SizedBox.shrink();
    }

    final items = WriterTextFormatter.parseChecklistItems(note.content);
    final checkedCount = items.where((i) => i.isChecked).length;
    final progress = items.isEmpty ? 0.0 : checkedCount / items.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.sheetRadius),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title.isNotEmpty ? note.title : 'Lista de tareas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$checkedCount de ${items.length} completadas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(noteId: note.id),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: theme.accentColor,
                  ),
                  label: Text(
                    'Editar',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: theme.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No hay tareas en esta nota.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, idx) {
                    final item = items[idx];
                    return Material(
                      color: theme.surfaceElevated.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.toggleChecklistLine(
                            note.id,
                            item.lineIndex,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.isChecked
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 21,
                                color: item.isChecked
                                    ? theme.accentColor
                                    : theme.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.text.isNotEmpty
                                      ? item.text
                                      : 'Tarea sin texto',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: item.isChecked
                                        ? theme.textSecondary
                                        : theme.textPrimary,
                                    decoration: item.isChecked
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    decorationColor: theme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
