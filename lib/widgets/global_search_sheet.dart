import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/note_model.dart';
import '../controllers/notes_controller.dart';
import '../controllers/theme_controller.dart';
import '../screens/note_editor_screen.dart';

class GlobalSearchSheet extends StatefulWidget {
  const GlobalSearchSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GlobalSearchSheet(),
    );
  }

  @override
  State<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<GlobalSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHighlightedText({
    required String text,
    required String query,
    required TextStyle baseStyle,
    required TextStyle matchStyle,
    int? maxLines,
  }) {
    if (query.isEmpty || !text.toLowerCase().contains(query)) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final List<TextSpan> spans = [];
    final q = query.toLowerCase();
    int start = 0;

    while (start < text.length) {
      final matchIndex = text.toLowerCase().indexOf(q, start);
      if (matchIndex == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (matchIndex > start) {
        spans.add(
          TextSpan(text: text.substring(start, matchIndex), style: baseStyle),
        );
      }
      final matchEnd = matchIndex + q.length;
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchEnd),
          style: matchStyle,
        ),
      );
      start = matchEnd;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NotesController>(context);
    final theme = Provider.of<ThemeController>(context);
    final isDark = theme.isDarkMode;

    final bgSheet = theme.surfaceCard;
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;
    final borderSubtle = theme.borderSubtle;

    final q = _query.toLowerCase().trim();
    final List<NoteModel> results = q.isEmpty
        ? <NoteModel>[]
        : controller.notes.where((note) {
            return note.title.toLowerCase().contains(q) ||
                note.content.toLowerCase().contains(q);
          }).toList();

    final matchStyle = TextStyle(
      backgroundColor: Colors.amber.withValues(alpha: 0.35),
      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
      fontWeight: FontWeight.w800,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.sheetRadius),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Búsqueda Global',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF27272A)
                    : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                border: Border.all(color: borderSubtle),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar en notas, títulos y contenidos...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: textSecondary,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          color: textSecondary,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),
          ),

          const Divider(height: 16),

          // Results List
          Expanded(
            child: q.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 38,
                          color: textSecondary.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escribe un término para buscar en tus notas',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 38,
                          color: textSecondary.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No se encontraron coincidencias para "$_query"',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final note = results[index];
                      final folder = controller.getFolder(note.folderId);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderSubtle, width: 0.8),
                          ),
                          child: Icon(
                            folder?.iconData ?? Icons.notes_rounded,
                            color: textPrimary,
                            size: 20,
                          ),
                        ),
                        title: _buildHighlightedText(
                          text: note.title.isNotEmpty
                              ? note.title
                              : 'Nota sin título',
                          query: q,
                          baseStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            fontSize: 14.5,
                          ),
                          matchStyle: matchStyle.copyWith(fontSize: 14.5),
                        ),
                        subtitle: note.content.isNotEmpty
                            ? _buildHighlightedText(
                                text: note.content,
                                query: q,
                                baseStyle: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                  height: 1.4,
                                ),
                                matchStyle: matchStyle.copyWith(fontSize: 12),
                                maxLines: 2,
                              )
                            : null,
                        trailing: folder != null
                            ? Text(
                                folder.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NoteEditorScreen(noteId: note.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
