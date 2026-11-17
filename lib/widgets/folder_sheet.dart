import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../controllers/notes_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/folder_model.dart';

class FolderSheet extends StatefulWidget {
  final bool isDark;

  const FolderSheet({super.key, required this.isDark});

  static Future<void> show(BuildContext context, {required bool isDark}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FolderSheet(isDark: isDark),
    );
  }

  @override
  State<FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<FolderSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  int _selectedIconCode = 0xe2a3; // folder

  final List<int> _iconChoices = const [
    0xe2a3, // folder
    0xe362, // lightbulb
    0xe491, // person
    0xe6f2, // work
    0xe5f9, // star
    0xe14d, // menu_book
    0xe87d, // favorite
    0xe59c, // shopping_bag
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showCreateDialog(BuildContext context, NotesController controller) {
    _nameCtrl.clear();
    _selectedIconCode = 0xe2a3;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Provider.of<ThemeController>(context);
          final textPrimary = theme.textPrimary;
          final textSecondary = theme.textSecondary;
          final borderSubtle = theme.borderSubtle;

          return AlertDialog(
            backgroundColor: theme.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            title: Text(
              'Nueva Carpeta',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nombre de la carpeta...',
                    hintStyle: TextStyle(color: textSecondary),
                    filled: true,
                    fillColor: theme.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                      borderSide: BorderSide(color: borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                      borderSide: BorderSide(color: textPrimary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Icono de la carpeta:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _iconChoices.map((code) {
                    final isSel = _selectedIconCode == code;
                    final iconData = getFolderIconData(code);
                    return GestureDetector(
                      onTap: () => setDialogState(() => _selectedIconCode = code),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSel
                              ? theme.accentColor.withValues(alpha: 0.16)
                              : theme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? theme.accentColor : borderSubtle,
                            width: isSel ? 1.8 : 1.0,
                          ),
                        ),
                        child: Icon(
                          iconData,
                          size: 18,
                          color: isSel ? theme.accentColor : textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancelar', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.trim().isNotEmpty) {
                    controller.addFolder(
                      name: _nameCtrl.text.trim(),
                      colorValue: theme.accentColor.toARGB32(),
                      iconCode: _selectedIconCode,
                    );
                  }
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: theme.onAccentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  ),
                ),
                child: const Text(
                  'Crear',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteFolder(
    BuildContext context,
    NotesController controller,
    FolderModel folder,
  ) {
    final theme = Provider.of<ThemeController>(context, listen: false);
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          '¿Eliminar carpeta?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        content: Text(
          'La carpeta "${folder.name}" se eliminará y sus notas se conservarán.',
          style: TextStyle(color: textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteFolder(folder.id);
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

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NotesController>(context);
    final theme = Provider.of<ThemeController>(context);
    final isDark = theme.isDarkMode;
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;
    final bgSheet = theme.surfaceCard;
    final borderSubtle = theme.borderSubtle;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.sheetRadius),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Carpetas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showCreateDialog(context, controller),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Nueva',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: controller.folders.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final folder = controller.folders[index];
                final count = controller.getCountForFolder(folder.id);
                final isSelected = controller.selectedFolderId == folder.id;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderSubtle, width: 0.8),
                    ),
                    child: Icon(folder.iconData, color: textPrimary, size: 20),
                  ),
                  title: Text(
                    folder.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '$count ${count == 1 ? "documento" : "documentos"}',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (folder.id != 'general')
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          color: textSecondary,
                          onPressed: () => _confirmDeleteFolder(context, controller, folder),
                        ),
                    ],
                  ),
                  onTap: () {
                    controller.setSelectedFolder(folder.id);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
