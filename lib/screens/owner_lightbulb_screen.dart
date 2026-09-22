import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// A reserved-for-later placeholder page, ported from
/// owner-lightbulb.html.
class OwnerLightbulbScreen extends StatelessWidget {
  const OwnerLightbulbScreen({super.key});

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
      appBar: AppBar(title: const Text('BenchPad')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('BENCHPAD', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
              const SizedBox(height: 10),
              const Text('Nothing here yet', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text(
                'This space is reserved for what comes next. Control Room now lives under BenchPad Platform.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
