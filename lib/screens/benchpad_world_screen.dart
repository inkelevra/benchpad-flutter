import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import 'vault_sphere_screen.dart';
import 'memory_sphere_screen.dart';
import 'roadmap_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart';
import 'secret_room_screen.dart';

/// BenchPad World — navigation hub, ported from benchpad-world.html.
///
/// Restyle pass: moved off dark neon-on-black cards to the app's own
/// light neomorphic language — each card is a raised soft-UI tile
/// (same shadow language as the rest of the app) with a coloured
/// ambient glow bleeding from behind it and a raised neomorphic icon
/// badge in the card's own colour, rather than a stark dark card.
/// Keeps the same 6 colours from benchpad-world.html. Profile and
/// Community (the two "live" cards — a guest identity and an active
/// community) sit as a wider hero row up top; the 4 capsule/secret/
/// roadmap cards sit in a 2x2 grid below — breaks the plain uniform
/// list into a hierarchy instead of 6 identical tiles.
///
/// Cleanup note: the Flutter version had accumulated 14 links here
/// (Report/Feedback, Municipal Info, Current Offers, Local Partners,
/// Current Result, Key Journey, Unlocks, Live Access — none of which
/// the PWA's own benchpad-world.html actually links from World) on
/// top of the real 6 cards. Report/Feedback, Municipal Info, Current
/// Offers and Local Partners are already reachable from Home, so
/// those were just duplicates — removed. Current Result moved to
/// Platform; Key Journey, Unlocks and Live Access moved to Profile
/// (closest thematic fit — personal status/rewards) so they keep a
/// real access path instead of becoming orphaned.
class BenchPadWorldScreen extends StatelessWidget {
  const BenchPadWorldScreen({super.key});

  static const _profileColor = Color(0xFFD9A62B);
  static const _communityColor = Color(0xFF9857E0);
  static const _vaultColor = Color(0xFF2FA855);
  static const _memoryColor = Color(0xFFE0503F);
  static const _secretColor = Color(0xFF2A9BB8);
  static const _roadmapColor = Color(0xFF2E7FFF);

  @override
  Widget build(BuildContext context) {
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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('BenchPad World')),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    const Text('WELCOME TO', style: TextStyle(color: Color(0xFFB8871F), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    const Text('BENCHPAD WORLD', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: NeumorphicPalette.textPrimary, letterSpacing: -1)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _FoundingKeyVideo(),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.64,
                children: [
                  _worldCard(
                    context,
                    color: _profileColor,
                    state: 'GUEST',
                    icon: Icons.person_outline,
                    title: 'My Profile',
                    subtitle: 'Your path into BenchPad World.',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  ),
                  _worldCard(
                    context,
                    color: _communityColor,
                    state: 'ACTIVE',
                    icon: Icons.groups_outlined,
                    title: 'Community',
                    subtitle: 'Meet the first people supporting BenchPad.',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen())),
                  ),
                  _worldCard(
                    context,
                    color: _vaultColor,
                    state: '162 CAPSULES',
                    icon: Icons.workspace_premium_outlined,
                    title: 'Time Capsule 1',
                    typeLabel: 'VAULT SPHERE',
                    subtitle: 'Structured capsule vault with the permanent Founding Twelve.',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultSphereScreen())),
                  ),
                  _worldCard(
                    context,
                    color: _memoryColor,
                    state: '492 CAPSULES',
                    icon: Icons.hub_outlined,
                    title: 'Time Capsule 2',
                    typeLabel: 'MEMORY SPHERE',
                    subtitle: '492 capsules with memories from around the world.',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemorySphereScreen())),
                  ),
                  _worldCard(
                    context,
                    color: _secretColor,
                    state: 'CLASSIFIED',
                    icon: Icons.visibility_off_outlined,
                    title: 'Secret Room',
                    subtitle: 'Not everything is visible.',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecretRoomScreen())),
                  ),
                  _worldCard(
                    context,
                    color: _roadmapColor,
                    state: 'VISUAL LOG',
                    icon: Icons.timeline_outlined,
                    title: 'Roadmap',
                    subtitle: 'Follow project progress through photographs and short descriptions.',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapScreen())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _worldCard(
    BuildContext context, {
    required Color color,
    required String state,
    required IconData icon,
    required String title,
    required String subtitle,
    String? typeLabel,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeumorphicPalette.background,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.75), offset: const Offset(7, 7), blurRadius: 16),
            const BoxShadow(color: Colors.white, offset: Offset(-7, -7), blurRadius: 16),
            BoxShadow(color: color.withOpacity(0.32), offset: const Offset(0, 10), blurRadius: 26, spreadRadius: -8),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(state, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: compact ? 16 : 20),
                Container(
                  width: compact ? 42 : 50,
                  height: compact ? 42 : 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NeumorphicPalette.background,
                    boxShadow: [
                      BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.7), offset: const Offset(3, 3), blurRadius: 6),
                      const BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6),
                      BoxShadow(color: color.withOpacity(0.55), blurRadius: 14),
                    ],
                  ),
                  child: Icon(icon, color: color, size: compact ? 19 : 23),
                ),
                const SizedBox(height: 12),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: NeumorphicPalette.textPrimary, fontSize: compact ? 14 : 15, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                if (typeLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(typeLabel, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
                const SizedBox(height: 6),
                Text(subtitle, maxLines: compact ? 3 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10.5, height: 1.35)),
                if (!compact) const SizedBox(height: 10),
                if (!compact)
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NeumorphicPalette.background,
                      boxShadow: [
                        BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.6), offset: const Offset(2, 2), blurRadius: 4),
                        const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                      ],
                    ),
                    child: Icon(Icons.chevron_right, color: color, size: 17),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Founding Key intro video — ported from benchpad-world.html's
/// world-key-video-stage, autoplay + loop + muted by default with a
/// tap-to-unmute sound button, same as the PWA. mixWithOthers avoids
/// grabbing audio focus from other apps' music while muted (same fix
/// applied to the other autoplay videos in the app).
class _FoundingKeyVideo extends StatefulWidget {
  const _FoundingKeyVideo();

  @override
  State<_FoundingKeyVideo> createState() => _FoundingKeyVideoState();
}

class _FoundingKeyVideoState extends State<_FoundingKeyVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/video/benchpad-founding-key-world.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.7), offset: const Offset(6, 6), blurRadius: 14),
            const BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 14),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready) VideoPlayer(_controller) else Container(color: NeumorphicPalette.shadowDark.withOpacity(0.2)),
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _muted = !_muted;
                    _controller.setVolume(_muted ? 0 : 1);
                  }),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                    child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 17),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
