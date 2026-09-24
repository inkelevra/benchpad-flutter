import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which capsules the user has created or opened on this
/// device — the PWA does the same via its own localStorage
/// time-capsule-store.js (its capsule DATA is local-only there; ours
/// is server-backed, so this just remembers which access keys to
/// re-query on Profile's "My Capsules" list).
class CapsuleStore {
  static const _prefsKey = 'benchpad_my_capsules_v1';

  static Future<List<Map<String, dynamic>>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> remember(Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await list();
    existing.removeWhere((r) => r['sphere'] == record['sphere'] && r['type'] == record['type'] && r['number'] == record['number']);
    existing.insert(0, record);
    await prefs.setStringList(_prefsKey, existing.map((r) => jsonEncode(r)).toList());
  }

  /// Looks up the access key this device remembered for one specific
  /// cell/position — used when reopening a "locked" (reserved, not yet
  /// sealed) cell straight from the sphere/grid, so continuing to edit
  /// it doesn't hit the server's access-key check with no key at all.
  static Future<String?> findKey(String sphere, String type, int number) async {
    final all = await list();
    for (final r in all) {
      if (r['sphere'] == sphere && r['type'] == type && r['number'] == number) {
        return r['accessKey'] as String?;
      }
    }
    return null;
  }
}
