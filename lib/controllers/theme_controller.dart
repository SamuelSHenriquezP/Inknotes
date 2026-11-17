import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const String _keyDarkMode = 'ink_notes_dark_mode';
  static const String _keyThemePreset = 'ink_notes_theme_preset';
  static const String _keyFontFamily = 'ink_notes_font_family';
  static const String _keyFontSize = 'ink_notes_font_size';

  bool _isDarkMode = false;
  AppThemePreset _preset = AppThemePreset.monochrome;
  NoteFontFamily _fontFamily = NoteFontFamily.lora;
  double _fontSize = 16.5;

  bool get isDarkMode => _isDarkMode;
  AppThemePreset get preset => _preset;
  NoteFontFamily get fontFamily => _fontFamily;
  double get fontSize => _fontSize;

  ThemeData get currentTheme =>
      AppTheme.createThemeData(preset: _preset, isDark: _isDarkMode);

  // Shortcut theme accessors for widgets
  Color get bgPrimary => _preset.bgPrimary(_isDarkMode);
  Color get surfaceCard => _preset.surfaceCard(_isDarkMode);
  Color get surfaceElevated => _preset.surfaceElevated(_isDarkMode);
  Color get textPrimary => _preset.textPrimary(_isDarkMode);
  Color get textSecondary => _preset.textSecondary(_isDarkMode);
  Color get borderSubtle => _preset.borderSubtle(_isDarkMode);
  Color get accentColor => _preset.accentColor(_isDarkMode);
  Color get onAccentColor => _preset.onAccentColor(_isDarkMode);

  ThemeController() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_keyDarkMode) ?? false;

      final presetIndex = prefs.getInt(_keyThemePreset);
      if (presetIndex != null &&
          presetIndex >= 0 &&
          presetIndex < AppThemePreset.values.length) {
        _preset = AppThemePreset.values[presetIndex];
      }

      final fontIndex = prefs.getInt(_keyFontFamily);
      if (fontIndex != null &&
          fontIndex >= 0 &&
          fontIndex < NoteFontFamily.values.length) {
        _fontFamily = NoteFontFamily.values[fontIndex];
      }

      _fontSize = prefs.getDouble(_keyFontSize) ?? 16.5;

      _applyOverlay();
      notifyListeners();
    } catch (_) {}
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _applyOverlay();
    _savePreferences();
    notifyListeners();
  }

  void setPreset(AppThemePreset newPreset) {
    _preset = newPreset;
    _savePreferences();
    notifyListeners();
  }

  void setFontFamily(NoteFontFamily newFont) {
    _fontFamily = newFont;
    _savePreferences();
    notifyListeners();
  }

  void setFontSize(double newSize) {
    _fontSize = newSize.clamp(13.0, 24.0);
    _savePreferences();
    notifyListeners();
  }

  void _applyOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: _isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDarkMode, _isDarkMode);
      await prefs.setInt(_keyThemePreset, _preset.index);
      await prefs.setInt(_keyFontFamily, _fontFamily.index);
      await prefs.setDouble(_keyFontSize, _fontSize);
    } catch (_) {}
  }
}
