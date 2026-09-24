import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeChoice { light, dark, auto }

/// App-wide Light/Dark/Auto theme setting, exposed in App Settings.
/// Defaults to Light. "Auto" mirrors the PWA's own behavior — it
/// follows the device's system light/dark setting (Android's own dark
/// mode toggle), not a time-of-day calculation.
class ThemeSettings extends ChangeNotifier {
  static const _prefsKey = 'benchpadThemeChoice';

  AppThemeChoice _choice = AppThemeChoice.light;
  AppThemeChoice get choice => _choice;
  bool get isAuto => _choice == AppThemeChoice.auto;

  // Remembers the last explicit (non-auto) pick, so turning Auto back
  // off resumes whichever of Light/Dark was chosen before, instead of
  // always resetting to Light.
  AppThemeChoice _lastExplicit = AppThemeChoice.light;

  ThemeMode get flutterThemeMode {
    switch (_choice) {
      case AppThemeChoice.light:
        return ThemeMode.light;
      case AppThemeChoice.dark:
        return ThemeMode.dark;
      case AppThemeChoice.auto:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      final match = AppThemeChoice.values.where((v) => v.name == saved);
      if (match.isNotEmpty) {
        _choice = match.first;
        if (_choice != AppThemeChoice.auto) _lastExplicit = _choice;
        notifyListeners();
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _choice.name);
  }

  /// Picks Light or Dark explicitly — also turns Auto off, matching
  /// the common pattern where manually choosing a mode overrides
  /// "follow system".
  Future<void> setExplicit(bool dark) async {
    _choice = dark ? AppThemeChoice.dark : AppThemeChoice.light;
    _lastExplicit = _choice;
    notifyListeners();
    await _persist();
  }

  /// Turns Auto (follow system) on or off. Turning it off resumes the
  /// last explicit Light/Dark pick.
  Future<void> setAuto(bool value) async {
    _choice = value ? AppThemeChoice.auto : _lastExplicit;
    notifyListeners();
    await _persist();
  }
}
