import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide language switch (English / Dutch), mirroring the PWA's own
/// header language toggle (index.html's .language-switch NL/EN buttons)
/// instead of requiring a trip through system/app settings.
///
/// Scope note: this ships the toggle mechanism plus translations for
/// the Home screen's own visible text. Translating every other screen
/// is a separate, larger follow-up — screens that don't yet read
/// [AppLanguage] simply stay in English regardless of the toggle.
class AppLanguage extends ChangeNotifier {
  static const _prefsKey = 'benchpadLanguage';

  String _code = 'en';
  String get code => _code;
  bool get isDutch => _code == 'nl';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'nl' || saved == 'en') {
      _code = saved!;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'nl') return;
    if (_code == code) return;
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }

  /// Looks up [en] against [nl] for the current language — the same
  /// small-dictionary pattern as the PWA's tr() helper, just inline per
  /// call site instead of a giant shared string table.
  String t(String en, String nl) => isDutch ? nl : en;
}
