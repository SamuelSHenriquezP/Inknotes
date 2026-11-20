import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/notes_controller.dart';
import '../controllers/security_controller.dart';
import '../controllers/theme_controller.dart';
import '../formatters/writer_text_formatter.dart';
import '../models/note_model.dart';
import '../theme/app_theme.dart';

/// Pantalla de Papelera temporal recuperable para restaurar o eliminar definitivamente notas.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  static Future<void> open(BuildContext context) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => const TrashScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0.0),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _confirmPermanentDelete(
    BuildContext context,
    NotesController controller,
    ThemeController theme,
    NoteModel note,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          '¿Eliminar definitivamente?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        content: Text(
          'Esta nota se borrará de forma permanente y no podrá recuperarse.',
          style: TextStyle(color: theme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: theme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.permanentlyDeleteNote(note.id);
              _showSnack(context, 'Nota eliminada definitivamente');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
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

  void _confirmEmptyTrash(
    BuildContext context,
    NotesController controller,
    ThemeController theme,
    int count,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          '¿Vaciar papelera?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        content: Text(
          'Se eliminarán definitivamente $count ${count == 1 ? 'nota' : 'notas'} de la papelera.',
          style: TextStyle(color: theme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: theme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.emptyTrash();
              _showSnack(context, 'Papelera vaciada');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text(
              'Vaciar papelera',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NotesController>(context);
    final theme = Provider.of<ThemeController>(context);
    final security = Provider.of<SecurityController>(context);
    final isDark = theme.isDarkMode;

    final trashed = controller.trashedNotes;

    return Scaffold(
      backgroundColor: theme.bgPrimary,
      appBar: AppBar(
        backgroundColor: theme.bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Papelera',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            if (trashed.isNotEmpty)
              Text(
                '${trashed.length} ${trashed.length == 1 ? 'nota eliminada' : 'notas eliminadas'}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: theme.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          if (trashed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: () => _confirmEmptyTrash(
                  context,
                  controller,
                  theme,
                  trashed.length,
                ),
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Vaciar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: trashed.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 52,
                        color: theme.textSecondary.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'La papelera está vacía',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Las notas que elimines aparecerán aquí para que puedas restaurarlas o borrarlas definitivamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                physics: const BouncingScrollPhysics(),
                itemCount: trashed.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final note = trashed[index];
                  final deletedLabel = note.deletedAt != null
                      ? WriterTextFormatter.formatSpanishRelativeDate(
                          note.deletedAt!,
                        )
                      : '';
                  final folder = controller.getFolder(note.folderId);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.borderSubtle, width: 1.0),
                      boxShadow: AppTheme.getSoftShadow(isDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                note.title.isNotEmpty
                                    ? note.title
                                    : 'Nota sin título',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (folder != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  folder.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (note.content.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            security.hidePreviews
                                ? '••••  Contenido protegido'
                                : note.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: security.hidePreviews
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: theme.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (note.tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: note.tags.take(4).map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Eliminada: $deletedLabel',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.textSecondary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_forever_outlined,
                                    size: 19,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Eliminar definitivamente',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmPermanentDelete(
                                    context,
                                    controller,
                                    theme,
                                    note,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    controller.restoreNote(note.id);
                                    _showSnack(context, 'Nota restaurada');
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.textPrimary,
                                    side: BorderSide(color: theme.borderSubtle),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.buttonRadius,
                                      ),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.restore_from_trash_rounded,
                                    size: 16,
                                    color: theme.accentColor,
                                  ),
                                  label: const Text(
                                    'Restaurar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
