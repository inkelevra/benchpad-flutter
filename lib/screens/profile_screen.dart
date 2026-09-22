import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../services/benchpad_api.dart';
import '../services/notification_service.dart';
import '../widgets/home_back_leading.dart';
import '../theme/neumorphic_theme.dart';
import 'vault_sphere_screen.dart';
import 'memory_sphere_screen.dart';
import 'capsule_creator_screen.dart';
import 'key_journey_screen.dart';
import 'unlocks_screen.dart';
import 'live_access_screen.dart';

/// Remembers which capsules were successfully opened on this device —
/// the PWA does the same via its own localStorage time-capsule-store.js
/// (its capsule DATA is local-only there; ours is server-backed, so
/// this just remembers which access keys to re-query on Profile).
class _CapsuleStore {
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
}

/// My Profile — ported from benchpad-profile.html.
///
/// Includes the "find my capsule by access key" functionality, moved
/// here from the standalone My Capsule screen (mirrors the same move
/// made in the PWA — see capsule_access_screen.dart's header comment).
///
/// Simplification note: the full PWA page shows a rich member dashboard
/// (world level, badges, QR code, activity feed, capsule list) once a
/// "BenchPad World membership" is active — driven by a localStorage flag
/// set by a membership script not ported yet (no membership-claiming
/// flow exists in the app currently). Every visitor is effectively a
/// "guest" in practice, so this screen shows that state faithfully.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = BenchpadApi();
  final _keyController = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _gold = Color(0xFFB8871F);
  List<Map<String, dynamic>> _myCapsules = [];

  @override
  void initState() {
    super.initState();
    _loadMyCapsules();
  }

  Future<void> _loadMyCapsules() async {
    final list = await _CapsuleStore.list();
    if (mounted) setState(() => _myCapsules = list);
  }

  @override
  void dispose() {
    _api.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _openMyCapsule() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Enter your access key.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final data = await _api.findCapsuleByKey(key);
      final type = (data['type'] ?? 'standard') as String;
      final number = (data['number'] as num?)?.toInt() ?? 1;
      final sphere = (data['sphere'] ?? 'vault') as String;
      await _CapsuleStore.remember({'accessKey': key, 'sphere': sphere, 'type': type, 'number': number, 'status': data['status']});
      final openingDateStr = data['openingDate'] as String?;
      if (openingDateStr != null) {
        final openingDate = DateTime.tryParse(openingDateStr);
        if (openingDate != null) {
          NotificationService.instance.scheduleCapsuleOpening(
            notificationId: key.hashCode & 0x7fffffff,
            title: 'Your capsule has opened',
            body: '${sphere == 'orbit' ? 'Memory Sphere' : 'Vault Sphere'} capsule is ready to view.',
            openingDate: openingDate,
          );
        }
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: type, number: number, ownerKey: key)));
      _loadMyCapsules();
    } catch (e) {
      setState(() => _error = e.toString().contains('404') || e.toString().toLowerCase().contains('not found')
          ? 'That access key was not found.'
          : 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
        appBar: AppBar(
          leading: Builder(builder: backLeading),
          leadingWidth: 64,
          centerTitle: true,
          title: const Text('My Profile'),
        ),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NeumorphicBox(
                flat: true,
                borderRadius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.circle, size: 8, color: NeumorphicPalette.danger),
                        SizedBox(width: 8),
                        Text('No key connected', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('MY PROFILE', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    const Text(
                      'FIND YOUR PLACE IN\nBENCHPAD WORLD',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: NeumorphicPalette.textPrimary, height: 1.1, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: const Border(left: BorderSide(color: _gold, width: 3)),
                        borderRadius: BorderRadius.circular(10),
                        color: _gold.withOpacity(0.08),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR MEMBER IDENTITY', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w800)),
                          SizedBox(height: 6),
                          Text(
                            'Your member number and private features will appear here after you claim a capsule or Founding Key.',
                            style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _ProfileCapsuleVideo(),
              const SizedBox(height: 16),
              NeumorphicBox(
                flat: true,
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BENCHPAD KEY', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    const Text('Member ######', style: TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose Vault Sphere or Memory Sphere to create your first Time Capsule.',
                      style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicBox(
                            soft: true,
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultSphereScreen())),
                            child: const Center(child: Text('VAULT SPHERE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NeumorphicBox(
                            soft: true,
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemorySphereScreen())),
                            child: const Center(child: Text('MEMORY SPHERE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: NeumorphicPalette.shadowDark),
                    const SizedBox(height: 16),
                    const Text('ALREADY HAVE A CAPSULE?', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter the access key you received when your capsule was set up. It looks like BP-XXXXX-XXXXX.',
                      style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    NeumorphicBox(
                      flat: true,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: _keyController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1, fontSize: 13, color: NeumorphicPalette.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'ACCESS KEY',
                          labelStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
                          hintText: 'BP-XXXXX-XXXXX',
                          hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
                          border: InputBorder.none,
                          filled: false,
                        ),
                        onSubmitted: (_) => _openMyCapsule(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: 14),
                    NeumorphicBox(
                      borderRadius: 14,
                      onTap: _busy ? null : _openMyCapsule,
                      child: Center(child: Text(_busy ? 'Searching...' : 'OPEN MY CAPSULE', style: const TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 13))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_myCapsules.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('TIME CAPSULES', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('My Capsules', style: TextStyle(color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 14))),
                    Text('${_myCapsules.length} ACTIVE', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                ..._myCapsules.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NeumorphicBox(
                        flat: true,
                        borderRadius: 14,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: r['type'] as String, number: (r['number'] as num).toInt(), ownerKey: r['accessKey'] as String))),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: NeumorphicPalette.accent.withOpacity(0.1)),
                              child: Text(r['sphere'] == 'orbit' ? '●' : (r['type'] == 'core' ? '⬟' : '⬡'), style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${r['sphere'] == 'orbit' ? 'MEMORY SPHERE' : 'VAULT SPHERE'} · ${(r['status'] as String? ?? 'locked').toUpperCase()}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(_capsuleDisplayId(r), style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: NeumorphicPalette.textSecondary),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(child: _metaCell('MEMBER SINCE', '----')),
                  const SizedBox(width: 8),
                  Expanded(child: _metaCell('STATUS', '----')),
                ],
              ),
              const SizedBox(height: 20),
              const Text('YOUR JOURNEY', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 10),
              _journeyLink('Key Journey', 'Your Founding Key has a story', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KeyJourneyScreen()))),
              const SizedBox(height: 8),
              _journeyLink('Unlocks', 'Your access can grow', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnlocksScreen()))),
              const SizedBox(height: 8),
              _journeyLink('Live Access', 'Control a real BenchPad', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveAccessScreen()))),
            ],
          ),
        ),
      ),
    );
  }

  /// Matches the PWA's own describe() id formatting exactly.
  String _capsuleDisplayId(Map<String, dynamic> r) {
    final number = (r['number'] as num).toInt();
    if (r['sphere'] == 'orbit') return 'MEMORY SPHERE ${number.toString().padLeft(3, '0')}';
    if (r['type'] == 'core') return 'BP-CORE-${number.toString().padLeft(2, '0')}';
    return 'BP-TC-${number.toString().padLeft(6, '0')}';
  }

  Widget _journeyLink(String title, String subtitle, VoidCallback onTap) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 14,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: NeumorphicPalette.textSecondary),
        ],
      ),
    );
  }

  Widget _metaCell(String label, String value) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
        ],
      ),
    );
  }
}

/// Time Capsule AI concept video — ported from benchpad-profile.html's
/// video-stage, autoplay + loop + muted with a tap-to-unmute button and
/// the same disclosure caption as the PWA (this is a concept
/// visualization, not the real working prototype).
class _ProfileCapsuleVideo extends StatefulWidget {
  const _ProfileCapsuleVideo();

  @override
  State<_ProfileCapsuleVideo> createState() => _ProfileCapsuleVideoState();
}

class _ProfileCapsuleVideoState extends State<_ProfileCapsuleVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/video/time-capsule-ai-concept.mp4',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
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
        ),
        const SizedBox(height: 6),
        const Text(
          'AI-generated concept visualization — does not depict the current working prototype.',
          style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
