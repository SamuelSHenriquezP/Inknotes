import 'dart:async';
import 'dart:convert';
import '../services/home_widget_bridge.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/folder_model.dart';
import '../models/note_model.dart';
import '../models/note_attachment_model.dart';
import '../models/note_highlight_model.dart';
import '../models/note_history_model.dart';
import '../formatters/writer_text_formatter.dart';
import '../formatters/highlighted_text_controller.dart';

enum SortCriteria {
  date, // Fecha (predeterminado)
  name, // Nombre (alfabético)
  length, // Longitud (tamaño / caracteres)
}

enum SortDirection {
  descending, // Descendente (Z-A, más recientes primero, más largos)
  ascending, // Ascendente (A-Z, más antiguos primero, más cortos)
}

enum FilterType {
  all, // Todo (Carpetas + Notas)
  folders, // Solo carpetas
  notes, // Solo notas
}

extension SortCriteriaExt on SortCriteria {
  String get label {
    switch (this) {
      case SortCriteria.date:
        return 'Fecha';
      case SortCriteria.name:
        return 'Nombre';
      case SortCriteria.length:
        return 'Longitud';
    }
  }

  IconData get icon {
    switch (this) {
      case SortCriteria.date:
        return Icons.calendar_today_rounded;
      case SortCriteria.name:
        return Icons.sort_by_alpha_rounded;
      case SortCriteria.length:
        return Icons.format_align_left_rounded;
    }
  }
}

extension SortDirectionExt on SortDirection {
  String get label {
    switch (this) {
      case SortDirection.descending:
        return 'Descendente';
      case SortDirection.ascending:
        return 'Ascendente';
    }
  }

  IconData get icon {
    switch (this) {
      case SortDirection.descending:
        return Icons.arrow_downward_rounded;
      case SortDirection.ascending:
        return Icons.arrow_upward_rounded;
    }
  }
}

extension FilterTypeExt on FilterType {
  String get label {
    switch (this) {
      case FilterType.all:
        return 'Todo';
      case FilterType.folders:
        return 'Carpetas';
      case FilterType.notes:
        return 'Notas';
    }
  }

  IconData get icon {
    switch (this) {
      case FilterType.all:
        return Icons.grid_view_rounded;
      case FilterType.folders:
        return Icons.folder_outlined;
      case FilterType.notes:
        return Icons.description_outlined;
    }
  }
}

class BackupPreview {
  final int notesCount;
  final int foldersCount;
  final DateTime? exportedAt;

  const BackupPreview({
    required this.notesCount,
    required this.foldersCount,
    this.exportedAt,
  });
}

class BackupImportResult {
  final bool success;
  final int notesImported;
  final int foldersImported;
  final String? error;

  const BackupImportResult({
    required this.success,
    this.notesImported = 0,
    this.foldersImported = 0,
    this.error,
  });
}

class NotesController extends ChangeNotifier {
  static const String _keyFolders = 'ink_notes_folders';
  static const String _keyNotes = 'ink_notes_notes';
  static const String _keyIsGrid = 'ink_notes_is_grid';
  static const String _keySortBy = 'ink_notes_sort_by';
  static const String _keySortDirection = 'ink_notes_sort_direction';
  static const String _keyFilterType = 'ink_notes_filter_type';
  static const String _keyAutoBackupEnabled = 'ink_notes_auto_backup_enabled';
  static const String _keyAutoBackupPayload = 'ink_notes_auto_backup_payload';
  static const String _keyAutoBackupAt = 'ink_notes_auto_backup_at';
  static const String _keyAutoBackupCount = 'ink_notes_auto_backup_count';

  List<FolderModel> _folders = [];
  List<NoteModel> _notes = [];
  String? _selectedFolderId; // null or 'all' = all notes
  String? _selectedTagFilter;
  String _searchQuery = '';
  bool _isGridView = true;
  bool _isLoading = true;
  bool _autoBackupEnabled = false;
  DateTime? _lastAutoBackupAt;
  int _autoBackupNotesCount = 0;
  bool _hasAutoBackup = false;

  SortCriteria _sortBy = SortCriteria.date;
  SortDirection _sortDirection = SortDirection.descending;
  FilterType _filterType = FilterType.all;

  Timer? _saveDebounceTimer;

  List<FolderModel> get folders => _folders;
  List<NoteModel> get notes =>
      _notes.where((n) => n.deletedAt == null).toList();
  List<NoteModel> get trashedNotes {
    final list = _notes.where((n) => n.deletedAt != null).toList();
    list.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return list;
  }

  String? get selectedFolderId => _selectedFolderId;
  String? get selectedTagFilter => _selectedTagFilter;
  String get searchQuery => _searchQuery;
  bool get isGridView => _isGridView;
  bool get isLoading => _isLoading;
  bool get autoBackupEnabled => _autoBackupEnabled;
  DateTime? get lastAutoBackupAt => _lastAutoBackupAt;
  int get autoBackupNotesCount => _autoBackupNotesCount;
  bool get hasAutoBackup => _hasAutoBackup;

  List<String> get allTags {
    final seen = <String, String>{};
    for (final note in _notes) {
      if (note.deletedAt != null) continue;
      for (final rawTag in note.tags) {
        final clean = rawTag.trim();
        if (clean.isEmpty) continue;
        final key = clean.toLowerCase();
        seen.putIfAbsent(key, () => clean);
      }
    }
    final result = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  SortCriteria get sortBy => _sortBy;
  SortDirection get sortDirection => _sortDirection;
  FilterType get filterType => _filterType;
  bool get isFilterActive =>
      _sortBy != SortCriteria.date ||
      _sortDirection != SortDirection.descending ||
      _filterType != FilterType.all ||
      _selectedTagFilter != null;

  NotesController() {
    ready = _init();
  }
  late final Future<void> ready;

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _isGridView = prefs.getBool(_keyIsGrid) ?? true;
      _autoBackupEnabled = prefs.getBool(_keyAutoBackupEnabled) ?? false;
      final backupAtStr = prefs.getString(_keyAutoBackupAt);
      _lastAutoBackupAt = backupAtStr != null
          ? DateTime.tryParse(backupAtStr)
          : null;
      _autoBackupNotesCount = prefs.getInt(_keyAutoBackupCount) ?? 0;
      _hasAutoBackup =
          (prefs.getString(_keyAutoBackupPayload) ?? '').isNotEmpty;

      final foldersJson = prefs.getString(_keyFolders);
      final notesJson = prefs.getString(_keyNotes);

      final sortByStr = prefs.getString(_keySortBy);
      if (sortByStr != null) {
        _sortBy = SortCriteria.values.firstWhere(
          (e) => e.name == sortByStr,
          orElse: () => SortCriteria.date,
        );
      }

      final sortDirStr = prefs.getString(_keySortDirection);
      if (sortDirStr != null) {
        _sortDirection = SortDirection.values.firstWhere(
          (e) => e.name == sortDirStr,
          orElse: () => SortDirection.descending,
        );
      }

      final filterTypeStr = prefs.getString(_keyFilterType);
      if (filterTypeStr != null) {
        _filterType = FilterType.values.firstWhere(
          (e) => e.name == filterTypeStr,
          orElse: () => FilterType.all,
        );
      }

      if (foldersJson != null && foldersJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(foldersJson);
        _folders = list
            .map((e) => FolderModel.fromMap(e as Map<String, dynamic>))
            .toList();
      }

      if (notesJson != null && notesJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(notesJson);
        _notes = list
            .map((e) => NoteModel.fromMap(e as Map<String, dynamic>))
            .toList();

        // Limpieza automática y reparación de resaltados en nota de bienvenida
        bool needsSave = false;
        for (int i = 0; i < _notes.length; i++) {
          var n = _notes[i];
          if (n.content.contains('==') || n.content.contains('*')) {
            final cleaned = cleanMarkdownDelimiters(
              n.content,
              existing: n.highlights,
            );
            n = n.copyWith(
              content: cleaned.text,
              highlights: cleaned.highlights,
            );
            _notes[i] = n;
            needsSave = true;
          }
          if (n.id == 'note_welcome' &&
              n.content.contains('Graba notas de voz')) {
            final hasBrokenOffsets = n.highlights.any(
              (h) =>
                  (h.start == 75 && h.end == 82) ||
                  (h.start == 117 && h.end == 122),
            );
            if (hasBrokenOffsets || n.highlights.isEmpty) {
              _notes[i] = n.copyWith(
                highlights: _buildWelcomeHighlights(n.content),
              );
              needsSave = true;
            }
          }
        }
        if (needsSave) {
          _save();
        }
      }

      if (foldersJson == null && notesJson == null) {
        _populateDefaultData();
      }
    } catch (e) {
      debugPrint('Error loading ink_notes: $e');
      if (_folders.isEmpty) {
        _populateDefaultData();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _populateDefaultData() {
    final now = DateTime.now();

    _folders = [
      FolderModel(
        id: 'general',
        name: 'General',
        colorValue: 0xFF6366F1,
        iconCode: 0xe2a3, // folder
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      FolderModel(
        id: 'ideas',
        name: 'Ideas',
        colorValue: 0xFF10B981,
        iconCode: 0xe362, // lightbulb
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      FolderModel(
        id: 'personal',
        name: 'Personal',
        colorValue: 0xFFF59E0B,
        iconCode: 0xe491, // person
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      FolderModel(
        id: 'trabajo',
        name: 'Trabajo',
        colorValue: 0xFF3B82F6,
        iconCode: 0xe6f2, // work
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    const welcomeContent =
        'Espacio minimalista y rápido diseñado para tomar notas sin distracciones.\n\n'
        '• Resalta fragmentos con tonos pasteles.\n'
        '• Graba notas de voz directas con reproductor integrado.\n'
        '• Añade bocetos y dibujos a mano alzada.\n'
        '• Inserta imágenes en cualquier nota.';

    _notes = [
      NoteModel(
        id: 'note_welcome',
        folderId: null, // At root
        title: '¡Bienvenido a inkNotes! 📝',
        content: welcomeContent,
        isPinned: true,
        highlights: _buildWelcomeHighlights(welcomeContent),
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(minutes: 10)),
      ),
      NoteModel(
        id: 'note_voice',
        folderId: 'personal',
        title: 'Recordatorio rápido de voz 🎙️',
        content:
            'Audio con los pendientes de la semana y detalles importantes que no quiero olvidar.',
        isPinned: false,
        attachments: [
          NoteAttachmentModel(
            id: 'sample_audio_1',
            type: AttachmentType.audio,
            data: 'sample_audio_memo',
            name: 'Nota de voz (0:34)',
            durationSeconds: 34,
            createdAt: now.subtract(const Duration(hours: 3)),
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      NoteModel(
        id: 'note_ideas',
        folderId: 'ideas',
        title: 'Boceto de concepto',
        content:
            'Idea para el nuevo diseño despejado. Usa el botón de lápiz inferior para trazar rápidamente un diagrama o firma.',
        isPinned: false,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    _save();
  }

  /// Carpetas ordenadas y filtradas según el criterio activo
  /// Carpetas ordenadas y filtradas según el criterio activo
  List<FolderModel> get sortedFolders {
    if (_filterType == FilterType.notes) {
      return const [];
    }

    final list = List<FolderModel>.from(_folders);
    final isAsc = _sortDirection == SortDirection.ascending;

    switch (_sortBy) {
      case SortCriteria.date:
        list.sort(
          (a, b) => isAsc
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt),
        );
        break;
      case SortCriteria.name:
        list.sort(
          (a, b) => isAsc
              ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
              : b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case SortCriteria.length:
        list.sort((a, b) {
          final countA = getCountForFolder(a.id);
          final countB = getCountForFolder(b.id);
          return isAsc ? countA.compareTo(countB) : countB.compareTo(countA);
        });
        break;
    }
    return list;
  }

  /// Notas ordenadas y filtradas según el criterio activo
  List<NoteModel> get filteredNotes {
    if (_filterType == FilterType.folders) {
      return const [];
    }

    final list = _notes.where((note) {
      if (note.deletedAt != null) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = note.title.toLowerCase().contains(q);
        final matchContent = note.content.toLowerCase().contains(q);
        final matchTag = note.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchTitle && !matchContent && !matchTag) return false;
      }

      if (_selectedTagFilter != null) {
        final target = _selectedTagFilter!.toLowerCase();
        final hasTag = note.tags.any((t) => t.toLowerCase() == target);
        if (!hasTag) return false;
      }

      if (_selectedFolderId != null && _selectedFolderId != 'all') {
        if (note.folderId != _selectedFolderId) return false;
      } else if (_selectedTagFilter == null) {
        // Nivel raíz: lo que está en las carpetas NO se ve afuera (salvo al filtrar por etiqueta)
        if (!((note.folderId?.isEmpty ?? true) || note.folderId == 'root')) {
          return false;
        }
      }

      return true;
    }).toList();

    final isAsc = _sortDirection == SortDirection.ascending;

    list.sort((a, b) {
      // Notas fijadas siempre arriba
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      switch (_sortBy) {
        case SortCriteria.date:
          return isAsc
              ? a.updatedAt.compareTo(b.updatedAt)
              : b.updatedAt.compareTo(a.updatedAt);
        case SortCriteria.name:
          final tA = a.title.trim().isNotEmpty ? a.title : a.content;
          final tB = b.title.trim().isNotEmpty ? b.title : b.content;
          return isAsc
              ? tA.toLowerCase().compareTo(tB.toLowerCase())
              : tB.toLowerCase().compareTo(tA.toLowerCase());
        case SortCriteria.length:
          final lenA = a.content.length + a.title.length;
          final lenB = b.content.length + b.title.length;
          return isAsc ? lenA.compareTo(lenB) : lenB.compareTo(lenA);
      }
    });

    return list;
  }

  void setSortBy(SortCriteria criteria) {
    if (_sortBy != criteria) {
      _sortBy = criteria;
      notifyListeners();
      _saveSortAndFilter();
    }
  }

  void setSortDirection(SortDirection direction) {
    if (_sortDirection != direction) {
      _sortDirection = direction;
      notifyListeners();
      _saveSortAndFilter();
    }
  }

  void setFilterType(FilterType type) {
    if (_filterType != type) {
      _filterType = type;
      notifyListeners();
      _saveSortAndFilter();
    }
  }

  void resetSortAndFilter() {
    _sortBy = SortCriteria.date;
    _sortDirection = SortDirection.descending;
    _filterType = FilterType.all;
    _selectedTagFilter = null;
    notifyListeners();
    _saveSortAndFilter();
  }

  void setSelectedTagFilter(String? tag) {
    final clean = tag?.replaceFirst(RegExp(r'^#+'), '').trim();
    final next = (clean == null || clean.isEmpty) ? null : clean;
    if (_selectedTagFilter != next) {
      _selectedTagFilter = next;
      if (next != null) _selectedFolderId = null;
      notifyListeners();
    }
  }

  Future<void> _saveSortAndFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySortBy, _sortBy.name);
      await prefs.setString(_keySortDirection, _sortDirection.name);
      await prefs.setString(_keyFilterType, _filterType.name);
    } catch (_) {}
  }

  int getCountForFolder(String folderId) {
    if (folderId == 'all') {
      return _notes.where((n) => n.deletedAt == null).length;
    }
    return _notes
        .where((n) => n.deletedAt == null && n.folderId == folderId)
        .length;
  }

  FolderModel? getFolder(String? folderId) {
    if (folderId == null || folderId.isEmpty) return null;
    try {
      return _folders.firstWhere((f) => f.id == folderId);
    } catch (_) {
      return null;
    }
  }

  void setSelectedFolder(String? folderId) {
    _selectedFolderId = folderId;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
    _saveViewMode();
  }

  // Folder Operations
  Future<void> addFolder({
    required String name,
    int colorValue = 0xFF6366F1,
    int iconCode = 0xe2a3,
  }) async {
    final folder = FolderModel(
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Nueva Carpeta' : name.trim(),
      colorValue: colorValue,
      iconCode: iconCode,
      createdAt: DateTime.now(),
    );
    _folders.add(folder);
    notifyListeners();
    _scheduleSave();
  }

  Future<void> updateFolder(FolderModel folder) async {
    final index = _folders.indexWhere((f) => f.id == folder.id);
    if (index != -1) {
      _folders[index] = folder;
      notifyListeners();
      _scheduleSave();
    }
  }

  Future<void> deleteFolder(String folderId) async {
    if (folderId == 'general') return;
    if (_selectedFolderId == folderId) _selectedFolderId = null;
    _folders.removeWhere((f) => f.id == folderId);
    for (int i = 0; i < _notes.length; i++) {
      if (_notes[i].folderId == folderId) {
        _notes[i] = _notes[i].copyWith(folderId: 'general');
      }
    }
    notifyListeners();
    _scheduleSave();
  }

  int _idSequence = 0;

  // Note Operations
  NoteModel createNote({
    String? folderId,
    String title = '',
    String content = '',
    bool isPinned = false,
    List<String> tags = const [],
    List<NoteAttachmentModel>? attachments,
  }) {
    final targetFolder =
        (folderId != null && folderId != 'all' && folderId != 'root')
        ? folderId
        : (_selectedFolderId != null &&
              _selectedFolderId != 'all' &&
              _selectedFolderId != 'root')
        ? _selectedFolderId
        : null;

    var noteId = 'note_${DateTime.now().millisecondsSinceEpoch}';
    if (_notes.any((n) => n.id == noteId)) {
      noteId = '${noteId}_${++_idSequence}';
    }

    final normalizedTags = _normalizeTags([...tags, ..._inlineTags(content)]);

    final note = NoteModel(
      id: noteId,
      folderId: targetFolder,
      title: title,
      content: content,
      isPinned: isPinned,
      tags: normalizedTags,
      attachments: attachments ?? [],
      highlights: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _notes.insert(0, note);
    notifyListeners();
    _scheduleSave();
    return note;
  }

  List<String> _normalizeTags(Iterable<String> rawTags) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawTags) {
      final clean = raw.trim().replaceFirst(RegExp(r'^#+'), '').trim();
      if (clean.isEmpty) continue;
      final key = clean.toLowerCase();
      if (seen.add(key)) {
        result.add(clean);
      }
    }
    return result;
  }

  static Iterable<String> _inlineTags(String content) => RegExp(
    r'(?:^|\s)#([\p{L}\p{N}_]+)',
    unicode: true,
  ).allMatches(content).map((match) => match.group(1)!);

  void updateNote(NoteModel updated) {
    final index = _notes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _notes[index] = updated.copyWith(
        tags: _normalizeTags([
          ...updated.tags,
          ..._inlineTags(updated.content),
        ]),
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void togglePin(String noteId) {
    final index = _notes.indexWhere(
      (n) => n.id == noteId && n.deletedAt == null,
    );
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        isPinned: !_notes[index].isPinned,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void setNoteTags(String noteId, List<String> tags) {
    final index = _notes.indexWhere(
      (n) => n.id == noteId && n.deletedAt == null,
    );
    if (index != -1) {
      final normalized = _normalizeTags(tags);
      _notes[index] = _notes[index].copyWith(
        tags: normalized,
        updatedAt: DateTime.now(),
      );
      if (_selectedTagFilter != null &&
          !allTags.any(
            (t) => t.toLowerCase() == _selectedTagFilter!.toLowerCase(),
          )) {
        _selectedTagFilter = null;
      }
      notifyListeners();
      _scheduleSave();
    }
  }

  void toggleChecklistLine(String noteId, int lineIndex) {
    final index = _notes.indexWhere(
      (n) => n.id == noteId && n.deletedAt == null,
    );
    if (index != -1) {
      final current = _notes[index];
      final nextContent = WriterTextFormatter.toggleChecklistLine(
        current.content,
        lineIndex,
      );
      if (nextContent != current.content) {
        _notes[index] = current.copyWith(
          content: nextContent,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        _scheduleSave();
      }
    }
  }

  void moveNoteToFolder(String noteId, String? targetFolderId) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final isRoot =
          targetFolderId == null ||
          targetFolderId.isEmpty ||
          targetFolderId == 'root' ||
          targetFolderId == 'all';
      _notes[index] = _notes[index].copyWith(
        folderId: isRoot ? null : targetFolderId,
        clearFolder: isRoot,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void deleteNote(String noteId) {
    final index = _notes.indexWhere(
      (n) => n.id == noteId && n.deletedAt == null,
    );
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(deletedAt: DateTime.now());
      if (_selectedTagFilter != null &&
          !allTags.any(
            (t) => t.toLowerCase() == _selectedTagFilter!.toLowerCase(),
          )) {
        _selectedTagFilter = null;
      }
      notifyListeners();
      _scheduleSave();
    }
  }

  void deleteNotes(Iterable<String> noteIds) {
    final idsSet = noteIds.toSet();
    final now = DateTime.now();
    bool changed = false;
    for (int i = 0; i < _notes.length; i++) {
      if (idsSet.contains(_notes[i].id) && _notes[i].deletedAt == null) {
        _notes[i] = _notes[i].copyWith(deletedAt: now);
        changed = true;
      }
    }
    if (changed) {
      if (_selectedTagFilter != null &&
          !allTags.any(
            (t) => t.toLowerCase() == _selectedTagFilter!.toLowerCase(),
          )) {
        _selectedTagFilter = null;
      }
      notifyListeners();
      _scheduleSave();
    }
  }

  void restoreNote(String id) {
    final index = _notes.indexWhere((n) => n.id == id && n.deletedAt != null);
    if (index != -1) {
      final note = _notes[index];
      final folderExists =
          note.folderId == null || _folders.any((f) => f.id == note.folderId);
      _notes[index] = note.copyWith(
        clearDeletedAt: true,
        clearFolder: !folderExists,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void permanentlyDeleteNote(String id) {
    final beforeLen = _notes.length;
    _notes.removeWhere((n) => n.id == id);
    if (_notes.length != beforeLen) {
      if (_selectedTagFilter != null &&
          !allTags.any(
            (t) => t.toLowerCase() == _selectedTagFilter!.toLowerCase(),
          )) {
        _selectedTagFilter = null;
      }
      notifyListeners();
      _scheduleSave();
    }
  }

  void emptyTrash() {
    final beforeLen = _notes.length;
    _notes.removeWhere((n) => n.deletedAt != null);
    if (_notes.length != beforeLen) {
      notifyListeners();
      _scheduleSave();
    }
  }

  void moveNotesToFolder(Iterable<String> noteIds, String? targetFolderId) {
    final idsSet = noteIds.toSet();
    final isRoot =
        targetFolderId == null ||
        targetFolderId.isEmpty ||
        targetFolderId == 'root' ||
        targetFolderId == 'all';
    for (int i = 0; i < _notes.length; i++) {
      if (idsSet.contains(_notes[i].id)) {
        _notes[i] = _notes[i].copyWith(
          folderId: isRoot ? null : targetFolderId,
          clearFolder: isRoot,
          updatedAt: DateTime.now(),
        );
      }
    }
    notifyListeners();
    _scheduleSave();
  }

  void addAttachment(String noteId, NoteAttachmentModel attachment) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final list = List<NoteAttachmentModel>.from(_notes[index].attachments)
        ..add(attachment);
      _notes[index] = _notes[index].copyWith(
        attachments: list,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void removeAttachment(String noteId, String attachmentId) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final list = List<NoteAttachmentModel>.from(_notes[index].attachments)
        ..removeWhere((a) => a.id == attachmentId);
      _notes[index] = _notes[index].copyWith(
        attachments: list,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void updateHighlights(String noteId, List<NoteHighlightModel> highlights) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        highlights: highlights,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void addHistorySnapshot(String noteId) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      if (note.title.trim().isEmpty && note.content.trim().isEmpty) return;

      final historyList = List<NoteHistorySnapshot>.from(note.history);
      // Evitar guardar duplicados consecutivos exactos
      if (historyList.isNotEmpty) {
        final last = historyList.first;
        if (last.title == note.title && last.content == note.content) {
          return;
        }
      }

      final snapshot = NoteHistorySnapshot(
        timestamp: DateTime.now(),
        title: note.title,
        content: note.content,
        wordCount: WriterTextFormatter.countWords(note.content),
      );

      historyList.insert(0, snapshot);
      if (historyList.length > 25) {
        historyList.removeLast();
      }

      _notes[index] = note.copyWith(
        history: historyList,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void restoreSnapshot(String noteId, NoteHistorySnapshot snapshot) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      // Crear snapshot del estado previo antes de restaurar
      final historyList = List<NoteHistorySnapshot>.from(note.history);
      if (note.title.isNotEmpty || note.content.isNotEmpty) {
        historyList.insert(
          0,
          NoteHistorySnapshot(
            timestamp: DateTime.now(),
            title: note.title,
            content: note.content,
            wordCount: WriterTextFormatter.countWords(note.content),
          ),
        );
      }

      _notes[index] = note.copyWith(
        title: snapshot.title,
        content: snapshot.content,
        history: historyList,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _scheduleSave();
    }
  }

  void deleteHistorySnapshot(String noteId, int snapshotIndex) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      final historyList = List<NoteHistorySnapshot>.from(note.history);
      if (snapshotIndex >= 0 && snapshotIndex < historyList.length) {
        historyList.removeAt(snapshotIndex);
        _notes[index] = note.copyWith(history: historyList);
        notifyListeners();
        _scheduleSave();
      }
    }
  }

  void clearHistory(String noteId) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      _notes[index] = note.copyWith(history: const []);
      notifyListeners();
      _scheduleSave();
    }
  }

  List<NoteHighlightModel> _buildWelcomeHighlights(String content) {
    final specs = <MapEntry<String, int>>[
      const MapEntry('Espacio minimalista y rápido diseñado', 0xFFFFE082),
      const MapEntry('Resalta', 0xFFA5D6A7),
      const MapEntry('Graba', 0xFF90CAF9),
      const MapEntry('dibujos', 0xFFCE93D8),
      const MapEntry('imágenes', 0xFFFFCC80),
    ];
    final result = <NoteHighlightModel>[];
    for (final spec in specs) {
      final idx = content.indexOf(spec.key);
      if (idx != -1) {
        result.add(
          NoteHighlightModel(
            start: idx,
            end: idx + spec.key.length,
            colorValue: spec.value,
          ),
        );
      }
    }
    return result;
  }

  String buildBackupJson() {
    return jsonEncode({
      'app': 'inkNotes',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'folders': _folders.map((f) => f.toMap()).toList(),
      'notes': _notes.map((n) => n.toMap()).toList(),
    });
  }

  BackupPreview? previewBackupJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['notes'] is! List) return null;
      final notesList = decoded['notes'] as List<dynamic>;
      final foldersList = decoded['folders'] as List<dynamic>? ?? const [];
      final exportedAtStr = decoded['exportedAt'] as String?;
      return BackupPreview(
        notesCount: notesList.length,
        foldersCount: foldersList.length,
        exportedAt: exportedAtStr != null
            ? DateTime.tryParse(exportedAtStr)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<BackupImportResult> importBackupJson(
    String rawJson, {
    bool merge = false,
  }) async {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic> || decoded['notes'] is! List) {
        return const BackupImportResult(
          success: false,
          error: 'Formato de respaldo inválido',
        );
      }

      final rawFolders = decoded['folders'] as List<dynamic>? ?? const [];
      final rawNotes = decoded['notes'] as List<dynamic>;

      final parsedFolders = rawFolders
          .whereType<Map<String, dynamic>>()
          .map(FolderModel.fromMap)
          .toList();
      final parsedNotes = rawNotes
          .whereType<Map<String, dynamic>>()
          .map(NoteModel.fromMap)
          .toList();

      if (merge) {
        final existingFolderIds = _folders.map((f) => f.id).toSet();
        for (final f in parsedFolders) {
          if (!existingFolderIds.contains(f.id)) {
            _folders.add(f);
            existingFolderIds.add(f.id);
          }
        }
        final existingNoteIds = _notes.map((n) => n.id).toSet();
        for (final n in parsedNotes) {
          if (!existingNoteIds.contains(n.id)) {
            _notes.add(n);
            existingNoteIds.add(n.id);
          }
        }
      } else {
        _folders = parsedFolders;
        _notes = parsedNotes;
        _selectedFolderId = null;
      }

      notifyListeners();
      await _save();

      return BackupImportResult(
        success: true,
        notesImported: parsedNotes.length,
        foldersImported: parsedFolders.length,
      );
    } catch (e) {
      return BackupImportResult(
        success: false,
        error: 'No se pudo procesar la copia: $e',
      );
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoBackupEnabled, enabled);
    } catch (_) {}
    if (enabled) {
      await runAutoBackupNow();
    }
  }

  Future<void> runAutoBackupNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = buildBackupJson();
      final now = DateTime.now();
      await prefs.setString(_keyAutoBackupPayload, payload);
      await prefs.setString(_keyAutoBackupAt, now.toIso8601String());
      await prefs.setInt(_keyAutoBackupCount, _notes.length);
      _lastAutoBackupAt = now;
      _autoBackupNotesCount = _notes.length;
      _hasAutoBackup = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> restoreAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = prefs.getString(_keyAutoBackupPayload);
      if (payload == null || payload.isEmpty) return false;
      final res = await importBackupJson(payload, merge: false);
      return res.success;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearAllData() async {
    _notes = [];
    _folders = [];
    _selectedFolderId = null;
    _selectedTagFilter = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFolders, jsonEncode([]));
      await prefs.setString(_keyNotes, jsonEncode([]));
      await HomeWidgetBridge.refresh();
    } catch (_) {}
  }

  void _scheduleSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyFolders,
        jsonEncode(_folders.map((f) => f.toMap()).toList()),
      );
      await prefs.setString(
        _keyNotes,
        jsonEncode(_notes.map((n) => n.toMap()).toList()),
      );
      await HomeWidgetBridge.refresh();
      if (_autoBackupEnabled) {
        await runAutoBackupNow();
      }
    } catch (_) {}
  }

  Future<void> flushPendingChanges() async {
    _saveDebounceTimer?.cancel();
    await _save();
  }

  Future<void> _saveViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsGrid, _isGridView);
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    super.dispose();
  }
}
