import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/note_attachment_model.dart';
import '../formatters/writer_text_formatter.dart';
import '../formatters/highlighted_text_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/security_controller.dart';
import 'checklist_quick_sheet.dart';
import 'tag_manager_sheet.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final FolderModel? folder;
  final bool isDark;
  final bool isGrid;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final ValueChanged<int>? onToggleChecklistLine;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;

  const NoteCard({
    super.key,
    required this.note,
    this.folder,
    required this.isDark,
    this.isGrid = false,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    this.onToggleChecklistLine,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final bgCard = themeController.surfaceCard;
    final textPrimary = themeController.textPrimary;
    final textSecondary = themeController.textSecondary;
    final borderSubtle = themeController.borderSubtle;

    final wordCount = WriterTextFormatter.countWords(
      stripHighlightDelimiters(note.content),
    );
    final formattedDate = WriterTextFormatter.formatSpanishRelativeDate(
      note.updatedAt,
    );

    final hasAudio = note.attachments.any((a) => a.type == AttachmentType.audio);
    final hasDrawing = note.attachments.any((a) => a.type == AttachmentType.drawing);
    final hasImage = note.attachments.any((a) => a.type == AttachmentType.image);

    final securityController = Provider.of<SecurityController>(context);
    final hidePreview = securityController.hidePreviews;
    final accent = themeController.accentColor;

    final Widget cardContent = isGrid
        ? _buildGridCard(
            bgCard: bgCard,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderSubtle: borderSubtle,
            accent: accent,
            hidePreview: hidePreview,
            wordCount: wordCount,
            formattedDate: formattedDate,
            hasAudio: hasAudio,
            hasDrawing: hasDrawing,
            hasImage: hasImage,
            context: context,
          )
        : _buildListCard(
            bgCard: bgCard,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderSubtle: borderSubtle,
            accent: accent,
            hidePreview: hidePreview,
            wordCount: wordCount,
            formattedDate: formattedDate,
            hasAudio: hasAudio,
            hasDrawing: hasDrawing,
            hasImage: hasImage,
            context: context,
          );

    // Si está en modo selección, devolvemos la tarjeta directa sin drag
    if (isSelectionMode) {
      return cardContent;
    }

    // Envoltura para arrastrar la nota directamente a las carpetas
    return LongPressDraggable<NoteModel>(
      data: note,
      delay: const Duration(milliseconds: 220),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: isGrid ? 170 : 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white70 : Colors.black87,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title.isNotEmpty ? note.title : 'Nota sin título',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 13,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Suelta en una carpeta',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: cardContent,
      ),
      child: cardContent,
    );
  }

  Widget _buildHeaderActions({
    required BuildContext context,
    required Color accent,
    required Color textSecondary,
    required double iconSize,
  }) {
    if (isSelectionMode) {
      return Icon(
        isSelected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        size: iconSize + 5,
        color: isSelected ? accent : textSecondary.withValues(alpha: 0.45),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTogglePin,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              note.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              size: iconSize,
              color: note.isPinned
                  ? accent
                  : textSecondary.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: () => _showOptions(context),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.more_vert_rounded,
              size: iconSize + 1,
              color: textSecondary.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewContent({
    required BuildContext context,
    required ThemeController theme,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required bool hidePreview,
    required int maxChecklistLines,
    required int maxTextLines,
    required double fontSize,
  }) {
    if (note.content.isEmpty) {
      return const SizedBox.shrink();
    }

    if (hidePreview) {
      return Text(
        '••••  Contenido protegido',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
          color: textSecondary.withValues(alpha: 0.65),
        ),
      );
    }

    final checklistItems = WriterTextFormatter.parseChecklistItems(note.content);
    if (checklistItems.isNotEmpty) {
      final visible = checklistItems.take(maxChecklistLines).toList();
      final remaining = checklistItems.length - visible.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 2.5),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: (!isSelectionMode && onToggleChecklistLine != null)
                        ? () {
                            HapticFeedback.selectionClick();
                            onToggleChecklistLine!(item.lineIndex);
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 5, top: 1, bottom: 1),
                      child: Icon(
                        item.isChecked
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 14,
                        color: item.isChecked
                            ? accent
                            : textSecondary.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.text.isNotEmpty ? item.text : 'Tarea',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: item.isChecked
                            ? textSecondary.withValues(alpha: 0.65)
                            : textPrimary.withValues(alpha: 0.85),
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (remaining > 0)
            Text(
              '+$remaining más',
              style: TextStyle(
                fontSize: fontSize - 1,
                fontWeight: FontWeight.w600,
                color: textSecondary.withValues(alpha: 0.75),
              ),
            ),
        ],
      );
    }

    return Text.rich(
      buildHighlightedTextSpan(
        text: note.content,
        highlights: note.highlights,
        isDark: isDark,
        baseStyle: TextStyle(
          fontSize: fontSize,
          color: textSecondary,
          height: 1.35,
        ),
      ),
      maxLines: maxTextLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTagsAndChecklistChips({
    required BuildContext context,
    required ThemeController theme,
    required Color textSecondary,
    required Color accent,
    required bool hidePreview,
    required int maxTags,
  }) {
    final progress = !hidePreview
        ? WriterTextFormatter.checklistProgress(note.content)
        : (checked: 0, total: 0);
    final hasChecklist = progress.total > 0;
    final hasTags = note.tags.isNotEmpty;

    if (!hasChecklist && !hasTags) {
      return const SizedBox.shrink();
    }

    final visibleTags = note.tags.take(maxTags).toList();
    final extraTags = note.tags.length - visibleTags.length;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (hasChecklist)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isSelectionMode
                  ? null
                  : () => ChecklistQuickSheet.show(context, noteId: note.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 11,
                      color: accent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${progress.checked}/${progress.total}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...visibleTags.map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$tag',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
          ),
          if (extraTags > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+$extraTags',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Tarjeta de Nota Normal en Cuadrícula
  Widget _buildGridCard({
    required Color bgCard,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderSubtle,
    required Color accent,
    required bool hidePreview,
    required int wordCount,
    required String formattedDate,
    required bool hasAudio,
    required bool hasDrawing,
    required bool hasImage,
    required BuildContext context,
  }) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? accent
              : (note.isPinned
                  ? accent.withValues(alpha: 0.7)
                  : borderSubtle),
          width: isSelected ? 2.0 : (note.isPinned ? 1.6 : 1.1),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress ?? () => _showOptions(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fila superior: Título de la nota y Pin / Selección
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              note.title.isNotEmpty ? note.title : 'Nota sin título',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.3,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildHeaderActions(
                            context: context,
                            accent: accent,
                            textSecondary: textSecondary,
                            iconSize: 14,
                          ),
                        ],
                      ),

                      // Previsualización normal, discreta o checklist
                      if (note.content.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Flexible(
                          child: _buildPreviewContent(
                            context: context,
                            theme: theme,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            accent: accent,
                            hidePreview: hidePreview,
                            maxChecklistLines: 2,
                            maxTextLines: 3,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      _buildTagsAndChecklistChips(
                        context: context,
                        theme: theme,
                        textSecondary: textSecondary,
                        accent: accent,
                        hidePreview: hidePreview,
                        maxTags: 2,
                      ),
                    ],
                  ),
                ),

                // Fila inferior: adjuntos, palabras y fecha
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasAudio) ...[
                              Icon(Icons.mic_none_rounded, size: 12, color: textSecondary),
                              const SizedBox(width: 3),
                            ],
                            if (hasDrawing) ...[
                              Icon(Icons.gesture_rounded, size: 12, color: textSecondary),
                              const SizedBox(width: 3),
                            ],
                            if (hasImage) ...[
                              Icon(Icons.image_outlined, size: 12, color: textSecondary),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                '$wordCount pal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tarjeta de Nota Normal en Lista
  Widget _buildListCard({
    required Color bgCard,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderSubtle,
    required Color accent,
    required bool hidePreview,
    required int wordCount,
    required String formattedDate,
    required bool hasAudio,
    required bool hasDrawing,
    required bool hasImage,
    required BuildContext context,
  }) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? accent
              : (note.isPinned
                  ? accent.withValues(alpha: 0.7)
                  : borderSubtle),
          width: isSelected ? 2.0 : (note.isPinned ? 1.6 : 1.1),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress ?? () => _showOptions(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        note.title.isNotEmpty ? note.title : 'Nota sin título',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildHeaderActions(
                      context: context,
                      accent: accent,
                      textSecondary: textSecondary,
                      iconSize: 14.5,
                    ),
                  ],
                ),
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _buildPreviewContent(
                    context: context,
                    theme: theme,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    accent: accent,
                    hidePreview: hidePreview,
                    maxChecklistLines: 3,
                    maxTextLines: 2,
                    fontSize: 12.5,
                  ),
                ],
                _buildTagsAndChecklistChips(
                  context: context,
                  theme: theme,
                  textSecondary: textSecondary,
                  accent: accent,
                  hidePreview: hidePreview,
                  maxTags: 4,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasAudio) ...[
                          Icon(Icons.mic_none_rounded, size: 12, color: textSecondary),
                          const SizedBox(width: 3),
                        ],
                        if (hasDrawing) ...[
                          Icon(Icons.gesture_rounded, size: 12, color: textSecondary),
                          const SizedBox(width: 3),
                        ],
                        if (hasImage) ...[
                          Icon(Icons.image_outlined, size: 12, color: textSecondary),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          '$wordCount palabras',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    final hasChecklist = WriterTextFormatter.hasChecklist(note.content);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  note.isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  color: theme.textPrimary,
                ),
                title: Text(
                  note.isPinned ? 'Desfijar de arriba' : 'Fijar arriba',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onTogglePin();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.tag_rounded,
                  color: theme.textPrimary,
                ),
                title: Text(
                  'Gestionar etiquetas',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
                subtitle: note.tags.isNotEmpty
                    ? Text(
                        note.tags.map((t) => '#$t').join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  TagManagerSheet.show(context, noteId: note.id);
                },
              ),
              if (hasChecklist)
                ListTile(
                  leading: Icon(
                    Icons.checklist_rounded,
                    color: theme.textPrimary,
                  ),
                  title: Text(
                    'Checklist rápido',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    ChecklistQuickSheet.show(context, noteId: note.id);
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Mover a la papelera',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          '¿Mover nota a la papelera?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        content: Text(
          'Podrás restaurarla desde la papelera cuando lo necesites.',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: theme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text(
              'Mover a papelera',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
