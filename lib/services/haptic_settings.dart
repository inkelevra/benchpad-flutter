import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide haptic feedback (vibration on button taps) on/off switch,
/// exposed in App Settings. Defaults to on, matching the app's
/// existing behavior before this setting existed.
class HapticSettings extends ChangeNotifier {
  static const _prefsKey = 'benchpadHapticEnabled';

  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefsKey);
    if (saved != null) {
      _enabled = saved;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
