import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../controllers/notes_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/editor_undo_manager.dart';
import '../models/note_model.dart';
import '../models/note_attachment_model.dart';
import '../formatters/writer_text_formatter.dart';
import '../formatters/highlighted_text_controller.dart';
import '../widgets/drawing_sheet.dart';
import '../widgets/voice_memo_sheet.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/theme_sheet.dart';
import '../widgets/note_history_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NoteEditorScreen extends StatefulWidget {
  final String noteId;

  const NoteEditorScreen({super.key, required this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late HighlightedTextEditingController _contentCtrl;
  final FocusNode _contentFocus = FocusNode();
  late final EditorUndoManager _undoManager;
  Timer? _typingDebounce;
  bool _isApplyingUndoRedo = false;

  bool _initialized = false;
  NoteModel? _note;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _contentCtrl = HighlightedTextEditingController();
    _undoManager = EditorUndoManager();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final controller = Provider.of<NotesController>(context, listen: false);
      final themeController = Provider.of<ThemeController>(context, listen: false);
      _note = controller.notes.where((n) => n.id == widget.noteId).firstOrNull;
      if (_note != null) {
        _titleCtrl.text = _note!.title;
        
        // Limpieza automática de delimitadores residuales (==, **, *) y restauración de estilos limpios
        if (_note!.content.contains('==') || _note!.content.contains('*')) {
          final cleaned = cleanMarkdownDelimiters(
            _note!.content,
            existing: _note!.highlights,
          );
          _note = _note!.copyWith(
            content: cleaned.text,
            highlights: cleaned.highlights,
          );
          controller.updateNote(_note!);
        }

        _contentCtrl.text = _note!.content;
        _contentCtrl.setHighlights(_note!.highlights);
        _contentCtrl.setIsDark(themeController.isDarkMode);

        _undoManager.initialize(EditorHistoryEntry(
          title: _titleCtrl.text,
          content: _contentCtrl.text,
          selection: _contentCtrl.selection,
          highlights: List.from(_contentCtrl.highlights),
        ));
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _undoManager.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onTextChanged(NotesController controller, {bool immediate = false}) {
    if (_note == null || _isApplyingUndoRedo) return;
    final updated = _note!.copyWith(
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      highlights: _contentCtrl.highlights,
    );
    _note = updated;
    controller.updateNote(updated);

    final currentEntry = EditorHistoryEntry(
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      selection: _contentCtrl.selection,
      highlights: List.from(_contentCtrl.highlights),
    );

    if (immediate) {
      _typingDebounce?.cancel();
      _undoManager.pushSnapshot(currentEntry);
    } else {
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(milliseconds: 380), () {
        _undoManager.pushSnapshot(currentEntry);
      });
    }
  }

  void _handleUndo(NotesController controller) {
    _typingDebounce?.cancel();
    // Guardar el estado actual antes de deshacer si había algo pendiente de tipeo
    final currentEntry = EditorHistoryEntry(
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      selection: _contentCtrl.selection,
      highlights: List.from(_contentCtrl.highlights),
    );
    _undoManager.pushSnapshot(currentEntry);

    final previous = _undoManager.undo();
    if (previous == null) return;

    HapticFeedback.lightImpact();
    _applyHistoryEntry(previous, controller);
  }

  void _handleRedo(NotesController controller) {
    _typingDebounce?.cancel();
    final next = _undoManager.redo();
    if (next == null) return;

    HapticFeedback.lightImpact();
    _applyHistoryEntry(next, controller);
  }

  void _applyHistoryEntry(EditorHistoryEntry entry, NotesController controller) {
    _isApplyingUndoRedo = true;
    _titleCtrl.text = entry.title;
    _contentCtrl.text = entry.content;
    _contentCtrl.setHighlights(entry.highlights);

    final safeOffset = entry.selection.baseOffset.clamp(0, entry.content.length);
    final safeExtent = entry.selection.extentOffset.clamp(0, entry.content.length);
    _contentCtrl.selection = TextSelection(
      baseOffset: safeOffset,
      extentOffset: safeExtent,
    );

    if (_note != null) {
      final updated = _note!.copyWith(
        title: entry.title,
        content: entry.content,
        highlights: entry.highlights,
        updatedAt: DateTime.now(),
      );
      _note = updated;
      controller.updateNote(updated);
      setState(() {});
    }

    _isApplyingUndoRedo = false;
  }

  void _cleanupIfEmpty(NotesController controller) {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (_note != null &&
        title.isEmpty &&
        content.isEmpty &&
        _note!.attachments.isEmpty) {
      controller.deleteNote(_note!.id);
    } else if (title.isNotEmpty || content.isNotEmpty) {
      controller.addHistorySnapshot(widget.noteId);
    }
  }

  void _insertPrefix(String prefix, NotesController controller) {
    final selection = _contentCtrl.selection;
    final text = _contentCtrl.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final needLeadingNewline =
        (start > 0 && !text.substring(0, start).endsWith('\n'));
    final insertion = '${needLeadingNewline ? '\n' : ''}$prefix';
    final newText = text.replaceRange(start, end, insertion);

    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    _onTextChanged(controller, immediate: true);
  }

  void _toggleBold(NotesController controller) {
    HapticFeedback.lightImpact();
    _contentCtrl.toggleBold();
    _onTextChanged(controller, immediate: true);
  }

  void _toggleItalic(NotesController controller) {
    HapticFeedback.lightImpact();
    _contentCtrl.toggleItalic();
    _onTextChanged(controller, immediate: true);
  }

  void _autoFormatParagraphs(NotesController controller) {
    HapticFeedback.mediumImpact();
    final oldText = _contentCtrl.text;
    final formatted = WriterTextFormatter.formatParagraphs(oldText);

    if (formatted == oldText) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los párrafos ya tienen el formato correcto'),
          duration: Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentOffset = _contentCtrl.selection.isValid
        ? _contentCtrl.selection.start.clamp(0, formatted.length)
        : formatted.length;

    _contentCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: currentOffset),
    );
    _onTextChanged(controller, immediate: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Párrafos separados automáticamente'),
        duration: Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage(NotesController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        final path = result.files.first.path!;
        final attachment = NoteAttachmentModel(
          id: 'img_${DateTime.now().millisecondsSinceEpoch}',
          type: AttachmentType.image,
          data: path,
          name: result.files.first.name,
          createdAt: DateTime.now(),
        );
        controller.addAttachment(widget.noteId, attachment);
        setState(() {
          _note = controller.notes
              .where((n) => n.id == widget.noteId)
              .firstOrNull;
        });
      }
    } catch (_) {}
  }

  Future<void> _recordVoiceMemo(NotesController controller, bool isDark) async {
    final attachment = await VoiceMemoSheet.show(context, isDark: isDark);
    if (attachment != null && mounted) {
      controller.addAttachment(widget.noteId, attachment);
      setState(() {
        _note = controller.notes
            .where((n) => n.id == widget.noteId)
            .firstOrNull;
      });
    }
  }

  Future<void> _openDrawingSheet(
    NotesController controller,
    bool isDark,
  ) async {
    final attachment = await DrawingSheet.show(context, isDark: isDark);
    if (attachment != null && mounted) {
      controller.addAttachment(widget.noteId, attachment);
      setState(() {
        _note = controller.notes
            .where((n) => n.id == widget.noteId)
            .firstOrNull;
      });
    }
  }

  void _showHighlightColorPicker(NotesController controller, bool isDark) {
    final colorOptions = [
      (color: const Color(0xFFFFE082), tag: 'yellow', label: 'Ámbar'),
      (color: const Color(0xFFA5D6A7), tag: 'mint', label: 'Menta'),
      (color: const Color(0xFF90CAF9), tag: 'sky', label: 'Cielo'),
      (color: const Color(0xFFCE93D8), tag: 'lavender', label: 'Lila'),
      (color: const Color(0xFFFFAB91), tag: 'peach', label: 'Melocotón'),
    ];

    final theme = Provider.of<ThemeController>(context, listen: false);
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
              Text(
                'Resaltar texto',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: theme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: colorOptions.map((opt) {
                  return GestureDetector(
                    onTap: () {
                      _contentCtrl.applyHighlightColor(opt.color.toARGB32());
                      _onTextChanged(controller, immediate: true);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: opt.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: opt.color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () {
                  final text = _contentCtrl.text;
                  final stripped = stripHighlightDelimiters(text);
                  _contentCtrl.value = TextEditingValue(
                    text: stripped,
                    selection: TextSelection.collapsed(
                      offset: _contentCtrl.selection.start.clamp(0, stripped.length),
                    ),
                  );
                  controller.updateHighlights(widget.noteId, []);
                  _onTextChanged(controller, immediate: true);
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.format_color_reset_rounded,
                  size: 18,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Quitar todos los resaltados',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  void _switchFolder(NotesController controller, bool isDark) {
    final theme = Provider.of<ThemeController>(context, listen: false);
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
              Text(
                'Mover a carpeta',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: theme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              // Opción para dejar la nota en la raíz (sin carpeta)
              ListTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: theme.textPrimary,
                    size: 18,
                  ),
                ),
                title: Text(
                  'Notas principales (sin carpeta)',
                  style: TextStyle(
                    fontWeight: (_note?.folderId == null || _note!.folderId!.isEmpty)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: theme.textPrimary,
                  ),
                ),
                trailing: (_note?.folderId == null || _note!.folderId!.isEmpty)
                    ? const Icon(Icons.check_rounded, size: 20)
                    : null,
                onTap: () {
                  controller.moveNoteToFolder(widget.noteId, null);
                  setState(() {
                    _note = controller.notes
                        .where((n) => n.id == widget.noteId)
                        .firstOrNull;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ...controller.folders.map((f) {
                final isCurrent = _note?.folderId == f.id;
                return ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      f.iconData,
                      color: theme.textPrimary,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    f.name,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: theme.textPrimary,
                    ),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check_rounded, size: 20)
                      : null,
                  onTap: () {
                    controller.moveNoteToFolder(widget.noteId, f.id);
                    setState(() {
                      _note = controller.notes
                          .where((n) => n.id == widget.noteId)
                          .firstOrNull;
                    });
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteNote(
    BuildContext context,
    NotesController notesController,
    bool isDark,
  ) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          '¿Eliminar esta nota?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        content: Text(
          'Esta acción no se puede deshacer.',
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
              notesController.deleteNote(widget.noteId);
              Navigator.of(context).pop();
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

  void _shareNote() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final text = '${title.isNotEmpty ? '$title\n\n' : ''}$content';
    if (text.isNotEmpty) {
      SharePlus.instance.share(ShareParams(text: text));
    }
  }

  void _showMoreNoteOptions(
    BuildContext context,
    NotesController notesController,
    NoteModel note,
    bool isDark,
    ThemeController themeController,
  ) {
    final currentFolder = notesController.getFolder(note.folderId);
    final textPrimary = themeController.textPrimary;
    final textSecondary = themeController.textSecondary;
    final borderSubtle = themeController.borderSubtle;

    showModalBottomSheet(
      context: context,
      backgroundColor: themeController.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.history_rounded, size: 19, color: textPrimary),
                  ),
                  title: Text(
                    'Historial de versiones',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Restaura versiones previas guardadas',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    NoteHistorySheet.show(context, noteId: note.id);
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.drive_file_move_outlined, size: 19, color: textPrimary),
                  ),
                  title: Text(
                    'Mover a carpeta',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    currentFolder != null
                        ? 'Actualmente en "${currentFolder.name}"'
                        : 'Actualmente en notas principales',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _switchFolder(notesController, isDark);
                  },
                ),
                Divider(color: borderSubtle, height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: Colors.redAccent,
                    ),
                  ),
                  title: const Text(
                    'Eliminar nota',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  subtitle: Text(
                    'Esta acción no se puede deshacer',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDeleteNote(context, notesController, isDark);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final notesController = Provider.of<NotesController>(context);
    final isDark = themeController.isDarkMode;

    final currentNote =
        notesController.notes.where((n) => n.id == widget.noteId).firstOrNull ??
        _note;
    if (currentNote == null) {
      return const Scaffold(body: Center(child: Text('Nota no encontrada')));
    }

    // Sincronizar controladores si se restauró una versión desde el historial
    if (currentNote.title != _titleCtrl.text && !_titleCtrl.selection.isValid) {
      _titleCtrl.text = currentNote.title;
    }
    if (currentNote.content != _contentCtrl.text && !_contentFocus.hasFocus) {
      _contentCtrl.text = currentNote.content;
      _contentCtrl.setHighlights(currentNote.highlights);
    }

    final currentFolder = notesController.getFolder(currentNote.folderId);
    final textPrimary = themeController.textPrimary;
    final textSecondary = themeController.textSecondary;
    final borderSubtle = themeController.borderSubtle;
    final bgPrimary = themeController.bgPrimary;
    final bgCard = themeController.surfaceCard;

    final wordCount = WriterTextFormatter.countWords(
      stripHighlightDelimiters(_contentCtrl.text),
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        _cleanupIfEmpty(notesController);
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
            if (_undoManager.canUndo) _handleUndo(notesController);
          },
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
            if (_undoManager.canRedo) _handleRedo(notesController);
          },
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
            if (_undoManager.canRedo) _handleRedo(notesController);
          },
        },
        child: Scaffold(
          backgroundColor: bgPrimary,
          body: SafeArea(
          child: Column(
            children: [
              // Barra superior limpia, espaciosa y minimalista
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: borderSubtle.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 21),
                      tooltip: 'Volver a notas',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),

                    // Selector de Carpeta en barra superior (Estilo chip compacto y elegante)
                    InkWell(
                      onTap: () => _switchFolder(notesController, isDark),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: themeController.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              currentFolder?.iconData ?? Icons.description_outlined,
                              size: 13.5,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 65),
                              child: Text(
                                currentFolder?.name ?? 'Notas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: textSecondary.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Selector de Diseño / Temas & Fuentes
                    IconButton(
                      icon: const Icon(Icons.palette_outlined, size: 20),
                      tooltip: 'Diseño & Tipografía',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ThemeSheet.show(context),
                    ),

                    // Pin toggle
                    IconButton(
                      icon: Icon(
                        currentNote.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        size: 19,
                        color: currentNote.isPinned
                            ? themeController.accentColor
                            : textSecondary,
                      ),
                      tooltip: currentNote.isPinned
                          ? 'Desfijar'
                          : 'Fijar arriba',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          notesController.togglePin(currentNote.id),
                    ),

                    // Share button
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 19),
                      tooltip: 'Compartir nota',
                      visualDensity: VisualDensity.compact,
                      onPressed: _shareNote,
                    ),

                    // Más opciones (Historial, Mover a carpeta, Eliminar)
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      tooltip: 'Más opciones',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showMoreNoteOptions(
                        context,
                        notesController,
                        currentNote,
                        isDark,
                        themeController,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic),

              // Cuerpo del editor
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  children: [
                    // Campo de Título
                    TextField(
                      controller: _titleCtrl,
                      onChanged: (_) => _onTextChanged(notesController),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Título de la nota...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: textSecondary.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Adjuntos Multimedia
                    if (currentNote.attachments.isNotEmpty) ...[
                      ...currentNote.attachments.map((att) {
                        if (att.type == AttachmentType.audio) {
                          return AudioPlayerWidget(
                            attachment: att,
                            isDark: isDark,
                            onDelete: () => notesController.removeAttachment(
                              currentNote.id,
                              att.id,
                            ),
                          );
                        } else if (att.type == AttachmentType.drawing) {
                          return _buildDrawingCard(
                            att,
                            currentNote,
                            notesController,
                            isDark,
                            bgCard,
                            borderSubtle,
                          );
                        } else if (att.type == AttachmentType.image) {
                          return _buildImageCard(
                            att,
                            currentNote,
                            notesController,
                            isDark,
                            bgCard,
                            borderSubtle,
                          );
                        }
                        return const SizedBox();
                      }),
                      const SizedBox(height: 12),
                    ],

                    // Campo de Contenido con tipografía y tamaño dinámicos
                    TextField(
                      controller: _contentCtrl,
                      focusNode: _contentFocus,
                      onChanged: (_) => _onTextChanged(notesController),
                      maxLines: null,
                      style: themeController.fontFamily.textStyle(
                        fontSize: themeController.fontSize,
                        height: 1.65,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Comienza a escribir aquí...',
                        hintStyle: themeController.fontFamily.textStyle(
                          fontSize: themeController.fontSize,
                          color: textSecondary.withValues(alpha: 0.4),
                          height: 1.65,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 50.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),

              // Barra inferior de herramientas y métricas (Horizontal scroll para evitar desbordes con teclado)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: bgCard,
                  border: Border(
                    top: BorderSide(color: borderSubtle, width: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Deshacer (Undo)
                            ListenableBuilder(
                              listenable: _undoManager,
                              builder: (context, _) {
                                return IconButton(
                                  icon: Icon(
                                    Icons.undo_rounded,
                                    size: 20,
                                    color: _undoManager.canUndo
                                        ? textPrimary
                                        : textSecondary.withValues(alpha: 0.3),
                                  ),
                                  tooltip: 'Deshacer (Ctrl+Z)',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _undoManager.canUndo
                                      ? () => _handleUndo(notesController)
                                      : null,
                                );
                              },
                            ),
                            // Rehacer (Redo)
                            ListenableBuilder(
                              listenable: _undoManager,
                              builder: (context, _) {
                                return IconButton(
                                  icon: Icon(
                                    Icons.redo_rounded,
                                    size: 20,
                                    color: _undoManager.canRedo
                                        ? textPrimary
                                        : textSecondary.withValues(alpha: 0.3),
                                  ),
                                  tooltip: 'Rehacer (Ctrl+Y)',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _undoManager.canRedo
                                      ? () => _handleRedo(notesController)
                                      : null,
                                );
                              },
                            ),
                            Container(
                              height: 18,
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              color: borderSubtle,
                            ),

                            // Negrita (B)
                            IconButton(
                              icon: const Icon(
                                Icons.format_bold_rounded,
                                size: 20,
                              ),
                              tooltip: 'Negrita',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _toggleBold(notesController),
                            ),
                            // Cursiva (I)
                            IconButton(
                              icon: const Icon(
                                Icons.format_italic_rounded,
                                size: 20,
                              ),
                              tooltip: 'Cursiva',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _toggleItalic(notesController),
                            ),
                            // Resaltador
                            IconButton(
                              icon: Icon(
                                Icons.border_color_rounded,
                                size: 19,
                                color: Colors.amber.shade700,
                              ),
                              tooltip: 'Resaltar texto',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _showHighlightColorPicker(notesController, isDark),
                            ),
                            // Auto-formatear párrafos
                            IconButton(
                              icon: Icon(
                                Icons.auto_fix_high_rounded,
                                size: 19,
                                color: textPrimary,
                              ),
                              tooltip: 'Separar párrafos automáticamente',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _autoFormatParagraphs(notesController),
                            ),
                            // Viñeta
                            IconButton(
                              icon: Icon(
                                Icons.format_list_bulleted_rounded,
                                size: 19,
                                color: textSecondary,
                              ),
                              tooltip: 'Lista con viñetas',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _insertPrefix('• ', notesController),
                            ),
                            // Lista de tareas / Casilla
                            IconButton(
                              icon: Icon(
                                Icons.check_box_outlined,
                                size: 19,
                                color: textSecondary,
                              ),
                              tooltip: 'Casilla de verificación',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _insertPrefix('☐ ', notesController),
                            ),
                            // Nota de voz
                            IconButton(
                              icon: Icon(
                                Icons.mic_none_rounded,
                                size: 20,
                                color: textSecondary,
                              ),
                              tooltip: 'Grabar nota de voz',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _recordVoiceMemo(notesController, isDark),
                            ),
                            // Dibujo a mano
                            IconButton(
                              icon: Icon(
                                Icons.gesture_rounded,
                                size: 20,
                                color: textSecondary,
                              ),
                              tooltip: 'Añadir boceto o dibujo',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _openDrawingSheet(notesController, isDark),
                            ),
                            // Imagen
                            IconButton(
                              icon: Icon(
                                Icons.image_outlined,
                                size: 20,
                                color: textSecondary,
                              ),
                              tooltip: 'Insertar imagen',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _pickImage(notesController),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      height: 18,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: borderSubtle,
                    ),

                    // Contador de palabras conciso (nunca desborda con teclado activo)
                    Text(
                      '$wordCount pal',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDrawingCard(
    NoteAttachmentModel att,
    NoteModel note,
    NotesController controller,
    bool isDark,
    Color bgCard,
    Color borderSubtle,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: borderSubtle, width: 1.2),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(att.data),
                fit: BoxFit.contain,
                width: double.infinity,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => controller.removeAttachment(note.id, att.id),
              tooltip: 'Eliminar dibujo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(
    NoteAttachmentModel att,
    NoteModel note,
    NotesController controller,
    bool isDark,
    Color bgCard,
    Color borderSubtle,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: borderSubtle, width: 1.2),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(att.data),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Imagen adjunta'),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => controller.removeAttachment(note.id, att.id),
              tooltip: 'Eliminar imagen',
            ),
          ),
        ],
      ),
    );
  }
}
