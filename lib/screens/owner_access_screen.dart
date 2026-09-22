import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import 'access_control_screen.dart';
import 'studio_screen.dart';

/// Owner Access — the single entry point for everything engineering-
/// and owner-only. Was three separate screens with three different
/// names for roughly the same idea (Owner Access, Platform Access,
/// Access Recovery/Recovery Access) — consolidated here. Primary path
/// is the owner password; recovery code (for trusting a new device
/// when Private mode is already on) is a secondary option in the same
/// screen rather than its own destination.
class OwnerAccessScreen extends StatefulWidget {
  /// When true, renders without its own Scaffold/AppBar — used when
  /// Platform embeds this directly as its own gate.
  final bool embedded;

  /// Called once owner access becomes active (token login or trust-
  /// browser) — lets an embedding parent (Platform) update its own
  /// state without needing a full navigation round-trip.
  final VoidCallback? onOwnerVerified;

  const OwnerAccessScreen({super.key, this.embedded = false, this.onOwnerVerified});

  @override
  State<OwnerAccessScreen> createState() => _OwnerAccessScreenState();
}

class _OwnerAccessScreenState extends State<OwnerAccessScreen> {
  final _api = BenchpadApi();
  final _tokenController = TextEditingController();
  final _recoveryNameController = TextEditingController(text: 'Recovered device');
  final _recoveryCodeController = TextEditingController();
  bool _isOwner = false;
  bool _busy = false;
  bool _showRecovery = false;
  bool _recoverySuccess = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _api.dispose();
    _tokenController.dispose();
    _recoveryNameController.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final owner = await _api.getOwnerStatus();
    if (mounted) setState(() => _isOwner = owner);
  }

  Future<void> _login() async {
    final value = _tokenController.text.trim();
    if (value.isEmpty) {
      setState(() { _message = 'Enter the owner password.'; _messageIsError = true; });
      return;
    }
    setState(() { _busy = true; _message = 'Checking owner access…'; _messageIsError = false; });
    try {
      await _api.ownerLogin(value);
      setState(() { _isOwner = true; _message = 'Owner access verified.'; _messageIsError = false; });
      widget.onOwnerVerified?.call();
    } catch (e) {
      setState(() { _message = e.toString(); _messageIsError = true; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useRecoveryCode() async {
    setState(() { _busy = true; _message = 'Checking recovery code…'; _messageIsError = false; });
    try {
      await _api.useRecoveryCode(displayName: _recoveryNameController.text.trim(), recoveryCode: _recoveryCodeController.text.trim());
      setState(() {
        _recoverySuccess = true;
        _message = 'This device is trusted. The recovery code is now invalid.';
        _messageIsError = false;
      });
    } catch (e) {
      setState(() { _message = e.toString(); _messageIsError = true; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _trustBrowser() async {
    setState(() => _busy = true);
    try {
      await _api.trustThisDevice('Owner device');
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessControlScreen()));
      }
    } catch (e) {
      setState(() { _message = e.toString(); _messageIsError = true; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await _api.ownerLogout();
    setState(() { _isOwner = false; _tokenController.clear(); _message = null; });
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context).copyWith(
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
    );
    final content = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('BENCHPAD · PRIVATE ACCESS', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('Owner Access', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              const Text(
                'Engineering, device, network and analytics workspaces are restricted to Owner sessions.',
                style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              if (!_isOwner) ...[
                TextField(
                  controller: _tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'OWNER PASSWORD'),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _busy ? null : _login, child: Text(_busy ? 'Verifying…' : 'ACTIVATE OWNER ACCESS')),
                const SizedBox(height: 8),
                if (_message != null && !_showRecovery)
                  Text(_message!, style: TextStyle(color: _messageIsError ? NeumorphicPalette.danger : const Color(0xFF79E29B), fontSize: 11))
                else if (!_showRecovery)
                  const Text('Owner access stays active on this device for 1 week, then needs the password again.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _showRecovery = !_showRecovery),
                  child: Text(_showRecovery ? 'Hide recovery code option' : "Don't have the password? Use a recovery code"),
                ),
                if (_showRecovery) ...[
                  const SizedBox(height: 8),
                  if (!_recoverySuccess) ...[
                    const Text(
                      'A recovery code (created earlier from Platform Access) trusts this specific device for Private mode. It is separate from the owner password above.',
                      style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _recoveryNameController, decoration: const InputDecoration(labelText: 'DEVICE NAME')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _recoveryCodeController,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(labelText: 'RECOVERY CODE', hintText: 'BP-XXXX-XXXX-XXXX'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: _busy ? null : _useRecoveryCode, child: Text(_busy ? 'Checking…' : 'TRUST THIS DEVICE')),
                  ] else
                    ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessControlScreen())),
                      child: const Text('OPEN PLATFORM ACCESS'),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 10),
                    Text(_message!, style: TextStyle(color: _messageIsError ? NeumorphicPalette.danger : const Color(0xFF79E29B), fontSize: 11)),
                  ],
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF79E29B).withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Color(0xFF79E29B)),
                      SizedBox(width: 6),
                      Text('Owner access active', style: TextStyle(color: Color(0xFF79E29B), fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.6,
                  children: [
                    _navButton('PLATFORM ACCESS', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessControlScreen()))),
                    _navButton('BENCHPAD STUDIO', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudioScreen()))),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _busy ? null : _trustBrowser, child: const Text('TRUST THIS BROWSER & OPEN PLATFORM ACCESS')),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.danger, side: const BorderSide(color: NeumorphicPalette.danger)),
                  child: const Text('SIGN OUT OWNER ACCESS'),
                ),
              ],
            ],
          ),
        ),
      );
    if (widget.embedded) {
      return Theme(data: themeData, child: content);
    }
    return Theme(
      data: themeData,
      child: Scaffold(
        appBar: AppBar(title: const Text('Owner Access')),
        body: content,
      ),
    );
  }

  Widget _navButton(String label, VoidCallback onTap) {
    return OutlinedButton(onPressed: onTap, child: Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center));
  }
}
