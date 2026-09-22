import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/app_language.dart';
import 'services/notification_service.dart';
import 'services/share_intent_service.dart';
import 'screens/home_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const BenchpadApp());
  NotificationService.instance.init();
  ShareIntentService.instance.start(_navigatorKey);
}

class BenchpadApp extends StatelessWidget {
  const BenchpadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppLanguage()..load(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'BenchPad',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        // Home is the app's real hub, matching index.html's structure —
        // its own 6-card grid + 5-button bottom nav replace what used
        // to be a separate persistent tab bar here (that bar duplicated
        // navigation Home's own bottom nav now covers, and stacked
        // visually underneath it).
        home: const HomeScreen(),
      ),
    );
  }
}
