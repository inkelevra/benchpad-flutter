import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';
import '../services/benchpad_api.dart';
import 'publish_queue_screen.dart';
import 'content_moderation_screen.dart';

/// Control Room — owner-only admin panel, ported from control-room.html.
///
/// Covers: live stats (queued/needs review/live/completed/failed),
/// pause/resume public publishing, enable/disable AI moderation,
/// emergency-stop all queued jobs, and force-run capsule auto-publish.
///
/// This is destructive-action territory (same as the PWA), so every
/// dangerous action keeps its confirm() dialog equivalent here.
class ControlRoomScreen extends StatefulWidget {
  const ControlRoomScreen({super.key});

  @override
  State<ControlRoomScreen> createState() => _ControlRoomScreenState();
}

class _ControlRoomScreenState extends State<ControlRoomScreen> {
  final _api = BenchpadApi();
  ControlRoomStatus? _status;
  String? _error;
  bool _busy = false;
  String? _debugOutput;

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
      final status = await _api.getControlRoomStatus();
      if (mounted) setState(() { _status = status; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeumorphicPalette.background,
        titleTextStyle: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14),
        title: Text(title),
        content: Text(message, style: const TextStyle(color: NeumorphicPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: NeumorphicPalette.danger)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _togglePublishing() async {
    if (_status == null) return;
    final next = _status!.publicPublishing == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
    setState(() => _busy = true);
    try {
      await _api.togglePublicPublishing(next);
      await _load();
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAiModeration() async {
    if (_status == null) return;
    final next = _status!.aiModeration == 'ACTIVE' ? 'DISABLED' : 'ACTIVE';
    if (next == 'DISABLED') {
      final ok = await _confirm(
        'Turn off AI moderation?',
        'Every publish (Advertise, Studio) will go live instantly with no safety/policy check. '
            'Only do this while publishing is limited to trusted people.',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await _api.toggleAiModeration(next);
      await _load();
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emergencyStop() async {
    final ok = await _confirm(
      'Emergency stop',
      'Cancel every queued job across ALL sources right now? Jobs already sending will finish normally.',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final cancelled = await _api.emergencyStopAllQueued();
      _toast('Cancelled $cancelled queued job(s)');
      await _load();
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _debugForcePublish() async {
    setState(() { _busy = true; _debugOutput = 'Running...'; });
    try {
      final result = await _api.debugForceCapsulePublish();
      setState(() => _debugOutput = result.toString());
      await _load();
    } catch (e) {
      setState(() => _debugOutput = 'Error: $e');
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
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.textPrimary, disabledForegroundColor: NeumorphicPalette.textSecondary, side: const BorderSide(color: NeumorphicPalette.accent)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: NeumorphicPalette.accent),
        ),
      ),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Control Room'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('OWNER ONLY', style: TextStyle(color: NeumorphicPalette.accent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger)),
              ),
            if (_status != null) _buildStatsGrid(_status!),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: 'Publishing',
              subtitle: "What's going out to the display right now",
              children: [
                _buildStateRow(
                  label: 'PUBLIC PUBLISHING',
                  note: 'Emergency municipal jobs stay a separate highest-priority layer.',
                  state: _status?.publicPublishing ?? '—',
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy || _status == null ? null : _togglePublishing,
                  child: Text(
                    _status?.publicPublishing == 'ACTIVE' ? 'PAUSE PUBLIC PUBLISHING' : 'RESUME PUBLIC PUBLISHING',
                  ),
                ),
                const SizedBox(height: 16),
                _buildStateRow(
                  label: 'AI MODERATION',
                  note: 'Safety + policy check before publish. Costs OpenAI credit per attempt — '
                      'off pre-Kickstarter since only the owner/testers publish. Turn back on before the public campaign goes live.',
                  state: _status?.aiModeration ?? '—',
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy || _status == null ? null : _toggleAiModeration,
                  child: Text(
                    _status?.aiModeration == 'ACTIVE' ? 'DISABLE AI MODERATION' : 'ENABLE AI MODERATION',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _busy ? null : _emergencyStop,
                  style: ElevatedButton.styleFrom(backgroundColor: NeumorphicPalette.danger, foregroundColor: Colors.white),
                  child: const Text('EMERGENCY STOP: CANCEL ALL QUEUED JOBS'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cancels every job still waiting (QUEUED/RETRYING) across all sources — '
                  'capsules, Advertise, AI, everything. Anything already SENDING to the display finishes normally.',
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishQueueScreen())),
                        child: const Text('PUBLISH QUEUE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContentModerationScreen())),
                        child: const Text('MODERATION'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Capsules',
              subtitle: 'Time capsule inventory and auto-publish',
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _debugForcePublish,
                  child: const Text('DEBUG: FORCE-RUN AUTO-PUBLISH NOW'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Auto-publish is currently in TEST MODE: any sealed capsule with a past opening date '
                  'publishes automatically, regardless of the "E-Ink Opening Day" consent checkbox.',
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
                ),
                if (_debugOutput != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NeumorphicPalette.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_debugOutput!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildStatsGrid(ControlRoomStatus s) {
    final stats = [
      ('QUEUED', s.queued),
      ('NEEDS REVIEW', s.needsReview),
      ('LIVE NOW', s.liveNow),
      ('COMPLETED', s.completed),
      ('FAILED', s.failed),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.3,
      children: stats.map((s) => Container(
        decoration: BoxDecoration(
          color: NeumorphicPalette.background,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.$1, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${s.$2}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required List<Widget> children}) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 18,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
    );
  }

  Widget _buildStateRow({required String label, required String note, required String state}) {
    Color color;
    switch (state) {
      case 'ACTIVE':
        color = const Color(0xFF68F56A);
        break;
      case 'PAUSED':
        color = NeumorphicPalette.danger;
        break;
      default:
        color = const Color(0xFFC08A1E); // darker amber — the old pale 0xFFFFE889 was nearly invisible as both text and background tint
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 3),
              Text(note, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(state, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
