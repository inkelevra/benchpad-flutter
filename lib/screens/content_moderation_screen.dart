import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// Content Moderation — review queue, ported from content-moderation.html.
class ContentModerationScreen extends StatefulWidget {
  const ContentModerationScreen({super.key});

  @override
  State<ContentModerationScreen> createState() => _ContentModerationScreenState();
}

class _ContentModerationScreenState extends State<ContentModerationScreen> {
  final _api = BenchpadApi();
  String _status = 'NEEDS_REVIEW';
  ModerationData? _data;
  String? _error;
  final _reasonControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    for (final c in _reasonControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getModerationItems(_status);
      if (mounted) setState(() { _data = data; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _decide(String jobCode, String action) async {
    final reason = _reasonControllers[jobCode]?.text.trim() ?? '';
    try {
      await _api.moderationDecision(jobCode: jobCode, action: action, reason: reason);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Uint8List? _decodeDataUrl(String? dataUrl) {
    if (dataUrl == null) return null;
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(dataUrl.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NeumorphicPalette.background,
          labelStyle: const TextStyle(color: NeumorphicPalette.textSecondary),
          floatingLabelStyle: const TextStyle(color: NeumorphicPalette.accent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.shadowDark)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.shadowDark)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.accent, width: 1.5)),
        ),
      ),
      child: Scaffold(
      appBar: AppBar(title: const Text('Content Moderation')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Safe material moves automatically to the display queue. Only uncertain cases wait here.',
              style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger)),
            if (data != null) ...[
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: [
                  _metric('REVIEW', data.needsReview),
                  _metric('AUTO', data.autoApproved),
                  _metric('MANUAL', data.manualApproved),
                  _metric('REJECTED', data.rejected),
                ],
              ),
              const SizedBox(height: 16),
            ],
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'NEEDS_REVIEW', label: Text('REVIEW', style: TextStyle(fontSize: 10))),
                ButtonSegment(value: 'REJECTED', label: Text('REJECTED', style: TextStyle(fontSize: 10))),
                ButtonSegment(value: 'APPROVED', label: Text('APPROVED', style: TextStyle(fontSize: 10))),
              ],
              selected: {_status},
              onSelectionChanged: (s) {
                setState(() { _status = s.first; _data = null; });
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (data == null && _error == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            if (data != null && data.items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
                child: const Text('No items in this category.', textAlign: TextAlign.center, style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
              ),
            if (data != null) ...data.items.map(_buildItemCard),
          ],
        ),
      ),
    ));
  }

  Widget _metric(String label, int value) {
    return Container(
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildItemCard(ModerationItem item) {
    final bytes = _decodeDataUrl(item.imageData);
    final isReview = item.status == 'AWAITING_REVIEW';
    _reasonControllers.putIfAbsent(item.jobCode, () => TextEditingController());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bytes != null)
            AspectRatio(aspectRatio: 4 / 3, child: Image.memory(bytes, fit: BoxFit.cover))
          else
            Container(height: 100, color: NeumorphicPalette.background),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.jobCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 3),
                          Text('${item.source} · ${item.deviceId} · ${item.displayId}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                    _statusBadge(item),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(10)),
                  child: Text(item.contentText ?? 'Image-only submission', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4CC65).withOpacity(0.05),
                    border: const Border(left: BorderSide(color: Color(0xFFF4CC65), width: 3)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.moderationReasonCode ?? 'REVIEW', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFFD8C58E))),
                      const SizedBox(height: 4),
                      Text(item.moderationNote ?? 'Automatic moderation requested a human decision.',
                          style: const TextStyle(color: Color(0xFFD8C58E), fontSize: 10)),
                    ],
                  ),
                ),
                if (isReview) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reasonControllers[item.jobCode],
                    decoration: const InputDecoration(hintText: 'Optional decision note'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _decide(item.jobCode, 'APPROVE'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B7752), foregroundColor: const Color(0xFFB9F3CA)),
                        child: const Text('APPROVE'),
                      ),
                      OutlinedButton(onPressed: () => _decide(item.jobCode, 'REQUEST_CHANGES'), child: const Text('REQUEST CHANGES')),
                      OutlinedButton(
                        onPressed: () => _decide(item.jobCode, 'REJECT'),
                        style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.danger, side: const BorderSide(color: NeumorphicPalette.danger)),
                        child: const Text('REJECT'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _statusBadge(ModerationItem item) {
    Color color;
    String label;
    if (item.status == 'AWAITING_REVIEW') {
      color = const Color(0xFFF4CC65);
      label = 'NEEDS REVIEW';
    } else if (item.status == 'REJECTED' || item.status == 'CHANGES_REQUESTED') {
      color = NeumorphicPalette.danger;
      label = item.status;
    } else {
      color = const Color(0xFF72E39A);
      label = item.moderationStatus ?? item.status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800)),
    );
  }
}
