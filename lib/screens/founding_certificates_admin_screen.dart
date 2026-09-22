import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import 'founding_certificate_screen.dart';

/// Founding Certificates — owner panel to enable/revoke each founder's
/// public certificate link, ported from founding-certificates.html.
class FoundingCertificatesAdminScreen extends StatefulWidget {
  const FoundingCertificatesAdminScreen({super.key});

  @override
  State<FoundingCertificatesAdminScreen> createState() => _FoundingCertificatesAdminScreenState();
}

class _FoundingCertificatesAdminScreenState extends State<FoundingCertificatesAdminScreen> {
  final _api = BenchpadApi();
  List<Map<String, dynamic>> _founders = [];
  String? _error;
  final _busyIds = <String>{};

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
      final founders = await _api.getAllFoundersForManagement();
      if (mounted) setState(() { _founders = founders; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  bool _isPublic(Map<String, dynamic> f) => f['certificatePublic'] == true && f['certificateRevokedAt'] == null;

  Future<void> _toggle(Map<String, dynamic> f) async {
    final id = f['id']?.toString() ?? '';
    setState(() => _busyIds.add(id));
    try {
      await _api.toggleCertificatePublic(f, !_isPublic(f));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _founders.length;
    final public = _founders.where(_isPublic).length;
    final revoked = _founders.where((f) => f['certificateRevokedAt'] != null).length;

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
      appBar: AppBar(title: const Text('Founding Certificates')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Manage which founders have a public certificate link.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger)),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.3,
              children: [
                _metric('TOTAL', '$total'),
                _metric('PUBLIC', '$public'),
                _metric('REVOKED', '$revoked'),
              ],
            ),
            const SizedBox(height: 16),
            if (_founders.isEmpty)
              const Text('No founder records.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))
            else
              ..._founders.map((f) {
                final id = f['id']?.toString() ?? '';
                final isPublic = _isPublic(f);
                final busy = _busyIds.contains(id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${f['founderNumber']} · ${f['displayName']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 3),
                              Text('${f['status']} · public link ${isPublic ? 'enabled' : 'disabled'}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FoundingCertificateScreen(id: id))),
                          child: const Text('VIEW'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => _toggle(f),
                          style: TextButton.styleFrom(foregroundColor: isPublic ? NeumorphicPalette.danger : NeumorphicPalette.accent),
                          child: Text(busy ? '...' : (isPublic ? 'REVOKE' : 'ENABLE')),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    ));
  }

  Widget _metric(String label, String value) {
    return Container(
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
