import 'dart:async';
import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// BenchPad Pulse — a continuously scrolling ticker combining the live
/// publish counter (GET /api/publish-stats) and local Amsterdam civic
/// updates (GET /api/municipal/local-updates), refreshed every 5
/// minutes. Ported from index.html's #benchpadPulse / v151-benchpad-
/// pulse script — same data sources, same "one aggregated publish line
/// + up to 5 local items" composition, same continuous belt-of-two-
/// copies marquee technique (so the loop point is invisible).
class BenchPadPulse extends StatefulWidget {
  const BenchPadPulse({super.key});

  @override
  State<BenchPadPulse> createState() => _BenchPadPulseState();
}

class _BenchPadPulseState extends State<BenchPadPulse> with SingleTickerProviderStateMixin {
  static const _refreshInterval = Duration(minutes: 5);
  static const _pxPerSecond = 42.0;

  final _api = BenchpadApi();
  late final AnimationController _controller;
  Timer? _refreshTimer;

  String _text = 'Loading live BenchPad activity…';
  final _measureKey = GlobalKey();
  double _textWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
    _refresh();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _api.dispose();
    _controller.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  String? _formatPublishStat(Map<String, dynamic> stats) {
    final total = (stats['totalPublications'] as num?)?.toInt() ?? 0;
    final countries = (stats['distinctCountries'] as num?)?.toInt() ?? 0;
    if (total == 0) return null;
    final totalText = total.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return countries > 1
        ? '$totalText publications on BenchPad · $countries countries'
        : '$totalText publications on BenchPad';
  }

  String? _formatLocalItem(Map<String, dynamic> item) {
    final label = ((item['categoryLabel'] ?? item['type'] ?? '') as String).trim();
    final title = ((item['title'] ?? '') as String).trim();
    final distance = ((item['distance'] ?? '') as String).trim();
    final body = [label, title].where((s) => s.isNotEmpty).join(': ');
    final parts = ['AMSTERDAM', body, distance].where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _refresh() async {
    final messages = <String>[];
    try {
      final stats = await _api.getPublishStats();
      final m = _formatPublishStat(stats);
      if (m != null) messages.add(m);
    } catch (_) {
      // Keep going — a missing stat just means one fewer line.
    }
    try {
      final local = await _api.getMunicipalUpdates();
      final updates = (local['updates'] as List?) ?? [];
      for (final item in updates.take(5)) {
        final m = _formatLocalItem(item as Map<String, dynamic>);
        if (m != null) messages.add(m);
      }
    } catch (_) {
      // Same — keep whatever was already shown rather than blanking it.
    }
    if (messages.isEmpty || !mounted) return;

    setState(() {
      _text = '${messages.join('   •   ')}   •   ';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _remeasure());
  }

  void _remeasure() {
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final width = box.size.width;
    if (width <= 0) return;
    final seconds = (width / _pxPerSecond).clamp(14, 60).toDouble();
    _textWidth = width;
    _controller
      ..duration = Duration(milliseconds: (seconds * 1000).round())
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 11, fontWeight: FontWeight.w700);

    return NeumorphicBox(
      borderRadius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Text('BENCHPAD PULSE',
              style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(width: 8),
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 16,
              child: ClipRect(
                child: Stack(
                  children: [
                    // Off-screen measuring copy — invisible, used only
                    // to size the marquee duration to the text length.
                    Opacity(
                      opacity: 0,
                      child: Text(_text, key: _measureKey, style: textStyle, maxLines: 1, softWrap: false),
                    ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final dx = _textWidth > 0 ? -(_controller.value * _textWidth) : 0.0;
                        return Stack(
                          children: [
                            Transform.translate(offset: Offset(dx, 0), child: Text(_text, style: textStyle, maxLines: 1, softWrap: false)),
                            Transform.translate(offset: Offset(dx + _textWidth, 0), child: Text(_text, style: textStyle, maxLines: 1, softWrap: false)),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
