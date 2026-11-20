import 'dart:convert';
import '../services/home_widget_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pure-Dart SHA-256 implementation so PIN hashing requires zero external deps.
class _Sha256 {
  static const List<int> _k = [
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  static int _rotr(int x, int n) =>
      ((x & 0xFFFFFFFF) >> n) | ((x << (32 - n)) & 0xFFFFFFFF);

  static String digestHex(String input) {
    final bytes = utf8.encode(input);
    final bitLen = bytes.length * 8;
    final padded = List<int>.from(bytes)..add(0x80);
    while ((padded.length % 64) != 56) {
      padded.add(0);
    }
    for (int i = 7; i >= 0; i--) {
      padded.add((bitLen >> (i * 8)) & 0xFF);
    }

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final w = List<int>.filled(64, 0);
    for (int offset = 0; offset < padded.length; offset += 64) {
      for (int i = 0; i < 16; i++) {
        final idx = offset + i * 4;
        w[i] =
            ((padded[idx] << 24) |
                (padded[idx + 1] << 16) |
                (padded[idx + 2] << 8) |
                padded[idx + 3]) &
            0xFFFFFFFF;
      }
      for (int i = 16; i < 64; i++) {
        final s0 =
            _rotr(w[i - 15], 7) ^
            _rotr(w[i - 15], 18) ^
            ((w[i - 15] & 0xFFFFFFFF) >> 3);
        final s1 =
            _rotr(w[i - 2], 17) ^
            _rotr(w[i - 2], 19) ^
            ((w[i - 2] & 0xFFFFFFFF) >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (int i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
        final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    String hex32(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return '${hex32(h0)}${hex32(h1)}${hex32(h2)}${hex32(h3)}${hex32(h4)}${hex32(h5)}${hex32(h6)}${hex32(h7)}';
  }
}

class SecurityController extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('inknotes/security');
  static const String _keyPinEnabled = 'sec_pin_enabled';
  static const String _keyPinHash = 'sec_pin_hash';
  static const String _keyLockOnBackground = 'sec_lock_on_background';
  static const String _keyPreventScreenshots = 'sec_prevent_screenshots';
  static const String _keyHidePreviews = 'sec_hide_previews';

  bool _isInitialized = false;
  bool _pinEnabled = false;
  String? _pinHash;
  bool _isLocked = false;
  bool _lockOnBackground = true;
  bool _preventScreenshots = false;
  bool _hidePreviews = false;

  bool get isInitialized => _isInitialized;
  bool get pinEnabled => _pinEnabled;
  bool get isLocked => _pinEnabled && _isLocked;
  bool get lockOnBackground => _lockOnBackground;
  bool get preventScreenshots => _preventScreenshots;
  bool get hidePreviews => _hidePreviews;

  SecurityController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pinHash = prefs.getString(_keyPinHash);
      _pinEnabled =
          (prefs.getBool(_keyPinEnabled) ?? false) &&
          (_pinHash != null && _pinHash!.isNotEmpty);
      _lockOnBackground = prefs.getBool(_keyLockOnBackground) ?? true;
      _preventScreenshots = prefs.getBool(_keyPreventScreenshots) ?? false;
      _hidePreviews = prefs.getBool(_keyHidePreviews) ?? false;
      _isLocked = _pinEnabled;
      _isInitialized = true;
      notifyListeners();
      if (_preventScreenshots) {
        await _applySecureFlag(true);
      }
    } catch (_) {
      _isInitialized = true;
      notifyListeners();
    }
  }

  String _hashPin(String pin) => _Sha256.digestHex('inknotes_v1_salt:$pin');

  bool verifyPin(String pin) {
    if (_pinHash == null || _pinHash!.isEmpty) return false;
    return _hashPin(pin) == _pinHash;
  }

  bool unlockWithPin(String pin) {
    if (verifyPin(pin)) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockIfProtected() {
    if (_pinEnabled && _lockOnBackground && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void lockNow() {
    if (_pinEnabled) {
      _isLocked = true;
      notifyListeners();
    }
  }

  Future<void> setPin(String pin) async {
    _pinHash = _hashPin(pin);
    _pinEnabled = true;
    _isLocked = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPinHash, _pinHash!);
      await prefs.setBool(_keyPinEnabled, true);
      await HomeWidgetBridge.refresh();
    } catch (_) {}
  }

  Future<void> disablePin() async {
    _pinEnabled = false;
    _pinHash = null;
    _isLocked = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPinHash);
      await prefs.setBool(_keyPinEnabled, false);
      await HomeWidgetBridge.refresh();
    } catch (_) {}
  }

  Future<void> setLockOnBackground(bool enabled) async {
    _lockOnBackground = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLockOnBackground, enabled);
    } catch (_) {}
  }

  Future<void> setPreventScreenshots(bool enabled) async {
    _preventScreenshots = enabled;
    notifyListeners();
    await _applySecureFlag(enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPreventScreenshots, enabled);
    } catch (_) {}
  }

  Future<void> setHidePreviews(bool enabled) async {
    _hidePreviews = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHidePreviews, enabled);
    } catch (_) {}
  }

  Future<void> resetSecurity() async {
    _pinEnabled = false;
    _pinHash = null;
    _isLocked = false;
    _lockOnBackground = true;
    _preventScreenshots = false;
    _hidePreviews = false;
    notifyListeners();
    await _applySecureFlag(false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPinHash);
      await prefs.remove(_keyPinEnabled);
      await prefs.remove(_keyLockOnBackground);
      await prefs.remove(_keyPreventScreenshots);
      await prefs.remove(_keyHidePreviews);
    } catch (_) {}
  }

  Future<void> _applySecureFlag(bool enabled) async {
    try {
      await _channel.invokeMethod('setSecureScreen', {'enabled': enabled});
    } catch (_) {
      // Safe fallback on non-Android platforms & widget tests
    }
  }
}
