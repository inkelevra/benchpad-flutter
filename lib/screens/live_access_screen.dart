import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/app_theme.dart';
import 'benchpad_live_screen.dart';

/// Live Access — "control a real BenchPad" gate/teaser, ported from
/// benchpad-live-access.html. Shows current participant count and
/// whether live publishing is open, then leads into the BenchPad Live
/// submission flow.
class LiveAccessScreen extends StatefulWidget {
  const LiveAccessScreen({super.key});

  static const _green = Color(0xFF70DF78);

  @override
  State<LiveAccessScreen> createState() => _LiveAccessScreenState();
}

class _LiveAccessScreenState extends State<LiveAccessScreen> {
  final _api = BenchpadApi();
  String _statusText = 'Checking public live access…';
  int _count = 0;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getLiveStatus();
      final n = (data['participantCount'] as num?)?.toInt() ?? 0;
      final active = data['publicPublishing'] == 'ACTIVE';
      setState(() {
        _count = n;
        _active = active;
        _statusText = active ? 'Live publishing is available' : 'Live publishing is temporarily paused';
      });
    } catch (_) {
      setState(() => _statusText = 'Live status temporarily unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050606),
      appBar: AppBar(backgroundColor: const Color(0xFF050606), title: const Text('Live Access')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD6A232), width: 2),
            borderRadius: BorderRadius.circular(30),
            gradient: RadialGradient(center: Alignment.topCenter, radius: 1.1, colors: [LiveAccessScreen._green.withOpacity(0.12), const Color(0xFF080908)], stops: const [0, 0.5]),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(border: Border.all(color: LiveAccessScreen._green), borderRadius: BorderRadius.circular(999)),
                child: const Text('LIVE ACCESS', style: TextStyle(color: LiveAccessScreen._green, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 24),
              const Text('CONTROL A\nREAL BENCHPAD', textAlign: TextAlign.center, style: TextStyle(color: LiveAccessScreen._green, fontSize: 32, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1)),
              const SizedBox(height: 12),
              const Text('Your message. A real BenchPad. Live.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB5AD9D), fontSize: 15)),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF2F5B3B)), borderRadius: BorderRadius.circular(16), color: const Color(0xFF07170D)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BENCHPAD LIVE · CURRENT STATUS', style: TextStyle(color: LiveAccessScreen._green, fontSize: 8, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(_statusText, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$_count', style: const TextStyle(color: Color(0xFFEFC15A), fontSize: 22, fontWeight: FontWeight.w800)),
                        const Text('PARTICIPANTS', style: TextStyle(color: Color(0xFF8D948C), fontSize: 7, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: _step('01', 'Create', 'Send a message or image.')),
                  const SizedBox(width: 8),
                  Expanded(child: _step('02', 'Moderate', 'Content is checked before publishing.')),
                  const SizedBox(width: 8),
                  Expanded(child: _step('03', 'Go Live', 'Watch the BenchPad display update.')),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: LiveAccessScreen._green, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BenchPadLiveScreen())),
                  child: const Text('START BENCHPAD LIVE SESSION →', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'BenchPad Live checks every public submission automatically. The physical display experience will become fully live when BP-AMS-001 is online.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB8B0A0), fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String number, String title, String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.07)), borderRadius: BorderRadius.circular(14), color: Colors.white.withOpacity(0.018)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: const TextStyle(color: LiveAccessScreen._green, fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(text, style: const TextStyle(color: Color(0xFF81796B), fontSize: 8, height: 1.4)),
        ],
      ),
    );
  }
}
