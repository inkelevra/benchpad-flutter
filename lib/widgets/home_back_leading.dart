import 'package:flutter/material.dart';

/// A back-button leading widget showing just "Home" (no arrow) —
/// used on every screen reached directly from Home (bottom nav:
/// Platform, BenchPad World, BenchPad Network, The Bench; and the
/// Home grid tiles: Municipal Info, Local Partners, Post to BenchPad,
/// Current Offers, Kinesus Info, Report/Feedback), where the
/// destination is always Home, per explicit request. The current
/// page's own name stays as the centered AppBar title, showing where
/// the person currently is. Ordinary deeper-pushed screens keep
/// Flutter's default back arrow (standard Material behaviour).
Widget homeBackLeading(BuildContext context) {
  final color = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
  return Center(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).maybePop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('Home', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ),
    ),
  );
}

/// Same visual treatment as [homeBackLeading], but labeled just "Back"
/// — for screens one level deeper than Home (e.g. Community/My
/// Profile, both reached via BenchPad World), where spelling out the
/// actual destination ("BenchPad World") would run too long next to
/// the page's own title.
Widget backLeading(BuildContext context) {
  final color = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
  return Center(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).maybePop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ),
    ),
  );
}
