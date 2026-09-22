import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Key Journey — decorative "your Founding Key has a story" preview,
/// ported from benchpad-key-journey.html. Purely static in the PWA too
/// (no server calls) — a preview of a future personal-timeline feature.
class KeyJourneyScreen extends StatelessWidget {
  const KeyJourneyScreen({super.key});

  static const _purple = Color(0xFFBD6CFF);
  static const _gold = Color(0xFFD7A83E);
  static const _green = Color(0xFF70DF78);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050606),
      appBar: AppBar(backgroundColor: const Color(0xFF050606), title: const Text('Key Journey')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
          decoration: BoxDecoration(
            border: Border.all(color: _gold, width: 2),
            borderRadius: BorderRadius.circular(30),
            gradient: RadialGradient(center: Alignment.topCenter, radius: 1.1, colors: [_purple.withOpacity(0.12), const Color(0xFF080908)], stops: const [0, 0.5]),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(border: Border.all(color: _purple), borderRadius: BorderRadius.circular(999)),
                child: const Text('KEY JOURNEY', style: TextStyle(color: _purple, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.vpn_key_outlined, color: _purple, size: 56),
              const SizedBox(height: 18),
              const Text('YOUR KEY HAS\nA STORY', textAlign: TextAlign.center, style: TextStyle(color: _purple, fontSize: 34, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1)),
              const SizedBox(height: 16),
              const Text(
                'Every meaningful BenchPad interaction can become part of your personal journey.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB5AD9D), fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 30),
              _buildMap(),
              const SizedBox(height: 24),
              _buildTimeline(),
              const SizedBox(height: 20),
              _buildStats(),
              const SizedBox(height: 20),
              _buildMemoryCard(),
              const SizedBox(height: 20),
              const Text(
                'Journey preview · Your real BenchPad Live sessions, Key interactions and milestones will build this story over time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB8B0A0), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _purple.withOpacity(0.24)),
        borderRadius: BorderRadius.circular(20),
        gradient: RadialGradient(colors: [_purple.withOpacity(0.09), const Color(0xFF030405)], radius: 1),
      ),
      child: Stack(
        children: [
          _cityMarker('Amsterdam', 'Key activated', _gold, Alignment.bottomLeft),
          _cityMarker('Tokyo', 'Live session', _green, Alignment.topRight),
          _cityMarker('Warsaw', 'Future milestone', _purple, Alignment.center),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: _purple.withOpacity(0.22)), borderRadius: BorderRadius.circular(14), color: const Color(0xD9050407)),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('JOURNEY DISTANCE', style: TextStyle(color: _purple, fontSize: 7, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('9,287 km', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('across your BenchPad story', style: TextStyle(color: Color(0xFF81796B), fontSize: 8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cityMarker(String name, String label, Color color, Alignment align) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 4), color: const Color(0xFF050606), boxShadow: [BoxShadow(color: color, blurRadius: 10)])),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: Color(0xFF80786C), fontSize: 7)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: [
        _timelineEvent('01', _gold, '2026', 'Founding Key activated', 'Your physical BenchPad Key entered BenchPad World.'),
        const SizedBox(height: 8),
        _timelineEvent('02', _green, 'FIRST LIVE SESSION', 'Amsterdam BenchPad reached', 'A real BenchPad received your content remotely.'),
        const SizedBox(height: 8),
        _timelineEvent('03', _purple, 'FUTURE', 'The journey continues', 'New cities, milestones and unlocks can appear here.'),
      ],
    );
  }

  Widget _timelineEvent(String number, Color color, String date, String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.07)), borderRadius: BorderRadius.circular(16), color: Colors.white.withOpacity(0.015)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color)),
            child: Center(child: Text(number, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: Color(0xFF81796B), fontSize: 10, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = [('3', 'Journey milestones'), ('2', 'Cities connected'), ('1', 'Physical Key'), ('∞', 'Future possibilities')];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: stats.map((s) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: _purple.withOpacity(0.14)), borderRadius: BorderRadius.circular(14), color: _purple.withOpacity(0.025)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s.$1, style: const TextStyle(color: _purple, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(s.$2, style: const TextStyle(color: Color(0xFF827B6F), fontSize: 8)),
              ],
            ),
          )).toList(),
    );
  }

  Widget _buildMemoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _gold, width: 2),
        borderRadius: BorderRadius.circular(18),
        gradient: RadialGradient(center: Alignment.topRight, radius: 1.2, colors: [_purple.withOpacity(0.1), const Color(0xFF080908)]),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.vpn_key, color: _gold, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR BENCHPAD JOURNEY', style: TextStyle(color: _gold, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 5),
                const Text('Founding Key #000247', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('A future shareable record of the places, interactions and milestones connected to your Key.', style: TextStyle(color: Color(0xFF81796B), fontSize: 9, height: 1.4)),
              ],
            ),
          ),
          const Text('#000247', style: TextStyle(color: _purple, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
