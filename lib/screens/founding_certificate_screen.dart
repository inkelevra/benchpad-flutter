import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// Founding Certificate — public certificate view for one founder,
/// ported from founding-certificate.html.
class FoundingCertificateScreen extends StatefulWidget {
  final String? token;
  final String? id;

  const FoundingCertificateScreen({super.key, this.token, this.id});

  @override
  State<FoundingCertificateScreen> createState() => _FoundingCertificateScreenState();
}

class _FoundingCertificateScreenState extends State<FoundingCertificateScreen> {
  final _api = BenchpadApi();
  Map<String, dynamic>? _founder;
  String? _error;

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
      final founder = await _api.getFounderCertificate(token: widget.token, id: widget.id);
      if (mounted) setState(() => _founder = founder);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Uint8List? _decodeImage(String? dataUrl) {
    if (dataUrl == null) return null;
    final i = dataUrl.indexOf(',');
    if (i == -1) return null;
    try {
      return base64Decode(dataUrl.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  String _initials(String? name) {
    final n = (name ?? 'BP').trim();
    if (n.isEmpty) return 'BP';
    return n.split(RegExp(r'\s+')).take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
  }

  String _tierLabel(String? tier) {
    if (tier == 'urban_hero') return 'Urban Hero · Member of The First Twelve';
    if (tier == 'sustainability_champion') return 'Sustainability Champion';
    return 'Founding Supporter';
  }

  @override
  Widget build(BuildContext context) {
    final f = _founder;
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
      backgroundColor: const Color(0xFF07040B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07040B),
        title: const Text('Founding Certificate'),
        actions: f != null
            ? [IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => Share.share('${f['displayName']} · Founding Certificate #${f['founderNumber']} · BenchPad World'))]
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _error != null
              ? Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger))
              : f == null
                  ? const CircularProgressIndicator()
                  : Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFB98B2D), width: 2),
                        borderRadius: BorderRadius.circular(24),
                        color: const Color(0xFF0D0A07),
                        gradient: const RadialGradient(center: Alignment.topCenter, radius: 1, colors: [Color(0x1FF0BD3F), Colors.transparent], stops: [0, 0.35]),
                      ),
                      child: Column(
                        children: [
                          const Text('BENCHPAD WORLD · VERIFIED DIGITAL RECORD', style: TextStyle(color: Color(0xFFD4AA4E), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(height: 16),
                          const Text('FOUNDING\nCERTIFICATE', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1, fontFamily: 'serif')),
                          const SizedBox(height: 18),
                          const Text(
                            'This certificate confirms that the identity below is recorded as a supporter of BenchPad during its founding development stage.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFFC0B8AA), fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFB98B2D), width: 2)),
                            clipBehavior: Clip.antiAlias,
                            child: _decodeImage(f['imageData'] as String?) != null
                                ? Image.memory(_decodeImage(f['imageData'] as String?)!, fit: BoxFit.cover)
                                : Center(child: Text(_initials(f['displayName'] as String?), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(height: 18),
                          Text('${f['displayName']}', style: const TextStyle(color: Colors.white, fontSize: 28, fontFamily: 'serif')),
                          const SizedBox(height: 8),
                          Text('${f['founderNumber']}', style: const TextStyle(color: Color(0xFFF1C65F), fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(_tierLabel(f['tier'] as String?), style: const TextStyle(color: Color(0xFFD4AA4E), fontSize: 13)),
                          const SizedBox(height: 22),
                          Text(
                            f['tier'] == 'urban_hero'
                                ? 'One of the twelve numbered Urban Heroes in the first founding circle of BenchPad World.'
                                : 'A confirmed member of the BenchPad founding community.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFD5CDBF), fontSize: 12, height: 1.5),
                          ),
                          const SizedBox(height: 26),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.6,
                            children: [
                              _fact('FOUNDING NUMBER', '${f['founderNumber']}'),
                              _fact('RECORDED', (f['createdAt'] as String? ?? '').length >= 10 ? (f['createdAt'] as String).substring(0, 10) : '—'),
                              _fact('LOCATION', (f['location'] as String?)?.isNotEmpty == true ? f['location'] as String : 'Not displayed'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Digital recognition is independent of physical network scale. Network-based Time Capsule functions remain subject to verified deployment conditions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF938A7C), fontSize: 10, height: 1.5),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    ));
  }

  Widget _fact(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: const Color(0x33F0BD3F)), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFA88D51), fontSize: 7, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
