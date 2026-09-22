import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import 'master_telemetry_screen.dart';
import 'result_screen.dart';
import 'kinetic_energy_screen.dart';

/// The Bench — live engineering telemetry view for BP-AMS-001, ported
/// from benchpad-bench.html ("The engineering view").
///
/// Shows connectivity, temperature, battery, solar input, E-Ink status,
/// last heartbeat, GPS fix, and the currently-displayed content — all
/// read directly from device telemetry, never phone location.
class BenchEngineeringScreen extends StatefulWidget {
  const BenchEngineeringScreen({super.key});

  @override
  State<BenchEngineeringScreen> createState() => _BenchEngineeringScreenState();
}

class _BenchEngineeringScreenState extends State<BenchEngineeringScreen> {
  final _api = BenchpadApi();
  static const _deviceId = 'BP-AMS-001';

  Map<String, dynamic>? _device;
  Map<String, dynamic>? _current;
  String _statusNote = 'Loading telemetry…';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _api.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await _api.getDeviceEngineeringStatus(_deviceId);
      if (mounted) setState(() { _device = status['device'] as Map<String, dynamic>?; _statusNote = ''; });
    } catch (e) {
      if (mounted) setState(() => _statusNote = 'Offline · $e');
    }
    try {
      final current = await _api.getLiveDisplay(_deviceId);
      if (mounted) setState(() => _current = current);
    } catch (_) {}
  }

  Uint8List? _decodeImage(String? dataUrl) {
    if (dataUrl == null) return null;
    final i = dataUrl.indexOf(',');
    if (i == -1) return null;
    try {
      return base64Decode(dataUrl.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final connected = device?['connected'] == true;

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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('The Bench')),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('THE ENGINEERING VIEW', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text('Everything related to the physical BenchPad prototype lives here.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                if (_statusNote.isNotEmpty) Text(_statusNote, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 11)),
                const SizedBox(height: 12),
                NeumorphicBox(
                  soft: true,
                  borderRadius: 14,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterTelemetryScreen())),
                  child: Row(
                    children: [
                      const Icon(Icons.router_outlined, size: 20, color: NeumorphicPalette.accent),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Master Telemetry (local network)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                            Text('Live JSON straight from the board — needs same WiFi/hotspot', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: NeumorphicPalette.textSecondary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Technical device status',
                  subtitle: 'Live hardware telemetry from the physical BenchPad prototype.',
                  children: [
                    Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: connected ? const Color(0xFF1E8E3E) : NeumorphicPalette.danger)),
                      const SizedBox(width: 8),
                      Text(connected ? 'Connectivity: Online' : 'Connectivity: Offline', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: NeumorphicPalette.textPrimary)),
                    ]),
                    if (device?['networkStatus'] != null && '${device!['networkStatus']}'.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(device['networkStatus'] == 'LTE' ? Icons.signal_cellular_alt : Icons.wifi, size: 14, color: NeumorphicPalette.accent),
                          const SizedBox(width: 6),
                          Expanded(child: Text('${device['networkDetail'] ?? device['networkStatus']}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.8,
                      children: [
                        _statCard('TEMPERATURE', device?['controllerTemperatureC'] != null ? '${device!['controllerTemperatureC']} °C' : 'No live data'),
                        _statCard('BATTERY', device?['batteryPercent'] != null ? '${device!['batteryPercent']}%' : 'Not connected'),
                        _statCard('SOLAR INPUT', device?['solarInputW'] != null ? '${device!['solarInputW']} W' : 'Not connected'),
                        _statCard('E-INK STATUS', '${device?['einkStatus'] ?? 'No live data'}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _row('LAST HEARTBEAT', '${device?['lastHeartbeat'] ?? 'No heartbeat yet'}'),
                  ],
                ),
                _sectionCard(
                  title: 'Solar Charge Controller',
                  subtitle: 'Victron SmartSolar 75/15 — read over Bluetooth Instant Readout.',
                  children: [
                    if (device?['batteryVoltage'] == null)
                      const Text('No reading yet.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))
                    else ...[
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.8,
                        children: [
                          _statCard('BATTERY VOLTAGE', '${device!['batteryVoltage']} V'),
                          _statCard('BATTERY CURRENT', '${device['batteryCurrent']} A'),
                          _statCard('SOLAR POWER', '${device['solarInputW']} W'),
                          _statCard('CHARGE STATE', '${device['chargingStatus'] ?? '—'}'),
                        ],
                      ),
                      if (device['telemetryNote'] != null) ...[
                        const SizedBox(height: 10),
                        _row('NOTE', '${device['telemetryNote']}'),
                      ],
                    ],
                  ],
                ),
                _sectionCard(
                  title: 'GPS fix',
                  subtitle: 'Device telemetry only — this card never reads phone location.',
                  children: [
                    if (device?['hasGpsFix'] == true)
                      Text('${(device!['latitude'] as num).toStringAsFixed(5)}, ${(device['longitude'] as num).toStringAsFixed(5)}', style: const TextStyle(color: Color(0xFF1E8E3E), fontSize: 13, fontWeight: FontWeight.w700))
                    else
                      Text(connected ? 'No Fix' : 'Waiting for GNSS Fix', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
                  ],
                ),
                _sectionCard(
                  title: 'Currently displayed',
                  subtitle: 'What BP-AMS-001 is showing right now.',
                  children: [
                    if (_current == null)
                      const Text('Result unavailable.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))
                    else ...[
                      if (_decodeImage(_current!['imageData'] as String?) != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(aspectRatio: 4 / 3, child: Image.memory(_decodeImage(_current!['imageData'] as String?)!, fit: BoxFit.cover)),
                        ),
                      const SizedBox(height: 8),
                      _row('STATUS', '${_current!['status'] ?? '—'}'),
                      _row('SOURCE', '${_current!['source'] ?? '—'}'),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultScreen())),
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('VIEW FULL RESULT'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
                _sectionCard(
                  title: 'Kinetic Energy Level',
                  subtitle: 'Power path visualization — live when the device has reported.',
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KineticEnergyScreen())),
                        icon: const Icon(Icons.bolt_outlined),
                        label: const Text('OPEN KINETIC ENERGY LEVEL'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10))),
          Flexible(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
