import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../services/benchpad_api.dart';
import '../theme/app_theme.dart';

/// Capsule Certificate — decorative certificate view, ported from
/// capsule-certificate.html. The certificate now exports as a real PNG
/// (captured via RepaintBoundary, same technique as Content Studio's
/// composition capture) instead of only sharing a text summary.
class CapsuleCertificateScreen extends StatefulWidget {
  final String type;
  final int number;

  const CapsuleCertificateScreen({super.key, required this.type, required this.number});

  @override
  State<CapsuleCertificateScreen> createState() => _CapsuleCertificateScreenState();
}

class _CapsuleCertificateScreenState extends State<CapsuleCertificateScreen> {
  final _api = BenchpadApi();
  final _certificateKey = GlobalKey();
  Map<String, dynamic>? _cell;
  bool _loading = true;
  bool _exporting = false;

  String get _displayId => widget.type == 'core'
      ? 'BP-CORE-${widget.number.toString().padLeft(2, '0')}'
      : 'BP-TC-${widget.number.toString().padLeft(6, '0')}';

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
      final cell = await _api.getCell(type: widget.type, number: widget.number);
      if (mounted) setState(() { _cell = cell; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _share() {
    final message = _cell?['message'] as String? ?? 'A message reserved for the future.';
    final owner = _cell?['ownerName'] as String? ?? 'Anonymous';
    Share.share('$_displayId · BenchPad World\n"$message"\n— $owner', subject: 'BenchPad World Time Capsule');
  }

  Future<void> _exportPng() async {
    setState(() => _exporting = true);
    try {
      final boundary = _certificateKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('capture_failed');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('encode_failed');
      final bytes = byteData.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: '$_displayId-certificate.png', mimeType: 'image/png')],
        subject: 'BenchPad World Certificate — $_displayId',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _cell?['message'] as String? ?? 'A message reserved for the future.';
    final owner = _cell?['ownerName'] as String? ?? 'Anonymous';
    final country = _cell?['ownerCountry'] as String? ?? '—';
    final opening = _cell?['openingDate'] as String? ?? 'Not scheduled';
    final status = ((_cell?['status'] as String?) ?? 'EMPTY').toUpperCase();
    final isCore = widget.type == 'core';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capsule Certificate'),
        actions: [
          IconButton(
            icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined),
            onPressed: _exporting ? null : _exportPng,
            tooltip: 'Export PNG',
          ),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _share),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: _certificateKey,
                  child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE7C45B), width: 2),
                    borderRadius: BorderRadius.circular(28),
                    gradient: const RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [Color(0xFF12344B), Color(0xFF02060A)],
                      stops: [0, 0.6],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BENCHPAD WORLD · DIGITAL CERTIFICATE', style: TextStyle(color: Color(0xFF9DDFFF), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      const Text('TIME CAPSULE', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1)),
                      const SizedBox(height: 6),
                      Text(_displayId, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFFFE279), fontSize: 22)),
                      const SizedBox(height: 24),
                      Text('"$message"', style: const TextStyle(fontSize: 16, height: 1.5)),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(child: _fact('OWNER', owner)),
                          Expanded(child: _fact('COUNTRY', country)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _fact('OPENING', opening)),
                          Expanded(child: _fact('STATUS', status)),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE7C45B), width: 2)),
                          child: Center(
                            child: Text(
                              isCore ? 'FOUNDING\nTWELVE' : 'BENCHPAD\nWORLD',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFFE279), fontWeight: FontWeight.w800, fontSize: 10, height: 1.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Color(0xFF8197AA), fontSize: 9, letterSpacing: 1)),
        ],
      ),
    );
  }
}
