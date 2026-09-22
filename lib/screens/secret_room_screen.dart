import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/home_back_leading.dart';

/// Secret Room — decorative teaser page, ported from
/// benchpad-secret-room.html. Purely static in the PWA too (no server
/// calls at all) — a Kickstarter-style intrigue teaser hinting at
/// future hidden content gated by Founding Key status.
class SecretRoomScreen extends StatelessWidget {
  const SecretRoomScreen({super.key});

  static const _accent = Color(0xFFFF5B4D);
  static const _gold = Color(0xFFD7A83E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050606),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050606),
        leading: Builder(builder: backLeading),
        leadingWidth: 64,
        centerTitle: true,
        title: const Text('Secret Room'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
          decoration: BoxDecoration(
            border: Border.all(color: _gold, width: 2),
            borderRadius: BorderRadius.circular(30),
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.1,
              colors: [_accent.withOpacity(0.12), const Color(0xFF080908)],
              stops: const [0, 0.5],
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(8, 8), blurRadius: 18),
              BoxShadow(color: Color(0xFF17191D), offset: Offset(-8, -8), blurRadius: 18),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(border: Border.all(color: _accent), borderRadius: BorderRadius.circular(999)),
                child: const Text('SECRET ROOM', style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.hexagon_outlined, color: _accent, size: 60),
              const SizedBox(height: 20),
              const Text('NOT EVERYTHING\nIS VISIBLE', textAlign: TextAlign.center, style: TextStyle(color: _accent, fontSize: 34, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1)),
              const SizedBox(height: 16),
              const Text(
                'Some parts of BenchPad World are meant to be discovered, not announced.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB5AD9D), fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 34),
              _buildVault(),
              const SizedBox(height: 30),
              _buildClassifiedGrid(),
              const SizedBox(height: 16),
              _buildSignal(),
              const SizedBox(height: 16),
              _buildWarning(),
              const SizedBox(height: 20),
              const Text(
                'The purpose of the Secret Room remains intentionally undisclosed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB8B0A0), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVault() {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _accent.withOpacity(0.3))),
          ),
          Transform.rotate(
            angle: 0.3,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accent.withOpacity(0.3), style: BorderStyle.solid),
              ),
            ),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB9443B), width: 2),
              gradient: RadialGradient(colors: [const Color(0xFF1C0B0A), const Color(0xFF070707)], radius: 0.9),
              boxShadow: [BoxShadow(color: _accent.withOpacity(0.12), blurRadius: 24)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, color: _accent, size: 32),
                const SizedBox(height: 6),
                const Text('ACCESS STATUS', style: TextStyle(color: _accent, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 3),
                const Text('PARTIALLY LOCKED', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('FOUNDING KEY #000247', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassifiedGrid() {
    return Column(
      children: [
        _classifiedCard(code: 'SR-01', icon: '✦', label: 'DISCOVERED', title: 'The Room Exists', text: 'Your Key has revealed that there is more beyond the visible platform.', obscured: false, locked: false),
        const SizedBox(height: 10),
        _classifiedCard(code: 'SR-02', icon: '?', label: 'CLASSIFIED', title: '████ ██████', text: '████████ █████ ███████ ████ ████████.', obscured: true, locked: false),
        const SizedBox(height: 10),
        _classifiedCard(code: 'SR-03', icon: '⌁', label: 'REQUIRES A FUTURE EVENT', title: 'Signal Not Yet Received', text: 'This part of the room will respond when the right moment arrives.', obscured: false, locked: true),
      ],
    );
  }

  Widget _classifiedCard({required String code, required String icon, required String label, required String title, required String text, required bool obscured, required bool locked}) {
    final textColor = obscured ? const Color(0xFF5B514B) : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _accent.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0A0B0C),
        boxShadow: [
          const BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 10),
          BoxShadow(color: const Color(0xFF17191D), offset: const Offset(-5, -5), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _accent)),
                child: Center(child: Text(icon, style: const TextStyle(color: _accent, fontSize: 18))),
              ),
              const Spacer(),
              Text(code, style: const TextStyle(color: Color(0xFF5E4B48), fontSize: 9, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(color: _accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: obscured ? 1 : 0)),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(color: obscured ? const Color(0xFF5B514B) : const Color(0xFF82786E), fontSize: 11, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSignal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _accent.withOpacity(0.17)),
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0A0B0C),
        boxShadow: [
          const BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 10),
          BoxShadow(color: const Color(0xFF17191D), offset: const Offset(-5, -5), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [12.0, 34.0, 50.0, 27.0, 16.0].map((h) => Container(
                    width: 3,
                    height: h,
                    decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 8)]),
                  )).toList(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ENCRYPTED BENCHPAD SIGNAL', style: TextStyle(color: _accent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text('Waiting for the next transmission...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('The Secret Room may change without appearing in the public platform menu.', style: TextStyle(color: Color(0xFF81766D), fontSize: 10, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: _gold.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0A0B0C),
        boxShadow: [
          const BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 8),
          BoxShadow(color: const Color(0xFF17191D), offset: const Offset(-4, -4), blurRadius: 8),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _gold)),
            child: const Center(child: Text('!', style: TextStyle(color: _gold, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FOUNDING KEY ACCESS DETECTED', style: TextStyle(color: Color(0xFFE4B54B), fontSize: 9, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Future content may depend on Key status, milestones, live events or hidden invitations.', style: TextStyle(color: Color(0xFF81796B), fontSize: 10, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
