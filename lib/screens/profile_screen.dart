import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/benchpad_api.dart';
import '../services/notification_service.dart';
import '../services/capsule_store.dart';
import '../widgets/home_back_leading.dart';
import '../theme/benchpad_dark_theme.dart';
import 'vault_sphere_screen.dart';
import 'memory_sphere_screen.dart';
import 'hex_grid_screen.dart';
import 'capsule_creator_screen.dart';

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
    final list = await CapsuleStore.list();
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
      await CapsuleStore.remember({'accessKey': key, 'sphere': sphere, 'type': type, 'number': number, 'status': data['status']});
      final openingDateStr = data['openingDate'] as String?;
      if (openingDateStr != null) {
        final openingDate = DateTime.tryParse(openingDateStr);
        if (openingDate != null) {
          NotificationService.instance.scheduleCapsuleOpening(
            notificationId: key.hashCode & 0x7fffffff,
            title: 'Your capsule has opened',
            body: '${sphere == 'orbit' ? 'Time Capsule 2' : 'Time Capsule 1'} capsule is ready to view.',
            openingDate: openingDate,
          );
        }
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: type, number: number, ownerKey: key, sphere: sphere)));
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
        scaffoldBackgroundColor: BPColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: BPColors.bg,
          foregroundColor: BPColors.textPrimary,
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
              DarkCard(
                flat: true,
                borderRadius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.circle, size: 8, color: BPColors.danger),
                        SizedBox(width: 8),
                        Text('No key connected', style: TextStyle(color: BPColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('MY PROFILE', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    const Text(
                      'FIND YOUR PLACE IN\nBENCHPAD WORLD',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: BPColors.textPrimary, height: 1.1, letterSpacing: -0.5),
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
                            style: TextStyle(color: BPColors.textSecondary, fontSize: 12),
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
              DarkCard(
                flat: true,
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BENCHPAD KEY', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    const Text('Member ######', style: TextStyle(color: BPColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose Time Capsule 1, 2 or 3 to create your first one.',
                      style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DarkCard(
                            soft: true,
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultSphereScreen())),
                            child: const Center(child: Text('TIME CAPSULE 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: BPColors.textPrimary))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DarkCard(
                            soft: true,
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemorySphereScreen())),
                            child: const Center(child: Text('TIME CAPSULE 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: BPColors.textPrimary))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DarkCard(
                      soft: true,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HexGridScreen())),
                      child: const Center(child: Text('TIME CAPSULE 3', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: BPColors.textPrimary))),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: BPColors.border),
                    const SizedBox(height: 16),
                    const Text('ALREADY HAVE A CAPSULE?', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter the access key you received when your capsule was set up. It looks like BP-XXXXX-XXXXX.',
                      style: TextStyle(color: BPColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    DarkCard(
                      flat: true,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: _keyController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1, fontSize: 13, color: BPColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'ACCESS KEY',
                          labelStyle: TextStyle(color: BPColors.textSecondary, fontSize: 11),
                          hintText: 'BP-XXXXX-XXXXX',
                          hintStyle: TextStyle(color: BPColors.textSecondary, fontSize: 13),
                          border: InputBorder.none,
                          filled: false,
                        ),
                        onSubmitted: (_) => _openMyCapsule(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: BPColors.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: 14),
                    DarkCard(
                      borderRadius: 14,
                      onTap: _busy ? null : _openMyCapsule,
                      child: Center(child: Text(_busy ? 'Searching...' : 'OPEN MY CAPSULE', style: const TextStyle(color: BPColors.yellow, fontWeight: FontWeight.w800, fontSize: 13))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_myCapsules.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('TIME CAPSULES', style: TextStyle(color: BPColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('My Capsules', style: TextStyle(color: BPColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14))),
                    Text('${_myCapsules.length} ACTIVE', style: const TextStyle(color: BPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                ..._myCapsules.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DarkCard(
                        flat: true,
                        borderRadius: 14,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: r['type'] as String, number: (r['number'] as num).toInt(), ownerKey: r['accessKey'] as String))),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: BPColors.yellow.withOpacity(0.1)),
                              child: Text(r['sphere'] == 'orbit' ? '●' : (r['type'] == 'core' ? '⬟' : '⬡'), style: const TextStyle(color: BPColors.yellow, fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${r['sphere'] == 'orbit' ? 'TIME CAPSULE 2' : 'TIME CAPSULE 1'} · ${(r['status'] as String? ?? 'locked').toUpperCase()}', style: const TextStyle(color: BPColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(_capsuleDisplayId(r), style: const TextStyle(color: BPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: BPColors.textSecondary),
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
            ],
          ),
        ),
      ),
    );
  }

  /// Matches the PWA's own describe() id formatting exactly.
  String _capsuleDisplayId(Map<String, dynamic> r) {
    final number = (r['number'] as num).toInt();
    if (r['sphere'] == 'orbit') return 'BP-ORB-${number.toString().padLeft(6, '0')}';
    if (r['type'] == 'core') return 'BP-CORE-${number.toString().padLeft(2, '0')}';
    return 'BP-TC-${number.toString().padLeft(6, '0')}';
  }

  Widget _metaCell(String label, String value) {
    return DarkCard(
      flat: true,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: BPColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BPColors.textPrimary)),
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
                BoxShadow(color: Colors.black.withOpacity(0.7), offset: const Offset(6, 6), blurRadius: 14),
                BoxShadow(color: BPColors.yellow.withOpacity(0.18), offset: Offset(-6, -6), blurRadius: 14),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_ready) VideoPlayer(_controller) else Container(color: BPColors.border.withOpacity(0.2)),
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
          style: TextStyle(color: BPColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
