import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Unlocks — decorative "your access can grow" preview, ported from
/// benchpad-unlocks.html. Purely static in the PWA too (no server calls).
class UnlocksScreen extends StatelessWidget {
  const UnlocksScreen({super.key});

  static const _orange = Color(0xFFFF951F);

  static const _cards = [
    ('★', 'gold', 'FOUNDING ACCESS', 'Early Access', 'See selected BenchPad features before public release.', 'UNLOCKED', true),
    ('▤', 'green', 'LIVE ACCESS', 'Special Live Sessions', 'Priority access to selected BenchPad Live experiences.', 'UNLOCKED', true),
    ('◎', 'blue', 'COMMUNITY', 'Founding Badge', 'A permanent status inside the future BenchPad community.', 'UNLOCKED', true),
    ('🔒', 'purple', 'MYSTERY', 'Unknown Reward', 'This unlock remains hidden until a future milestone is reached.', 'LOCKED', false),
    ('✦', 'orange', 'FUTURE PARTNER BENEFIT', 'Partner Privilege', 'A future benefit offered by participating BenchPad partners.', 'COMING LATER', false),
    ('?', 'red', 'SECRET ROOM', 'Hidden Access', 'Some doors in BenchPad World should remain closed for now.', 'CLASSIFIED', false),
  ];

  static const _colors = {
    'gold': Color(0xFFF0BD3F), 'green': Color(0xFF70DF78), 'blue': Color(0xFF42A8FF),
    'purple': Color(0xFFBD6CFF), 'orange': Color(0xFFFF951F), 'red': Color(0xFFFF5B4D),
  };

  static const _milestones = ['Key Activated', 'World Entered', 'Live Access', 'Next Unlock', 'Unknown'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050606),
      appBar: AppBar(backgroundColor: const Color(0xFF050606), title: const Text('Unlocks')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD6A232), width: 2),
            borderRadius: BorderRadius.circular(30),
            gradient: RadialGradient(center: Alignment.topCenter, radius: 1.1, colors: [_orange.withOpacity(0.12), const Color(0xFF080908)], stops: const [0, 0.5]),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(border: Border.all(color: _orange), borderRadius: BorderRadius.circular(999)),
                child: const Text('UNLOCKS', style: TextStyle(color: _orange, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 24),
              const Text('YOUR ACCESS\nCAN GROW', textAlign: TextAlign.center, style: TextStyle(color: _orange, fontSize: 34, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1)),
              const SizedBox(height: 16),
              const Text('BenchPad World can reveal new privileges, experiences and surprises over time.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB5AD9D), fontSize: 15, height: 1.5)),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: _orange.withOpacity(0.24)), borderRadius: BorderRadius.circular(18), color: _orange.withOpacity(0.07)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CURRENT WORLD LEVEL', style: TextStyle(color: _orange, fontSize: 8, fontWeight: FontWeight.w900)),
                              Text('3', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(border: Border.all(color: _orange.withOpacity(0.26)), borderRadius: BorderRadius.circular(999)),
                          child: const Text('FOUNDING ACCESS', style: TextStyle(color: Color(0xFFFFB35E), fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: 0.68, minHeight: 8, backgroundColor: const Color(0xFF15100A), color: _orange)),
                    const SizedBox(height: 8),
                    const Text('2 more experiences to unlock something new.', style: TextStyle(color: Color(0xFF8A8173), fontSize: 9)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
                children: _cards.map((c) {
                  final color = _colors[c.$2]!;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.08)), borderRadius: BorderRadius.circular(18), color: Colors.white.withOpacity(0.018)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color)),
                          child: Center(child: Text(c.$1, style: TextStyle(color: color, fontSize: 18))),
                        ),
                        const SizedBox(height: 10),
                        Text(c.$3, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text(c.$4, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(c.$5, style: const TextStyle(color: Color(0xFF8A8173), fontSize: 9, height: 1.4)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(999)),
                          child: Text(c.$6, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: List.generate(5, (i) {
                  final active = i < 3;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: active ? _orange.withOpacity(0.18) : Colors.white.withOpacity(0.07)),
                        borderRadius: BorderRadius.circular(14),
                        color: active ? _orange.withOpacity(0.025) : Colors.white.withOpacity(0.015),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? _orange : const Color(0xFF5D5549))),
                            child: Center(child: Text('${i + 1}'.padLeft(2, '0'), style: TextStyle(color: active ? _orange : const Color(0xFF6E665A), fontSize: 8))),
                          ),
                          const SizedBox(height: 6),
                          Text(_milestones[i], textAlign: TextAlign.center, style: TextStyle(color: active ? const Color(0xFFC9A06D) : const Color(0xFF777064), fontSize: 7)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              const Text('Unlocks preview · New access and benefits will appear as BenchPad World and its partner network grow.',
                  textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB8B0A0), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
