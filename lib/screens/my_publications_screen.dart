import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/benchpad_api.dart';
import '../services/publish_queue_tracker.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';

/// Lists every publish job the user has submitted (most recent first),
/// each showing its assigned number (№ 000311) and live status/queue
/// position — refetched periodically while this screen is open, so
/// several photos can be followed at once instead of only the one
/// active publish flow.
class MyPublicationsScreen extends StatefulWidget {
  const MyPublicationsScreen({super.key});

  @override
  State<MyPublicationsScreen> createState() => _MyPublicationsScreenState();
}

class _MyPublicationsScreenState extends State<MyPublicationsScreen> {
  final _api = BenchpadApi();
  final Map<String, Map<String, dynamic>?> _statusByJob = {};
  final Map<String, String> _errorByJob = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) => _refreshAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final jobs = context.read<PublishQueueTracker>().jobs;
    for (final job in jobs) {
      try {
        final response = await _api.getPublishStatus(job.jobCode);
        final data = response['job'] as Map<String, dynamic>? ?? response;
        if (!mounted) return;
        setState(() {
          _statusByJob[job.jobCode] = data;
          _errorByJob.remove(job.jobCode);
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _errorByJob[job.jobCode] = 'Unable to check status');
      }
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  ({String label, Color color, IconData icon}) _statusPresentation(Map<String, dynamic>? data, String? error) {
    if (error != null) return (label: error, color: NeumorphicPalette.textSecondary, icon: Icons.wifi_off);
    if (data == null) return (label: 'Checking…', color: NeumorphicPalette.textSecondary, icon: Icons.hourglass_empty);

    final status = data['status'] as String? ?? '';
    final position = data['position'];
    switch (status) {
      case 'DISPLAYED':
        return (label: 'Displayed', color: NeumorphicPalette.success, icon: Icons.check_circle);
      case 'FAILED':
        return (label: data['errorMessage'] as String? ?? 'Failed', color: NeumorphicPalette.danger, icon: Icons.error);
      case 'QUEUED':
        return position is num && position > 0
            ? (label: 'Queued — position ${position.toInt()}', color: NeumorphicPalette.accent, icon: Icons.schedule)
            : (label: 'Queued', color: NeumorphicPalette.accent, icon: Icons.schedule);
      case 'RETRYING':
        return (label: 'Retrying…', color: NeumorphicPalette.accent, icon: Icons.refresh);
      case 'SENDING':
      case 'RECEIVED':
      case 'DELIVERED':
      case 'REFRESHING':
        return (label: 'Sending to the display…', color: NeumorphicPalette.accent, icon: Icons.send);
      default:
        return status.isEmpty ? (label: 'Checking…', color: NeumorphicPalette.textSecondary, icon: Icons.hourglass_empty) : (label: status, color: NeumorphicPalette.textSecondary, icon: Icons.info_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = context.watch<PublishQueueTracker>().jobs;

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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('My Publications')),
        body: jobs.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nothing published yet. Once you publish a photo, it shows up here with its queue position.', textAlign: TextAlign.center, style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    final presentation = _statusPresentation(_statusByJob[job.jobCode], _errorByJob[job.jobCode]);
                    return Dismissible(
                      key: ValueKey(job.jobCode),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: NeumorphicPalette.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.delete_outline, color: NeumorphicPalette.danger),
                      ),
                      onDismissed: (_) => context.read<PublishQueueTracker>().removeJob(job.jobCode),
                      child: NeumorphicBox(
                        flat: true,
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        child: Row(
                          children: [
                            Icon(presentation.icon, color: presentation.color, size: 26),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('№ ${job.displayNumber}', style: const TextStyle(color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  Text(presentation.label, style: TextStyle(color: presentation.color, fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('Submitted ${_relativeTime(job.submittedAt)}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
