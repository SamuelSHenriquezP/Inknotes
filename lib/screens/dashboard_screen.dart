import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/app_theme.dart';
import '../controllers/notes_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../models/note_attachment_model.dart';
import '../formatters/writer_text_formatter.dart';
import '../widgets/note_card.dart';
import '../widgets/voice_memo_sheet.dart';
import '../widgets/drawing_sheet.dart';
import '../widgets/global_search_sheet.dart';
import '../widgets/sort_filter_sheet.dart';
import 'note_editor_screen.dart';
import 'options_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _folderNameCtrl = TextEditingController();
  late AnimationController _fabAnimController;
  late Animation<double> _rotateAnim;
  bool _isFabOpen = false;

  final Set<String> _selectedNoteIds = {};
  bool get _isSelectionMode => _selectedNoteIds.isNotEmpty;

  void _toggleNoteSelection(String noteId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  void _selectAllNotes(List<NoteModel> notes) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedNoteIds.length == notes.length) {
        _selectedNoteIds.clear();
      } else {
        _selectedNoteIds.addAll(notes.map((n) => n.id));
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedNoteIds.clear();
    });
  }

  void _confirmBatchDelete(BuildContext context, NotesController controller, bool isDark) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    final count = _selectedNoteIds.length;
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          count == 1 ? '¿Eliminar 1 nota?' : '¿Eliminar $count notas?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        content: Text(
          'Esta acción no se puede deshacer. Las notas seleccionadas se eliminarán permanentemente.',
          style: TextStyle(
            color: textSecondary,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final idsToDelete = Set<String>.from(_selectedNoteIds);
              _clearSelection();
              controller.deleteNotes(idsToDelete);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(count == 1 ? '1 nota eliminada' : '$count notas eliminadas'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadius)),
            ),
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showBatchMoveSheet(BuildContext context, NotesController controller, bool isDark) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    final count = _selectedNoteIds.length;
    final bgCard = theme.surfaceCard;
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;
    final borderSubtle = theme.borderSubtle;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mover $count ${count == 1 ? "nota" : "notas"} a...',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Selecciona la carpeta de destino',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Divider(color: borderSubtle, height: 1),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.home_outlined, size: 20, color: textPrimary),
                  ),
                  title: Text(
                    'Notas principales (Sin carpeta)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  onTap: () {
                    final idsToMove = Set<String>.from(_selectedNoteIds);
                    _clearSelection();
                    controller.moveNotesToFolder(idsToMove, null);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(count == 1 ? 'Nota movida a notas principales' : '$count notas movidas a notas principales'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ...controller.folders.map((f) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(f.iconData, size: 20, color: textPrimary),
                  ),
                  title: Text(
                    f.name,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  subtitle: Text(
                    '${controller.getCountForFolder(f.id)} notas',
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                  ),
                  onTap: () {
                    final idsToMove = Set<String>.from(_selectedNoteIds);
                    _clearSelection();
                    controller.moveNotesToFolder(idsToMove, f.id);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(count == 1 ? 'Nota movida a "${f.name}"' : '$count notas movidas a "${f.name}"'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                )),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _rotateAnim = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    _folderNameCtrl.dispose();
    super.dispose();
  }

  void _toggleFab() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabAnimController.forward();
      } else {
        _fabAnimController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_isFabOpen) {
      setState(() {
        _isFabOpen = false;
        _fabAnimController.reverse();
      });
    }
  }

  void _openEditor(BuildContext context, NoteModel note) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            NoteEditorScreen(noteId: note.id),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _createNote(
    BuildContext context,
    NotesController controller, {
    List<NoteAttachmentModel>? attachments,
  }) {
    HapticFeedback.lightImpact();
    final newNote = controller.createNote(attachments: attachments);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            NoteEditorScreen(noteId: newNote.id),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _quickVoiceNote(
    BuildContext context,
    NotesController controller,
    bool isDark,
  ) async {
    final attachment = await VoiceMemoSheet.show(context, isDark: isDark);
    if (attachment != null && context.mounted) {
      _createNote(context, controller, attachments: [attachment]);
    }
  }

  Future<void> _quickDrawingNote(
    BuildContext context,
    NotesController controller,
    bool isDark,
  ) async {
    final attachment = await DrawingSheet.show(context, isDark: isDark);
    if (attachment != null && context.mounted) {
      _createNote(context, controller, attachments: [attachment]);
    }
  }

  Future<void> _quickImageNote(
    BuildContext context,
    NotesController controller,
  ) async {
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
        if (context.mounted) {
          _createNote(context, controller, attachments: [attachment]);
        }
      }
    } catch (_) {}
  }

  void _showCreateFolderSheet(
    BuildContext context,
    NotesController controller,
    bool isDark,
  ) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;
    final borderSubtle = theme.borderSubtle;
    final bgCard = theme.surfaceCard;

    _folderNameCtrl.clear();
    int selectedIconCode = 0xe2a3; // Ícono de carpeta por defecto

    final availableIcons = const [
      {'name': 'Carpeta', 'code': 0xe2a3},
      {'name': 'Ideas', 'code': 0xe362},
      {'name': 'Personal', 'code': 0xe491},
      {'name': 'Trabajo', 'code': 0xe6f2},
      {'name': 'Lectura', 'code': 0xe14d},
      {'name': 'Favorito', 'code': 0xe5f9},
      {'name': 'Corazón', 'code': 0xe87d},
      {'name': 'Compras', 'code': 0xe59c},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final keyboardPadding = MediaQuery.of(ctx).viewInsets.bottom;
          final currentIconData = getFolderIconData(selectedIconCode);

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + keyboardPadding),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderSubtle, width: 1),
                        ),
                        child: Icon(currentIconData, size: 22, color: textPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nueva Carpeta',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Organiza tus notas en un nuevo espacio',
                              style: TextStyle(fontSize: 12.5, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'NOMBRE DE LA CARPETA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _folderNameCtrl,
                    autofocus: true,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ej. Proyectos, Finanzas, Ideas...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: textSecondary.withValues(alpha: 0.5),
                        fontWeight: FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderSubtle, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderSubtle, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: textPrimary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (val) {
                      final name = val.trim();
                      if (name.isNotEmpty) {
                        controller.addFolder(
                          name: name,
                          colorValue: 0xFF111111,
                          iconCode: selectedIconCode,
                        );
                        Navigator.of(ctx).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ICONO REPRESENTATIVO',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: availableIcons.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final item = availableIcons[index];
                        final code = item['code'] as int;
                        final isSelected = selectedIconCode == code;
                        final iconData = getFolderIconData(code);

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedIconCode = code),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.accentColor
                                  : theme.surfaceElevated.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : borderSubtle,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              iconData,
                              size: 20,
                              color: isSelected
                                  ? theme.onAccentColor
                                  : textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = _folderNameCtrl.text.trim();
                            if (name.isNotEmpty) {
                              controller.addFolder(
                                name: name,
                                colorValue: 0xFF111111,
                                iconCode: selectedIconCode,
                              );
                              Navigator.of(ctx).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accentColor,
                            foregroundColor: theme.onAccentColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Crear Carpeta',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpeedDialItem({
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
    required bool isDark,
    required Color textPrimary,
    required Color borderSubtle,
  }) {
    final double start = (index * 0.10).clamp(0.0, 0.6);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _fabAnimController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
      reverseCurve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    );

    return ScaleTransition(
      scale: animation,
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: _fabAnimController,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Etiqueta flotante
              GestureDetector(
                onTap: () {
                  _closeFab();
                  onTap();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderSubtle, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Pequeño botón flotante
              GestureDetector(
                onTap: () {
                  _closeFab();
                  onTap();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderSubtle, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedDial(
    BuildContext context,
    NotesController controller,
    bool isDark,
    Color textPrimary,
    Color borderSubtle,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Pequeños botones flotantes animados saliendo del '+'
        if (_isFabOpen || !_fabAnimController.isDismissed) ...[
          _buildSpeedDialItem(
            index: 4,
            icon: Icons.image_outlined,
            label: 'Imagen',
            isDark: isDark,
            textPrimary: textPrimary,
            borderSubtle: borderSubtle,
            onTap: () => _quickImageNote(context, controller),
          ),
          _buildSpeedDialItem(
            index: 3,
            icon: Icons.gesture_rounded,
            label: 'Boceto a mano',
            isDark: isDark,
            textPrimary: textPrimary,
            borderSubtle: borderSubtle,
            onTap: () => _quickDrawingNote(context, controller, isDark),
          ),
          _buildSpeedDialItem(
            index: 2,
            icon: Icons.mic_none_rounded,
            label: 'Nota de voz',
            isDark: isDark,
            textPrimary: textPrimary,
            borderSubtle: borderSubtle,
            onTap: () => _quickVoiceNote(context, controller, isDark),
          ),
          _buildSpeedDialItem(
            index: 1,
            icon: Icons.create_new_folder_outlined,
            label: 'Nueva carpeta',
            isDark: isDark,
            textPrimary: textPrimary,
            borderSubtle: borderSubtle,
            onTap: () => _showCreateFolderSheet(context, controller, isDark),
          ),
          _buildSpeedDialItem(
            index: 0,
            icon: Icons.article_outlined,
            label: 'Nueva nota',
            isDark: isDark,
            textPrimary: textPrimary,
            borderSubtle: borderSubtle,
            onTap: () => _createNote(context, controller),
          ),
        ],

        // Botón '+' flotante principal abajo a la derecha
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 4),
          child: GestureDetector(
            onTap: _toggleFab,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Provider.of<ThemeController>(context).accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: RotationTransition(
                turns: _rotateAnim,
                child: Icon(
                  Icons.add_rounded,
                  size: 30,
                  color: Provider.of<ThemeController>(context).onAccentColor,
                ),
              ),
            ),
          ),
        ).animate().scale(
          begin: const Offset(0.2, 0.2),
          end: const Offset(1.0, 1.0),
          delay: 200.ms,
          duration: 650.ms,
          curve: Curves.elasticOut,
        ),
      ],
    );
  }

  void _showFolderOptions(
    BuildContext context,
    NotesController controller,
    FolderModel folder,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
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
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.drive_file_rename_outline_rounded, color: textPrimary),
                title: Text(
                  'Renombrar carpeta',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showRenameFolderDialog(context, controller, folder, isDark, textPrimary, textSecondary);
                },
              ),
              if (folder.id != 'general')
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Eliminar carpeta',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    controller.deleteFolder(folder.id);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameFolderDialog(
    BuildContext context,
    NotesController controller,
    FolderModel folder,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    _folderNameCtrl.text = folder.name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
        title: Text('Renombrar carpeta', style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary)),
        content: TextField(
          controller: _folderNameCtrl,
          autofocus: true,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Nuevo nombre...',
            filled: true,
            fillColor: theme.surfaceElevated,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancelar', style: TextStyle(color: textSecondary))),
          ElevatedButton(
            onPressed: () {
              final newName = _folderNameCtrl.text.trim();
              if (newName.isNotEmpty) {
                controller.updateFolder(folder.copyWith(name: newName));
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: theme.onAccentColor),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context, bool isDark) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          '¿Quieres salir?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: theme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas cerrar inkNotes?',
          style: TextStyle(
            fontSize: 13.5,
            color: theme.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: theme.onAccentColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text(
              'Salir',
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

    final textPrimary = themeController.textPrimary;
    final textSecondary = themeController.textSecondary;
    final borderSubtle = themeController.borderSubtle;
    final bgCard = themeController.surfaceCard;
    final bgPrimary = themeController.bgPrimary;

    final todayFormatted = WriterTextFormatter.formatSpanishDate(DateTime.now());
    final isInsideFolder = controller.selectedFolderId != null && controller.selectedFolderId != 'all';
    final currentFolder = isInsideFolder ? controller.getFolder(controller.selectedFolderId!) : null;
    final filteredNotes = controller.filteredNotes;

    // En el directorio raíz, las carpetas y las notas sueltas forman UN SOLO CONJUNTO
    final folders = isInsideFolder ? <FolderModel>[] : controller.sortedFolders;
    final totalRootItems = folders.length + filteredNotes.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 0. Si está en modo selección por lotes, cancelarlo primero
        if (_isSelectionMode) {
          _clearSelection();
          return;
        }

        // 1. Si el speed dial flotante está desplegado, replegarlo primero
        if (_isFabOpen) {
          _closeFab();
          return;
        }

        // 2. Si el usuario está navegando dentro de una carpeta, volver a la raíz primero
        if (controller.selectedFolderId != null && controller.selectedFolderId != 'all') {
          controller.setSelectedFolder(null);
          return;
        }

        // 3. Si está en la raíz, confirmar si desea salir de la app
        final shouldExit = await _showExitConfirmationDialog(context, isDark);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgPrimary,
        body: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
            // Cabecera Editorial Limpia y Organizada
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: _isSelectionMode
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 22),
                                tooltip: 'Cancelar selección',
                                visualDensity: VisualDensity.compact,
                                onPressed: _clearSelection,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedNoteIds.length} seleccionada${_selectedNoteIds.length == 1 ? "" : "s"}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: Icon(
                              _selectedNoteIds.length == filteredNotes.length
                                  ? Icons.deselect_rounded
                                  : Icons.select_all_rounded,
                              size: 18,
                              color: textPrimary,
                            ),
                            label: Text(
                              _selectedNoteIds.length == filteredNotes.length
                                  ? 'Deseleccionar'
                                  : 'Todas',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: textPrimary,
                              ),
                            ),
                            onPressed: () => _selectAllNotes(filteredNotes),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // Fila 1: Fecha (o Volver) a la izquierda, Acciones a la derecha
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isInsideFolder)
                          GestureDetector(
                            onTap: () => controller.setSelectedFolder(null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderSubtle, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: 16,
                                    color: textPrimary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Volver a notas',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.15, end: 0, curve: Curves.easeOutBack)
                        else
                          Text(
                            todayFormatted.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                              letterSpacing: 1.2,
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic),

                        // Botones de acción principales (condensados: búsqueda, vista y opciones)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.search_rounded,
                                size: 21,
                                color: textSecondary,
                              ),
                              tooltip: 'Buscar notas',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => GlobalSearchSheet.show(context),
                            ).animate().fadeIn(duration: 300.ms, delay: 50.ms).scale(begin: const Offset(0.65, 0.65), curve: Curves.easeOutBack),
                            IconButton(
                              icon: Icon(
                                controller.isGridView
                                    ? Icons.view_agenda_outlined
                                    : Icons.grid_view_rounded,
                                size: 20,
                                color: textSecondary,
                              ),
                              tooltip: controller.isGridView
                                  ? 'Vista Lista'
                                  : 'Vista Cuadrícula',
                              visualDensity: VisualDensity.compact,
                              onPressed: controller.toggleViewMode,
                            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).scale(begin: const Offset(0.65, 0.65), curve: Curves.easeOutBack),
                            IconButton(
                              icon: Icon(
                                Icons.settings_outlined,
                                size: 21,
                                color: textSecondary,
                              ),
                              tooltip: 'Opciones',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => OptionsScreen.open(context),
                            ).animate().fadeIn(duration: 300.ms, delay: 150.ms).scale(begin: const Offset(0.65, 0.65), curve: Curves.easeOutBack),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Fila 2: Título de Carpeta / App y Botones de Acción Armónicos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isInsideFolder) ...[
                                    Icon(
                                      currentFolder?.iconData ?? Icons.folder_rounded,
                                      size: 19,
                                      color: textPrimary,
                                    ),
                                    const SizedBox(width: 7),
                                  ],
                                  Flexible(
                                    child: Text(
                                      isInsideFolder
                                          ? (currentFolder?.name ?? 'Carpeta')
                                          : 'inkNotes',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isInsideFolder ? 18.5 : 21,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isInsideFolder
                                    ? '${filteredNotes.length} ${filteredNotes.length == 1 ? "nota" : "notas"}'
                                    : '${folders.length} carpetas · ${filteredNotes.length} notas',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutBack),
                        ),

                        const SizedBox(width: 12),

                        // Botones de acción a la derecha (Filtrar + Opciones de carpeta con estilo armónico)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: controller.isFilterActive ? 0.08 : 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: controller.isFilterActive
                                      ? textPrimary.withValues(alpha: 0.35)
                                      : borderSubtle,
                                  width: 0.9,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => SortFilterSheet.show(context),
                                  child: Center(
                                    child: Badge(
                                      isLabelVisible: controller.isFilterActive,
                                      smallSize: 6,
                                      backgroundColor: textPrimary,
                                      child: Icon(
                                        Icons.tune_rounded,
                                        size: 18.5,
                                        color: controller.isFilterActive ? textPrimary : textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(duration: 350.ms, delay: 140.ms).scale(begin: const Offset(0.65, 0.65), curve: Curves.easeOutBack),

                            if (isInsideFolder && currentFolder != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderSubtle, width: 0.9),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _showFolderOptions(
                                      context,
                                      controller,
                                      currentFolder,
                                      isDark,
                                      textPrimary,
                                      textSecondary,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.more_vert_rounded,
                                        size: 18.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(duration: 350.ms, delay: 180.ms).scale(begin: const Offset(0.65, 0.65), curve: Curves.easeOutBack),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Línea Divisoria Minimalista Animada
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  height: 1.0,
                  color: borderSubtle,
                ),
              ).animate().fadeIn(duration: 350.ms, delay: 150.ms).scaleX(begin: 0, alignment: Alignment.centerLeft, curve: Curves.easeOutCubic),
            ),

            // ESTADO VACÍO (si no hay nada que mostrar en esta carpeta)
            if (isInsideFolder && filteredNotes.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        size: 46,
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Esta carpeta está vacía',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Arrastra notas aquí desde Archivos o crea una nueva nota con el botón inferior',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _createNote(context, controller),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          'Crear nota en esta carpeta',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeController.accentColor,
                          foregroundColor: themeController.onAccentColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).scale(begin: const Offset(0.9, 0.9), duration: 450.ms, curve: Curves.easeOutBack),
              )
            else if (!isInsideFolder && totalRootItems == 0)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        controller.isFilterActive ? Icons.filter_alt_off_outlined : Icons.note_alt_outlined,
                        size: 46,
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        controller.isFilterActive
                            ? 'No hay elementos con este filtro'
                            : 'No hay notas ni carpetas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.isFilterActive
                            ? 'Prueba cambiando el filtro o restableciendo la vista'
                            : 'Toca el botón + para crear tu primera nota o carpeta',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: textSecondary, height: 1.35),
                      ),
                      if (controller.isFilterActive) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            controller.resetSortAndFilter();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text(
                            'Restablecer filtros',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: borderSubtle),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).scale(begin: const Offset(0.9, 0.9), duration: 450.ms, curve: Curves.easeOutBack),
              )
            // UN SOLO CONJUNTO EN CUADRÍCULA (Carpetas + Notas juntas en el mismo grid)
            else if (controller.isGridView)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.90,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Primero las carpetas
                      if (index < folders.length) {
                        final folder = folders[index];
                        final count = controller.getCountForFolder(folder.id);
                        return _buildFolderGridCard(
                          folder: folder,
                          count: count,
                          controller: controller,
                          isDark: isDark,
                          bgCard: bgCard,
                          borderSubtle: borderSubtle,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        )
                        .animate(
                          key: ValueKey('grid_folder_${folder.id}_$index'),
                        )
                        .fadeIn(
                          duration: 380.ms,
                          delay: (index * 40).clamp(0, 480).ms,
                          curve: Curves.easeOut,
                        )
                        .scale(
                          begin: const Offset(0.85, 0.85),
                          end: const Offset(1.0, 1.0),
                          delay: (index * 40).clamp(0, 480).ms,
                          duration: 450.ms,
                          curve: Curves.easeOutBack,
                        )
                        .slideY(
                          begin: 0.16,
                          end: 0,
                          delay: (index * 40).clamp(0, 480).ms,
                          duration: 450.ms,
                          curve: Curves.easeOutCubic,
                        );
                      }

                      // Seguido por las notas que están en este nivel
                      final noteIndex = index - folders.length;
                      final note = filteredNotes[noteIndex];
                      final folder = controller.getFolder(note.folderId);
                      return NoteCard(
                        note: note,
                        folder: folder,
                        isDark: isDark,
                        isGrid: true,
                        isSelectionMode: _isSelectionMode,
                        isSelected: _selectedNoteIds.contains(note.id),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleNoteSelection(note.id);
                          } else {
                            _openEditor(context, note);
                          }
                        },
                        onLongPress: () => _toggleNoteSelection(note.id),
                        onTogglePin: () => controller.togglePin(note.id),
                        onDelete: () => controller.deleteNote(note.id),
                      )
                      .animate(
                        key: ValueKey('grid_note_${note.id}_$index'),
                      )
                      .fadeIn(
                        duration: 380.ms,
                        delay: (index * 40).clamp(0, 480).ms,
                        curve: Curves.easeOut,
                      )
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1.0, 1.0),
                        delay: (index * 40).clamp(0, 480).ms,
                        duration: 450.ms,
                        curve: Curves.easeOutBack,
                      )
                      .slideY(
                        begin: 0.16,
                        end: 0,
                        delay: (index * 40).clamp(0, 480).ms,
                        duration: 450.ms,
                        curve: Curves.easeOutCubic,
                      );
                    },
                    childCount: totalRootItems,
                  ),
                ),
              )
            // UN SOLO CONJUNTO EN LISTA (Carpetas + Notas juntas en la misma lista)
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Primero las carpetas
                      if (index < folders.length) {
                        final folder = folders[index];
                        final count = controller.getCountForFolder(folder.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildFolderListRow(
                            folder: folder,
                            count: count,
                            controller: controller,
                            isDark: isDark,
                            bgCard: bgCard,
                            borderSubtle: borderSubtle,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        )
                        .animate(
                          key: ValueKey('list_folder_${folder.id}_$index'),
                        )
                        .fadeIn(
                          duration: 350.ms,
                          delay: (index * 35).clamp(0, 420).ms,
                          curve: Curves.easeOut,
                        )
                        .scale(
                          begin: const Offset(0.92, 0.92),
                          end: const Offset(1.0, 1.0),
                          delay: (index * 35).clamp(0, 420).ms,
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        )
                        .slideY(
                          begin: 0.14,
                          end: 0,
                          delay: (index * 35).clamp(0, 420).ms,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        );
                      }

                      // Seguido por las notas que están en este nivel
                      final noteIndex = index - folders.length;
                      final note = filteredNotes[noteIndex];
                      final folder = controller.getFolder(note.folderId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: NoteCard(
                          note: note,
                          folder: folder,
                          isDark: isDark,
                          isGrid: false,
                          isSelectionMode: _isSelectionMode,
                          isSelected: _selectedNoteIds.contains(note.id),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleNoteSelection(note.id);
                            } else {
                              _openEditor(context, note);
                            }
                          },
                          onLongPress: () => _toggleNoteSelection(note.id),
                          onTogglePin: () => controller.togglePin(note.id),
                          onDelete: () => controller.deleteNote(note.id),
                        ),
                      )
                      .animate(
                        key: ValueKey('list_note_${note.id}_$index'),
                      )
                      .fadeIn(
                        duration: 350.ms,
                        delay: (index * 35).clamp(0, 420).ms,
                        curve: Curves.easeOut,
                      )
                      .scale(
                        begin: const Offset(0.92, 0.92),
                        end: const Offset(1.0, 1.0),
                        delay: (index * 35).clamp(0, 420).ms,
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      )
                      .slideY(
                        begin: 0.14,
                        end: 0,
                        delay: (index * 35).clamp(0, 420).ms,
                        duration: 400.ms,
                        curve: Curves.easeOutCubic,
                      );
                    },
                    childCount: totalRootItems,
                  ),
                ),
              ),
            ],
          ),

          // Fondo semitransparente que se atenúa suavemente al desplegar el speed dial
          if (_isFabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFab,
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _fabAnimController,
                  builder: (context, child) => Container(
                    color: Colors.black.withValues(
                      alpha: (0.35 * _fabAnimController.value).clamp(0.0, 0.35),
                    ),
                  ),
                ),
              ),
            ),

          // Barra flotante de acciones por lote cuando hay selección activa
          if (_isSelectionMode)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: themeController.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderSubtle,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.drive_file_move_outlined, size: 20),
                        label: const Text(
                          'Mover',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        onPressed: _selectedNoteIds.isEmpty
                            ? null
                            : () => _showBatchMoveSheet(context, controller, isDark),
                      ),
                    ),
                    Container(height: 24, width: 1, color: borderSubtle),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: Colors.redAccent,
                          ),
                        ),
                        onPressed: _selectedNoteIds.isEmpty
                            ? null
                            : () => _confirmBatchDelete(context, controller, isDark),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0),
            ),
        ],
      ),
    ),

    // Speed Dial con pequeños botones flotantes animados (oculto en modo selección)
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: _isSelectionMode
        ? null
        : _buildSpeedDial(
            context,
            controller,
            isDark,
            textPrimary,
            borderSubtle,
          ),
  ),
);
}

  // Tarjeta de Carpeta en la Cuadrícula Unificada (UN SOLO CONJUNTO)
  Widget _buildFolderGridCard({
    required FolderModel folder,
    required int count,
    required NotesController controller,
    required bool isDark,
    required Color bgCard,
    required Color borderSubtle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return DragTarget<NoteModel>(
      onWillAcceptWithDetails: (details) => details.data.folderId != folder.id,
      onAcceptWithDetails: (details) {
        controller.moveNoteToFolder(details.data.id, folder.id);
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nota movida a "${folder.name}"'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedScale(
          scale: isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isHovered
                  ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7))
                  : bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isHovered
                    ? (isDark ? Colors.white : Colors.black)
                    : borderSubtle,
                width: isHovered ? 2.0 : 1.1,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : AppTheme.getSoftShadow(isDark),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.setSelectedFolder(folder.id);
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              folder.iconData,
                              size: 22,
                              color: textPrimary,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: textSecondary.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count ${count == 1 ? "nota" : "notas"}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
          ),
        );
      },
    );
  }

  // Fila de Carpeta en la Lista Unificada (UN SOLO CONJUNTO)
  Widget _buildFolderListRow({
    required FolderModel folder,
    required int count,
    required NotesController controller,
    required bool isDark,
    required Color bgCard,
    required Color borderSubtle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return DragTarget<NoteModel>(
      onWillAcceptWithDetails: (details) => details.data.folderId != folder.id,
      onAcceptWithDetails: (details) {
        controller.moveNoteToFolder(details.data.id, folder.id);
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nota movida a "${folder.name}"'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: isHovered
                ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7))
                : bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHovered
                  ? (isDark ? Colors.white : Colors.black)
                  : borderSubtle,
              width: isHovered ? 1.6 : 1.1,
            ),
            boxShadow: AppTheme.getSoftShadow(isDark),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => controller.setSelectedFolder(folder.id),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        folder.iconData,
                        size: 22,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            '$count ${count == 1 ? "nota" : "notas"}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: textSecondary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
