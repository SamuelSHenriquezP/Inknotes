import 'package:flutter/material.dart';
import '../models/note_highlight_model.dart';

/// Instantánea inmutable del estado del editor para deshacer/rehacer
class EditorHistoryEntry {
  final String title;
  final String content;
  final TextSelection selection;
  final List<NoteHighlightModel> highlights;

  const EditorHistoryEntry({
    required this.title,
    required this.content,
    required this.selection,
    required this.highlights,
  });

  bool isSameState(String t, String c, List<NoteHighlightModel> h) {
    if (title != t || content != c) return false;
    if (highlights.length != h.length) return false;
    for (int i = 0; i < highlights.length; i++) {
      if (highlights[i].start != h[i].start ||
          highlights[i].end != h[i].end ||
          highlights[i].colorValue != h[i].colorValue ||
          highlights[i].isBold != h[i].isBold ||
          highlights[i].isItalic != h[i].isItalic) {
        return false;
      }
    }
    return true;
  }
}

/// Administrador de pila Deshacer/Rehacer (Undo/Redo) para el editor de notas
class EditorUndoManager extends ChangeNotifier {
  final List<EditorHistoryEntry> _history = [];
  int _currentIndex = -1;
  final int maxHistory;

  EditorUndoManager({this.maxHistory = 100});

  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex >= 0 && _currentIndex < _history.length - 1;

  int get historyLength => _history.length;
  int get currentIndex => _currentIndex;

  /// Inicializa la pila con el estado original de la nota
  void initialize(EditorHistoryEntry initial) {
    _history.clear();
    _history.add(initial);
    _currentIndex = 0;
    notifyListeners();
  }

  /// Registra una nueva instantánea si hay cambios respecto al estado actual
  void pushSnapshot(EditorHistoryEntry entry) {
    if (_currentIndex >= 0 && _currentIndex < _history.length) {
      final current = _history[_currentIndex];
      if (current.isSameState(entry.title, entry.content, entry.highlights)) {
        return;
      }
    }

    // Si estábamos en medio del historial debido a deshacer, descartamos las ramas futuras
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    _history.add(entry);
    if (_history.length > maxHistory) {
      _history.removeAt(0);
    } else {
      _currentIndex++;
    }
    notifyListeners();
  }

  /// Deshace al estado anterior
  EditorHistoryEntry? undo() {
    if (!canUndo) return null;
    _currentIndex--;
    notifyListeners();
    return _history[_currentIndex];
  }

  /// Rehace al estado siguiente
  EditorHistoryEntry? redo() {
    if (!canRedo) return null;
    _currentIndex++;
    notifyListeners();
    return _history[_currentIndex];
  }

  /// Limpia el historial
  void clear() {
    _history.clear();
    _currentIndex = -1;
    notifyListeners();
  }
}
