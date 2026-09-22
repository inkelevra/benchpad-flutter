import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import 'result_screen.dart';

/// BenchPad Live — submit a message/photo into the live participant
/// queue and watch it move through moderation to the physical display,
/// ported from benchpad-live.html.
class BenchPadLiveScreen extends StatefulWidget {
  const BenchPadLiveScreen({super.key});

  @override
  State<BenchPadLiveScreen> createState() => _BenchPadLiveScreenState();
}

class _BenchPadLiveScreenState extends State<BenchPadLiveScreen> {
  final _api = BenchpadApi();
  final _picker = ImagePicker();
  final _messageController = TextEditingController();
  final _sessionId = 'fl-live-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';

  File? _image;
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Map<String, dynamic>? _participant;
  Map<String, dynamic>? _job;
  String? _resultToken;
  Timer? _pollTimer;
  String? _lastSubmittedPreview;

  @override
  void dispose() {
    _api.dispose();
    _messageController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _image == null) {
      setState(() { _statusMessage = 'Add a message or upload an image.'; _statusIsError = true; });
      return;
    }
    setState(() { _busy = true; _statusMessage = null; });
    try {
      String imageData = '';
      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        imageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
      _lastSubmittedPreview = imageData;
      final data = await _api.submitLive(message: message, imageData: imageData, sessionId: _sessionId);
      setState(() {
        _participant = data['participant'] as Map<String, dynamic>?;
        _job = data['job'] as Map<String, dynamic>?;
        _resultToken = data['resultToken'] as String? ?? (data['job'] as Map?)?['resultToken'] as String?;
        _statusMessage = data['duplicate'] == true ? 'Already published · result restored' : 'Approved · publish job created';
        _statusIsError = false;
      });
      if (_resultToken != null) _startPolling();
    } on PublishException catch (e) {
      setState(() {
        _statusIsError = true;
        _statusMessage = e.reasonCode == 'cooldown'
            ? 'Next publication available in ${e.cooldownSeconds ?? 30} seconds'
            : e.reasonCode == 'needs_review'
                ? '${e.jobCode ?? "Submission"} · needs review · other approved publications continue'
                : 'Publish denied: ${e.reasonCode}';
      });
    } catch (e) {
      setState(() { _statusIsError = true; _statusMessage = '$e'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (_resultToken == null) return;
      try {
        final data = await _api.getLiveResult(_resultToken!);
        final job = data['job'] as Map<String, dynamic>?;
        setState(() {
          _participant = data['participant'] as Map<String, dynamic>? ?? _participant;
          _job = job;
        });
        final status = (job?['status'] as String? ?? '').toUpperCase();
        final image = job?['imageData'] as String? ?? _lastSubmittedPreview;
        if (image != null && image.isNotEmpty) {
          ResultScreen.save(
            imageDataUrl: image,
            status: status.isEmpty ? 'QUEUED' : status,
            deviceId: (data['device'] as Map?)?['deviceId'] as String? ?? 'BP-AMS-001',
            jobCode: job?['jobCode'] as String?,
            source: 'BENCHPAD_LIVE',
          );
        }
        if (['DISPLAYED', 'COMPLETED', 'FAILED', 'REJECTED'].contains(status)) {
          t.cancel();
        }
      } catch (_) {}
    });
  }

  String _statusLabel(String status) {
    const labels = {
      'AWAITING_REVIEW': 'WAITING FOR REVIEW',
      'QUEUED': 'QUEUED',
      'RETRYING': 'RETRYING',
      'SENDING': 'SENDING',
      'RECEIVED': 'RECEIVED BY DEVICE',
      'DELIVERED': 'DELIVERED',
      'REFRESHING': 'E-INK REFRESHING',
      'DISPLAYED': 'DISPLAYED ✓',
      'COMPLETED': 'PUBLICATION COMPLETED ✓',
      'FAILED': 'DISPLAY UPDATE FAILED',
      'REJECTED': 'PUBLICATION REJECTED',
    };
    return labels[status] ?? status;
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _participant != null;
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
      appBar: AppBar(title: const Text('BenchPad Live')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasResult) ...[
            const Text('YOUR MESSAGE · A REAL BENCHPAD · LIVE', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text('Send something to a real display', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: _messageController, maxLines: 5, maxLength: 200, decoration: const InputDecoration(hintText: 'Write your message…')),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: _image != null ? Image.file(_image!, fit: BoxFit.cover) : const Center(child: Icon(Icons.image_outlined, size: 40, color: NeumorphicPalette.textSecondary)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_library_outlined), label: const Text('Upload image'))),
                if (_image != null) IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _image = null)),
              ],
            ),
            const SizedBox(height: 16),
            if (_statusMessage != null) ...[
              Text(_statusMessage!, style: TextStyle(color: _statusIsError ? NeumorphicPalette.danger : const Color(0xFF72E39A), fontSize: 12)),
              const SizedBox(height: 12),
            ],
            ElevatedButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Checking content…' : 'SEND TO BENCHPAD')),
          ] else ...[
            _buildParticipantResult(),
          ],
        ],
      ),
    ));
  }

  Widget _buildParticipantResult() {
    final p = _participant!;
    final job = _job ?? {};
    final status = (job['status'] as String? ?? 'QUEUED').toUpperCase();
    final country = p['countryName'] ?? p['countryCode'] ?? 'Unknown';
    final distance = p['distanceKm'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AFTER YOUR LIVE PUBLICATION', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text('#${p['participantNumber']}', style: const TextStyle(color: Color(0xFFE4BF69), fontSize: 64, fontWeight: FontWeight.w900, height: 0.9)),
        const SizedBox(height: 10),
        Text(
          status == 'DISPLAYED'
              ? "You are participant #${p['participantNumber']} to control a real BenchPad remotely."
              : 'Your BenchPad publication is being processed.',
          style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: NeumorphicPalette.accent.withOpacity(0.3)), borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_statusLabel(status), style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _row('Country', '$country'),
              _row('Distance', distance == null ? 'Unavailable' : '${(distance as num).toStringAsFixed(0)} km to Amsterdam'),
              _row('Job code', '${job['jobCode'] ?? '—'}'),
              _row('Status', status),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => setState(() {
            _participant = null;
            _job = null;
            _resultToken = null;
            _pollTimer?.cancel();
            _messageController.clear();
            _image = null;
            _statusMessage = null;
          }),
          child: const Text('SEND ANOTHER'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11))),
          Flexible(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
