import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../theme/neumorphic_theme.dart';
import '../services/app_language.dart';
import '../widgets/benchpad_pulse.dart';
import '../widgets/benchpad_video_tile.dart';
import '../widgets/weather_icon.dart';
import 'benchpad_world_screen.dart';
import 'advertise_screen.dart';
import 'platform_screen.dart';
import 'municipal_info_screen.dart';
import 'local_partners_screen.dart';
import 'offers_screen.dart';
import 'kinesus_info_screen.dart';
import 'report_feedback_screen.dart';
import 'network_screen.dart';
import 'bench_engineering_screen.dart';

/// BenchPad Dashboard — the app's home shell, ported from index.html.
///
/// UI-polish pass (v3): press-in tactile feedback + real vibration on
/// every neumorphic tap, darker/larger secondary text, larger tile
/// icons, the bottom nav's 5th button now uses the actual BenchPad
/// logo mark (tinted to match the other 4), and the NFC/QR Entry card
/// + Publish stats card have been removed from Home (NfcEntryScreen
/// was deleted outright along with it).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  String? _weatherTemp;
  String? _weatherText;
  String _weatherKey = 'cloudy';

  static const _weatherIcons = {
    0: ('clear', 'Clear sky'),
    1: ('partly', 'Mainly clear'),
    2: ('partly', 'Partly cloudy'),
    3: ('cloudy', 'Overcast'),
    45: ('fog', 'Fog'),
    48: ('fog', 'Depositing rime fog'),
    51: ('rain', 'Light drizzle'),
    53: ('rain', 'Drizzle'),
    55: ('rain', 'Dense drizzle'),
    56: ('rain', 'Freezing drizzle'),
    57: ('rain', 'Dense freezing drizzle'),
    61: ('rain', 'Slight rain'),
    63: ('rain', 'Rain'),
    65: ('rain', 'Heavy rain'),
    66: ('rain', 'Freezing rain'),
    67: ('rain', 'Heavy freezing rain'),
    71: ('snow', 'Slight snow'),
    73: ('snow', 'Snow'),
    75: ('snow', 'Heavy snow'),
    77: ('snow', 'Snow grains'),
    80: ('rain', 'Slight showers'),
    81: ('rain', 'Showers'),
    82: ('rain', 'Violent showers'),
    85: ('snow', 'Slight snow showers'),
    86: ('snow', 'Heavy snow showers'),
    95: ('storm', 'Thunderstorm'),
    96: ('storm', 'Thunderstorm with hail'),
    99: ('storm', 'Thunderstorm with heavy hail'),
  };

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadWeather();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    try {
      final res = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=52.3676&longitude=4.9041&current=temperature_2m,weather_code,wind_speed_10m,is_day&timezone=Europe%2FAmsterdam'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;
      final temp = (current['temperature_2m'] as num).round();
      final wind = (current['wind_speed_10m'] as num).round();
      final code = (current['weather_code'] as num).toInt();
      final isDay = (current['is_day'] as num?)?.toInt() != 0;
      final entry = _weatherIcons[code] ?? ('cloudy', 'Cloudy');
      if (mounted) {
        setState(() {
          _weatherKey = isDay ? entry.$1 : '${entry.$1}_night';
          _weatherTemp = '$temp°C';
          _weatherText = '${entry.$2} · $wind km/h';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _weatherText = 'Weather temporarily unavailable');
    }
  }

  String get _timeStr => '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
  String get _dateStr {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[_now.weekday - 1]}, ${_now.day} ${months[_now.month - 1]}';
  }

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLanguage>();

    // Scoped light-neumorphic theme override — see the class doc above.
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: NeumorphicPalette.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: NeumorphicPalette.background,
          foregroundColor: NeumorphicPalette.textPrimary,
          elevation: 0,
          // Material 3 tints the app bar when content scrolls beneath
          // it by default — this is what was showing as "a different
          // shade at the top while scrolling". Both of these kill it.
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/kinesus-logo.png', width: 24, height: 24, fit: BoxFit.contain),
              ),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary),
                  children: [
                    TextSpan(text: 'Bench'),
                    TextSpan(text: 'Pad', style: TextStyle(color: NeumorphicPalette.accent)),
                  ],
                ),
              ),
            ],
          ),
          actions: [_buildLanguageSwitch(lang), const SizedBox(width: 12)],
        ),
        body: RefreshIndicator(
          onRefresh: _loadWeather,
          // Suppress the default overscroll glow entirely, rather than
          // it flashing a differently-tinted color at the top edge.
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              notification.disallowIndicator();
              return true;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildUtilityPanel(),
                const SizedBox(height: 12),
                const BenchPadPulse(),
                const SizedBox(height: 18),
                const BenchPadVideoTile(),
                const SizedBox(height: 18),
                _buildHomeGrid(lang),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  /// EN/NL toggle — ported from index.html's header .language-switch,
  /// so switching language doesn't require a trip into app settings.
  Widget _buildLanguageSwitch(AppLanguage lang) {
    Widget option(String code, String label) {
      final active = lang.code == code;
      return GestureDetector(
        onTap: () {
          HapticFeedback.vibrate();
          lang.setLanguage(code);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? NeumorphicPalette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : NeumorphicPalette.textSecondary,
            ),
          ),
        ),
      );
    }

    return NeumorphicBox(
      soft: true,
      borderRadius: 10,
      padding: const EdgeInsets.all(2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option('nl', 'NL'), option('en', 'EN')]),
    );
  }

  Widget _buildUtilityPanel() {
    return NeumorphicBox(
      borderRadius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_timeStr, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1, color: NeumorphicPalette.textPrimary)),
                const SizedBox(height: 6),
                Text(_dateStr, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WeatherIcon(conditionKey: _weatherKey, size: 30),
                  const SizedBox(width: 12),
                  Text(_weatherTemp ?? '--', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(_weatherText ?? 'Loading weather…', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  /// The 6-card home grid, ported 1:1 from index.html's card set:
  /// Municipal Info, Local Partners, Advertise on BenchPad, Current
  /// Offers, Kinesus Info, Report / Feedback.
  Widget _buildHomeGrid(AppLanguage lang) {
    final tiles = [
      _HomeTile(lang.t('Municipal\nInfo', 'Gemeente\nInfo'), Icons.location_city_outlined, () => _push(const MunicipalInfoScreen())),
      _HomeTile(lang.t('Local\nPartners', 'Lokale\nPartners'), Icons.handshake_outlined, () => _push(const LocalPartnersScreen())),
      _HomeTile(lang.t('Post to\nBenchPad', 'Plaatsen op\nBenchPad'), Icons.campaign_outlined, () => _push(const AdvertiseScreen())),
      _HomeTile(lang.t('Current\nOffers', 'Actuele\naanbiedingen'), Icons.sell_outlined, () => _push(const OffersScreen())),
      _HomeTile(lang.t('Report /\nFeedback', 'Melding /\nFeedback'), Icons.feedback_outlined, () => _push(const ReportFeedbackScreen())),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: [
        _buildTile(tiles[0]), // Municipal Info
        _buildTile(tiles[2]), // Post to BenchPad
        _buildTile(tiles[1]), // Local Partners
        _buildTile(tiles[3]), // Current Offers
        _buildTile(tiles[4]), // Report / Feedback
        _buildKinesusTile(lang), // Kinesus Info
      ],
    );
  }

  Widget _buildTile(_HomeTile tile) {
    return NeumorphicBox(
      borderRadius: 24,
      padding: const EdgeInsets.all(14),
      onTap: tile.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeumorphicBox(
            soft: true,
            borderRadius: 16,
            padding: const EdgeInsets.all(15),
            child: Icon(tile.icon, color: NeumorphicPalette.accent, size: 33),
          ),
          const Spacer(),
          Text(
            tile.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary, height: 1.15),
          ),
        ],
      ),
    );
  }

  /// Same tile shape as the others, but with the real tri-color Kinesus
  /// flower mark instead of a generic icon — matching the PWA's own
  /// "Kinesus Info" card, which uses the logo image as its main icon.
  Widget _buildKinesusTile(AppLanguage lang) {
    return NeumorphicBox(
      borderRadius: 24,
      padding: const EdgeInsets.all(14),
      onTap: () => _push(const KinesusInfoScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeumorphicBox(
            soft: true,
            borderRadius: 16,
            padding: const EdgeInsets.all(9),
            child: Image.asset('assets/images/kinesus-logo.png', width: 42, height: 42, fit: BoxFit.contain),
          ),
          const Spacer(),
          Text(
            lang.t('Kinesus\nInfo', 'Kinesus\nInfo'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary, height: 1.15),
          ),
        ],
      ),
    );
  }

  /// The 5-button bottom nav, ported from index.html's <nav class="nav">:
  /// Dashboard (this screen — active), Platform, BenchPad World,
  /// BenchPad Network, Bench — the last one uses the actual BenchPad
  /// logo mark (tinted the same as the other 4 icons) instead of a
  /// generic icon, matching the PWA's own bottom nav. Each button is
  /// now its own raised neumorphic shape (alternating square/round, to
  /// compare) rather than a flat icon; the active tab (Home) shows
  /// permanently pressed-in as a "you are here" cue.
  Widget _buildBottomNav() {
    Widget navButton(
      Widget Function(Color color) iconBuilder, {
      bool active = false,
      bool round = false,
      VoidCallback? onTap,
    }) {
      final color = active ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary;
      return NeumorphicBox(
        borderRadius: round ? 23 : 14,
        padding: const EdgeInsets.all(11),
        pressed: active,
        onTap: onTap,
        child: SizedBox(width: 22, height: 22, child: Center(child: iconBuilder(color))),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: NeumorphicPalette.background,
        boxShadow: [BoxShadow(color: NeumorphicPalette.shadowDark, offset: Offset(0, -3), blurRadius: 10)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            navButton((c) => Icon(Icons.home_rounded, color: c, size: 22), active: true, round: true),
            navButton((c) => Icon(Icons.grid_view_rounded, color: c, size: 22), round: true, onTap: () => _push(const PlatformScreen())),
            navButton((c) => Icon(Icons.public, color: c, size: 22), round: true, onTap: () => _push(const BenchPadWorldScreen())),
            navButton((c) => Icon(Icons.lightbulb_outline, color: c, size: 22), round: true, onTap: () => _push(const NetworkScreen())),
            navButton(
              (c) => Image.asset('assets/images/benchpad-logo-mark.png', width: 22, height: 22, color: c, colorBlendMode: BlendMode.srcIn),
              round: true,
              onTap: () => _push(const BenchEngineeringScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTile {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _HomeTile(this.label, this.icon, this.onTap);
}
