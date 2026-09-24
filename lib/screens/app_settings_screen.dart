import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/haptic_settings.dart';
import '../services/theme_settings.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import '../widgets/haptic_toggle.dart';
import '../widgets/sun_moon_toggle.dart';
import '../widgets/auto_toggle.dart';

/// App-wide settings, reached via the lightbulb icon in Home's bottom
/// nav (previously pointed at NetworkScreen's "paused" placeholder —
/// this is real, live functionality for that spot instead).
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final haptics = context.watch<HapticSettings>();
    final themeSettings = context.watch<ThemeSettings>();

    // While Auto is on, the sun/moon toggle reflects the device's
    // current system setting rather than a manual pick.
    final resolvedIsDark = themeSettings.isAuto ? MediaQuery.platformBrightnessOf(context) == Brightness.dark : themeSettings.choice == AppThemeChoice.dark;

    Widget settingRow({required String title, required String subtitle, required Widget trailing}) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      );
    }

    Widget settingCard({required List<Widget> rows}) {
      return NeumorphicBox(
        flat: true,
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0x22000000)),
                const SizedBox(height: 14),
              ],
              rows[i],
            ],
          ],
        ),
      );
    }

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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text('APPEARANCE', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
            settingCard(rows: [
              settingRow(
                title: 'Light / Dark',
                subtitle: themeSettings.isAuto ? 'Following system right now' : (resolvedIsDark ? 'Dark' : 'Light'),
                trailing: SunMoonToggle(
                  isDark: resolvedIsDark,
                  onChanged: (dark) => context.read<ThemeSettings>().setExplicit(dark),
                ),
              ),
              settingRow(
                title: 'Auto',
                subtitle: 'Follow the phone\'s system theme',
                trailing: AutoToggle(
                  isOn: themeSettings.isAuto,
                  onChanged: (value) => context.read<ThemeSettings>().setAuto(value),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text('FEEDBACK', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
            settingCard(rows: [
              settingRow(
                title: 'Haptic feedback',
                subtitle: 'Vibrate on button taps',
                trailing: HapticToggle(
                  value: haptics.enabled,
                  onChanged: (value) => context.read<HapticSettings>().setEnabled(value),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
