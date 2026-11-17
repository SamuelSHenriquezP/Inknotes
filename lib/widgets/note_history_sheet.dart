import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/note_history_model.dart';
import '../controllers/notes_controller.dart';
import '../controllers/theme_controller.dart';
import '../formatters/writer_text_formatter.dart';

class NoteHistorySheet extends StatelessWidget {
  final String noteId;

  const NoteHistorySheet({super.key, required this.noteId});

  static Future<void> show(BuildContext context, {required String noteId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteHistorySheet(noteId: noteId),
    );
  }

  void _confirmRestore(
    BuildContext context,
    NotesController controller,
    NoteHistorySnapshot snapshot,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '¿Restaurar esta versión?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        content: Text(
          'Tu contenido actual se guardará en el historial y se recuperará la versión del ${WriterTextFormatter.formatSpanishRelativeDate(snapshot.timestamp)}.',
          style: TextStyle(color: textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.restoreSnapshot(noteId, snapshot);
              Navigator.of(ctx).pop(); // Cierra diálogo
              Navigator.of(context).pop(); // Cierra hoja de historial
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: theme.onAccentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text(
              'Restaurar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSnapshot(
    BuildContext context,
    NotesController controller,
    int index,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '¿Eliminar esta versión?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        content: Text(
          'Esta versión se eliminará permanentemente del historial de esta nota.',
          style: TextStyle(color: textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteHistorySnapshot(noteId, index);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(
    BuildContext context,
    NotesController controller,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '¿Borrar todo el historial?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        content: Text(
          'Se eliminarán todas las versiones guardadas de esta nota. La nota actual no se modificará.',
          style: TextStyle(color: textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.clearHistory(noteId);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text(
              'Borrar todo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NotesController>(context);
    final themeController = Provider.of<ThemeController>(context);
    final isDark = themeController.isDarkMode;

    final bgSheet = themeController.surfaceCard;
    final textPrimary = themeController.textPrimary;
    final textSecondary = themeController.textSecondary;
    final borderSubtle = themeController.borderSubtle;
    final accent = themeController.accentColor;

    final note = controller.notes.where((n) => n.id == noteId).firstOrNull;
    final history = note?.history ?? <NoteHistorySnapshot>[];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: bgSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Notch
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial de Versiones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${history.length} punto(s) de restauración',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (history.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Borrar todo el historial',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmClearHistory(
                          context,
                          controller,
                          isDark,
                          textPrimary,
                          textSecondary,
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        controller.addHistorySnapshot(noteId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Punto de restauración guardado'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                      label: const Text(
                        'Guardar punto',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 18),

            // Lista de Versiones
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 42,
                            color: textSecondary.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sin historial previo aún',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Las versiones se registrarán automáticamente al editar o pulsar "Guardar punto"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final snapshot = history[index];
                        final formattedDate =
                            WriterTextFormatter.formatSpanishRelativeDate(
                          snapshot.timestamp,
                        );

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: themeController.surfaceElevated.withValues(alpha: 0.6),
                            borderRadius:
                                BorderRadius.circular(AppTheme.cardRadius),
                            border: Border.all(color: borderSubtle, width: 0.9),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 15,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${snapshot.wordCount} palabras',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (snapshot.title.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  snapshot.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                              if (snapshot.content.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  snapshot.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    tooltip: 'Eliminar esta versión',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _confirmDeleteSnapshot(
                                      context,
                                      controller,
                                      index,
                                      isDark,
                                      textPrimary,
                                      textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  OutlinedButton.icon(
                                    onPressed: () => _confirmRestore(
                                      context,
                                      controller,
                                      snapshot,
                                      isDark,
                                      textPrimary,
                                      textSecondary,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textPrimary,
                                      side: BorderSide(color: borderSubtle),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.buttonRadius,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.restore_page_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Restaurar versión',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
