import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import 'capsule_creator_screen.dart';
import 'vault_sphere_screen.dart';
import 'memory_sphere_screen.dart';

/// Capsule Access — "My Capsule" key lookup, ported from
/// capsule-access.html.
class CapsuleAccessScreen extends StatefulWidget {
  const CapsuleAccessScreen({super.key});

  @override
  State<CapsuleAccessScreen> createState() => _CapsuleAccessScreenState();
}

class _CapsuleAccessScreenState extends State<CapsuleAccessScreen> {
  final _api = BenchpadApi();
  final _keyController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _api.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _go() async {
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
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: type, number: number, ownerKey: key)));
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
      appBar: AppBar(title: const Text('My Capsule')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('BENCHPAD WORLD · CAPSULE ACCESS', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('My Capsule', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text(
                'Enter the access key you received when your capsule was set up. It looks like BP-XXXXX-XXXXX.',
                style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _keyController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1),
                decoration: const InputDecoration(labelText: 'ACCESS KEY', hintText: 'BP-XXXXX-XXXXX'),
                onSubmitted: (_) => _go(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 12), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'Searching...' : 'OPEN MY CAPSULE')),
              const SizedBox(height: 24),
              Row(children: const [
                Expanded(child: Divider(color: NeumorphicPalette.background)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR BROWSE', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.w800))),
                Expanded(child: Divider(color: NeumorphicPalette.background)),
              ]),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultSphereScreen())),
                      child: const Text('VAULT SPHERE\n(162 capsules)', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemorySphereScreen())),
                      child: const Text('MEMORY SPHERE\n(492 capsules)', textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
