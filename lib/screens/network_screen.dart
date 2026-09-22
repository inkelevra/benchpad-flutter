import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';

/// BenchPad Network — trivial "paused" placeholder, ported from
/// benchpad-network.html.
class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  static const _cyan = Color(0xFF2E9BD6);

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
      ),
      child: Scaffold(
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('BenchPad Network')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: NeumorphicBox(
              flat: true,
              borderRadius: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('BENCHPAD NETWORK', style: TextStyle(color: _cyan, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  const Text('More is coming here.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1, color: NeumorphicPalette.textPrimary)),
                  const SizedBox(height: 12),
                  const Text(
                    'This section is paused for now. Community reach, growth plans and the idea inbox live on the BenchPad Community page.',
                    style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                    child: const Text('Nothing to see here yet', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
