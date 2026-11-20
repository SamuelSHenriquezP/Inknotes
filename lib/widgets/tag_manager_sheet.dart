import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/notes_controller.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';

/// Hoja modal para gestionar las #etiquetas de una nota.
class TagManagerSheet extends StatefulWidget {
  final String noteId;

  const TagManagerSheet({super.key, required this.noteId});

  static Future<void> show(BuildContext context, {required String noteId}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TagManagerSheet(noteId: noteId),
    );
  }

  @override
  State<TagManagerSheet> createState() => _TagManagerSheetState();
}

class _TagManagerSheetState extends State<TagManagerSheet> {
  final TextEditingController _tagCtrl = TextEditingController();

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTagsFromInput(NotesController controller, List<String> currentTags) {
    final raw = _tagCtrl.text.trim();
    if (raw.isEmpty) return;

    final parts = raw
        .split(RegExp(r'[,\n]+'))
        .map((e) => e.trim().replaceFirst(RegExp(r'^#+'), '').trim())
        .where((e) => e.isNotEmpty);

    if (parts.isEmpty) return;

    final updated = List<String>.from(currentTags)..addAll(parts);
    controller.setNoteTags(widget.noteId, updated);
    _tagCtrl.clear();
    HapticFeedback.selectionClick();
  }

  void _toggleTag(
    NotesController controller,
    List<String> currentTags,
    String tag,
  ) {
    HapticFeedback.selectionClick();
    final targetLower = tag.toLowerCase();
    final exists = currentTags.any((t) => t.toLowerCase() == targetLower);
    final updated = exists
        ? currentTags.where((t) => t.toLowerCase() != targetLower).toList()
        : (List<String>.from(currentTags)..add(tag));
    controller.setNoteTags(widget.noteId, updated);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NotesController>(context);
    final theme = Provider.of<ThemeController>(context);
    final isDark = theme.isDarkMode;

    final note = controller.notes.where((n) => n.id == widget.noteId).firstOrNull;
    if (note == null) {
      return const SizedBox.shrink();
    }

    final currentTags = note.tags;
    final allTags = controller.allTags;
    final suggestions = allTags
        .where(
          (t) => !currentTags.any((c) => c.toLowerCase() == t.toLowerCase()),
        )
        .toList();

    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + keyboardPadding),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.sheetRadius),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Etiquetas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Organiza y filtra esta nota con #etiquetas',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagCtrl,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ej. trabajo, urgente, ideas...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: theme.textSecondary.withValues(alpha: 0.55),
                          fontWeight: FontWeight.normal,
                        ),
                        prefixIcon: Icon(
                          Icons.tag_rounded,
                          size: 18,
                          color: theme.textSecondary,
                        ),
                        filled: true,
                        fillColor: theme.surfaceElevated.withValues(alpha: 0.65),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.accentColor,
                            width: 1.4,
                          ),
                        ),
                      ),
                      onSubmitted: (_) =>
                          _addTagsFromInput(controller, currentTags),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _addTagsFromInput(controller, currentTags),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: theme.onAccentColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Añadir',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'ETIQUETAS DE ESTA NOTA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (currentTags.isEmpty)
                Text(
                  'Sin etiquetas asignadas todavía.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.textSecondary.withValues(alpha: 0.75),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: currentTags.map((tag) {
                    return Chip(
                      label: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.onAccentColor,
                        ),
                      ),
                      backgroundColor: theme.accentColor,
                      deleteIcon: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: theme.onAccentColor,
                      ),
                      onDeleted: () => _toggleTag(controller, currentTags, tag),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'ETIQUETAS EXISTENTES',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.map((tag) {
                    return ActionChip(
                      label: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      avatar: Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: theme.textSecondary,
                      ),
                      backgroundColor:
                          theme.surfaceElevated.withValues(alpha: 0.7),
                      side: BorderSide(color: theme.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggleTag(controller, currentTags, tag),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textPrimary,
                    side: BorderSide(color: theme.borderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    'Listo',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
