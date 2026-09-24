import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/app_language.dart';
import 'services/haptic_settings.dart';
import 'services/theme_settings.dart';
import 'services/publish_queue_tracker.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLanguage()..load()),
        ChangeNotifierProvider(create: (_) => HapticSettings()..load()),
        ChangeNotifierProvider(create: (_) => ThemeSettings()..load()),
        ChangeNotifierProvider(create: (_) => PublishQueueTracker()..load()),
      ],
      child: Consumer<ThemeSettings>(
        builder: (context, themeSettings, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'BenchPad',
            debugShowCheckedModeBanner: false,
            // Light is the default (ThemeSettings starts on
            // AppThemeChoice.light); Dark/Auto are opt-in from App
            // Settings. NOTE: this switches MaterialApp's own theme
            // data, but most individual screens still wrap themselves
            // in their own hardcoded-light Theme() override (from the
            // neumorphic UI pass) — actually recoloring every screen
            // for Dark mode is separate, larger follow-up work the
            // user has explicitly deferred for now.
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeSettings.flutterThemeMode,
            // Home is the app's real hub, matching index.html's structure —
            // its own 6-card grid + 5-button bottom nav replace what used
            // to be a separate persistent tab bar here (that bar duplicated
            // navigation Home's own bottom nav now covers, and stacked
            // visually underneath it).
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
