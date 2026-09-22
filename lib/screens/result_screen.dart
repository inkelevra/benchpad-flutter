import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/neumorphic_theme.dart';

/// Current Result — shows the last thing published to BenchPad, ported
/// from benchpad-result.html.
///
/// Simplification note: the PWA reads this from a small local
/// (BenchPadResult) helper that Advertise/Studio write to after a
/// successful publish. That write-side hook isn't wired into every
/// publish flow in the app yet, so this screen may show the empty state
/// more often than the PWA does until that's connected everywhere —
/// the read side and empty-state UI are fully ported.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  static const prefsKey = 'benchpad_last_result_v1';

  /// Call this after a successful publish to make it show up here —
  /// same shape as the PWA's BenchPadResult.write().
  static Future<void> save({
    required String imageDataUrl,
    required String status,
    required String deviceId,
    String location = 'Amsterdam',
    String? jobCode,
    String? source,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode({
      'imageData': imageDataUrl,
      'status': status,
      'deviceId': deviceId,
      'location': location,
      'jobCode': jobCode,
      'source': source,
      'displayedAt': DateTime.now().toIso8601String(),
    }));
  }

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ResultScreen.prefsKey);
    if (mounted) {
      setState(() {
        _result = raw != null ? jsonDecode(raw) as Map<String, dynamic> : null;
        _loading = false;
      });
    }
  }

  Uint8List? _decodeImage(String? dataUrl) {
    if (dataUrl == null) return null;
    final i = dataUrl.indexOf(',');
    if (i == -1) return null;
    try {
      return base64Decode(dataUrl.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: NeumorphicPalette.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: NeumorphicPalette.background,
          foregroundColor: NeumorphicPalette.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Current Result')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: NeumorphicPalette.accent))
            : NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (n) {
                  n.disallowIndicator();
                  return true;
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('BENCHPAD · DISPLAYED', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    const Text('Current result', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('See exactly what appeared on BenchPad.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),
                    if (result == null)
                      NeumorphicBox(
                        flat: true,
                        borderRadius: 20,
                        child: const Column(
                          children: [
                            Text('No result found', style: TextStyle(color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                            SizedBox(height: 6),
                            Text('Publish content and open Current Result again.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    else ...[
                      NeumorphicBox(
                        flat: true,
                        borderRadius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${result['deviceId'] ?? 'BP-AMS-001'} · ${(result['location'] ?? 'Amsterdam').toString().toUpperCase()}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9)),
                                      const Text('Current result on BenchPad', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(color: NeumorphicPalette.success.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
                                  child: Text('${result['status'] ?? 'DISPLAYED'} ✓', style: const TextStyle(color: NeumorphicPalette.success, fontSize: 9, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_decodeImage(result['imageData'] as String?) != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: AspectRatio(aspectRatio: 4 / 3, child: Image.memory(_decodeImage(result['imageData'] as String?)!, fit: BoxFit.cover)),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              [result['jobCode'], result['source'], result['displayedAt'] != null ? DateTime.tryParse(result['displayedAt'] as String)?.toLocal().toString().substring(0, 16) : null, 'Central Display']
                                  .where((v) => v != null && v != '')
                                  .join(' · '),
                              style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: NeumorphicBox(
                              soft: true,
                              borderRadius: 16,
                              onTap: () => Navigator.pop(context),
                              child: const Center(child: Text('SEND ANOTHER', style: TextStyle(color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NeumorphicBox(
                              borderRadius: 16,
                              onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
                              child: const Center(child: Text('DASHBOARD', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 12))),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
