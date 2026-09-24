import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import 'publish_queue_board_screen.dart';

/// Publish Queue — full display queue manager, ported from
/// publish-jobs.html.
class PublishQueueScreen extends StatefulWidget {
  const PublishQueueScreen({super.key});

  @override
  State<PublishQueueScreen> createState() => _PublishQueueScreenState();
}

class _PublishQueueScreenState extends State<PublishQueueScreen> {
  final _api = BenchpadApi();
  PublishQueueData? _data;
  String? _error;
  final _expandedJobs = <String>{};
  final _jobImages = <String, String>{};

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
      final data = await _api.getPublishJobs(limit: 80);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _togglePublishing() async {
    if (_data == null) return;
    final next = _data!.publicPublishing == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
    try {
      await _api.togglePublicPublishing(next);
      _load();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _emergencyStop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeumorphicPalette.background,
        titleTextStyle: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14),
        title: const Text('Emergency stop'),
        content: const Text('Cancel every queued job across ALL sources right now? Jobs already sending will finish normally.', style: TextStyle(color: NeumorphicPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm', style: TextStyle(color: NeumorphicPalette.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final cancelled = await _api.emergencyStopAllQueued();
      _toast('Cancelled $cancelled queued job(s)');
      _load();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _tick() async {
    try {
      await _api.tickPublishQueue();
      _load();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _cancelJob(String jobCode) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeumorphicPalette.background,
        titleTextStyle: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14),
        title: const Text('Remove from queue?'),
        content: Text('Remove $jobCode from the queue?', style: const TextStyle(color: NeumorphicPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: NeumorphicPalette.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.cancelSingleJob(jobCode);
      _load();
    } catch (e) {
      if (mounted) _toast('Failed: $e');
    }
  }

  Future<void> _toggleJobExpand(String jobCode) async {
    setState(() {
      if (_expandedJobs.contains(jobCode)) {
        _expandedJobs.remove(jobCode);
      } else {
        _expandedJobs.add(jobCode);
      }
    });
    if (_expandedJobs.contains(jobCode) && !_jobImages.containsKey(jobCode)) {
      try {
        final detail = await _api.getPublishJobDetail(jobCode);
        final imageData = (detail['job'] as Map?)?['imageData'] as String?;
        if (imageData != null && mounted) setState(() => _jobImages[jobCode] = imageData);
      } catch (_) {}
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final data = _data;
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
          title: const Text('Publish Queue'),
          actions: [
            IconButton(
              tooltip: 'Public board',
              icon: const Icon(Icons.flight_takeoff),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishQueueBoardScreen())),
            ),
          ],
        ),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger)),
                if (data == null && _error == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: NeumorphicPalette.accent))),
                if (data != null) ...[
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.3,
                    children: [
                      _metric('QUEUED', data.queued),
                      _metric('NEEDS REVIEW', data.needsReview),
                      _metric('LIVE NOW', data.liveNow),
                      _metric('COMPLETED', data.completed),
                      _metric('FAILED', data.failed),
                      _metric('24H JOBS', data.jobs24h),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NeumorphicBox(
                    flat: true,
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('PUBLIC PUBLISHING', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: NeumorphicPalette.textPrimary))),
                            _statePill(data.publicPublishing),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: NeumorphicBox(
                                soft: true,
                                borderRadius: 12,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                onTap: _togglePublishing,
                                child: Center(child: Text(data.publicPublishing == 'ACTIVE' ? 'PAUSE' : 'RESUME', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: NeumorphicBox(
                                soft: true,
                                borderRadius: 12,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                onTap: _emergencyStop,
                                child: const Center(child: Text('EMERGENCY STOP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.danger))),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Display locks', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                      NeumorphicBox(
                        soft: true,
                        borderRadius: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onTap: _tick,
                        child: const Text('PROCESS QUEUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NeumorphicPalette.accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (data.locks.isEmpty)
                    _emptyCard('All displays available')
                  else
                    ...data.locks.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: NeumorphicBox(
                            flat: true,
                            borderRadius: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${l.deviceId} · ${l.displayId}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: NeumorphicPalette.textPrimary)),
                                const SizedBox(height: 3),
                                Text(l.currentJobCode ?? '—', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 16),
                  const Text('Recent jobs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                  const SizedBox(height: 8),
                  if (data.jobs.isEmpty)
                    _emptyCard('No publish jobs yet.')
                  else
                    ...data.jobs.map(_buildJobCard),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, int value) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
        ],
      ),
    );
  }

  Widget _statePill(String state) {
    final active = state == 'ACTIVE';
    final color = active ? NeumorphicPalette.success : NeumorphicPalette.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(state, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _emptyCard(String text) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 14,
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
    );
  }

  static const _statusColors = {
    'DISPLAYED': NeumorphicPalette.success,
    'COMPLETED': Color(0xFF2D9CDB),
    'QUEUED': Color(0xFFC98A00),
    'RETRYING': Color(0xFFC98A00),
    'AWAITING_REVIEW': Color(0xFFC98A00),
    'FAILED': NeumorphicPalette.danger,
    'REJECTED': NeumorphicPalette.danger,
    'CHANGES_REQUESTED': NeumorphicPalette.danger,
  };

  Widget _buildJobCard(PublishJobSummary job) {
    final expanded = _expandedJobs.contains(job.jobCode);
    final color = _statusColors[job.status] ?? NeumorphicPalette.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        onTap: () => _toggleJobExpand(job.jobCode),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.jobCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: NeumorphicPalette.textPrimary)),
                      const SizedBox(height: 3),
                      Text('${job.source} · ${job.deviceId} · ${job.displayId} · priority ${job.priority}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(job.status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                    if (job.status == 'QUEUED' || job.status == 'RETRYING') ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _cancelJob(job.jobCode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: NeumorphicPalette.danger.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
                          child: const Text('REMOVE', style: TextStyle(color: NeumorphicPalette.danger, fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (expanded) ...[
              const Divider(height: 20, color: NeumorphicPalette.shadowDark),
              _detailRow('Moderation', job.moderationStatus ?? '—'),
              _detailRow('Reason', job.moderationReasonCode ?? '—'),
              _detailRow('Minimum visible', '${job.minimumVisibleSeconds}s'),
              _detailRow('Attempts', '${job.attemptCount}/3'),
              _detailRow('Content', job.contentText ?? '—'),
              _detailRow('Content hash', job.contentHash),
              if (_jobImages[job.jobCode] != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Builder(builder: (context) {
                    final dataUrl = _jobImages[job.jobCode]!;
                    final commaIndex = dataUrl.indexOf(',');
                    if (commaIndex == -1) return const SizedBox.shrink();
                    try {
                      final bytes = base64Decode(dataUrl.substring(commaIndex + 1));
                      return Image.memory(bytes, fit: BoxFit.cover);
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  }),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textPrimary))),
        ],
      ),
    );
  }
}
