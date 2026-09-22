import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';

/// BenchPad Master telemetry — reads /status.json directly from the
/// Master ESP32-S3's own local web server (added in firmware v5.9;
/// see BenchPad_Master_ESP32S3_v5_9.ino's handleStatusJson()).
///
/// Important: this is the device's own local web server, not the
/// cloud — it's only reachable while the phone is on the same network
/// as the board (either the board's own "BenchPad_Master_AP" hotspot,
/// or the shared WiFi it's also connected to). It has nothing to do
/// with the rest of the app, which all talks to Cloudflare.
class MasterTelemetryScreen extends StatefulWidget {
  const MasterTelemetryScreen({super.key});

  @override
  State<MasterTelemetryScreen> createState() => _MasterTelemetryScreenState();
}

class _MasterTelemetryScreenState extends State<MasterTelemetryScreen> {
  final _ipController = TextEditingController(text: '192.168.4.1');
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('http://${_ipController.text.trim()}/status.json')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        setState(() {
          _data = jsonDecode(res.body) as Map<String, dynamic>;
          _error = null;
        });
      } else {
        setState(() => _error = 'Device replied with ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Not reachable — make sure your phone is on the same network as the board.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
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
        appBar: AppBar(leading: Builder(builder: backLeading), leadingWidth: 64, centerTitle: true, title: const Text('Master Telemetry')),
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
                const Text('LOCAL NETWORK ONLY', style: TextStyle(color: NeumorphicPalette.danger, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text(
                  "Reads directly from the Master board's own web server — only works while your phone is on the same network as the board (its own hotspot, or shared WiFi).",
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 14),
                NeumorphicBox(
                  flat: true,
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      const Text('IP', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary, fontFamily: 'monospace'),
                          decoration: const InputDecoration(border: InputBorder.none, filled: false, isDense: true),
                          onSubmitted: (_) => _load(),
                        ),
                      ),
                      IconButton(icon: Icon(_loading ? Icons.hourglass_top : Icons.refresh, size: 18, color: NeumorphicPalette.accent), onPressed: _load),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 12)),
                  ),
                if (d != null) ...[
                  _section('System', [
                    _row('Uptime', '${d['uptimeSec']} sec'),
                    _row('Free heap', '${d['freeHeap']} bytes'),
                    _row('PSRAM', '${d['psramFree']} / ${d['psramTotal']} bytes free'),
                  ]),
                  _section('Master AP', [
                    _row('SSID', '${d['masterApSsid']}'),
                    _row('IP', '${d['masterApIp']}'),
                    _row('Clients', '${d['masterApClients']}'),
                  ]),
                  _section('Internet', [
                    _statusRow('Connectivity', d['internetConnected'] == true),
                    _row('IP', '${d['internetIp']}'),
                    if (d['wifiForceDisabled'] == true) _statusRow('WiFi force-disabled', false, label2: 'ON — testing LTE failover'),
                  ]),
                  _section('LTE Modem', [
                    _statusRow('Enabled', d['lteInternetEnabled'] == true),
                    _statusRow('Connected', d['lteConnected'] == true),
                    _row('Signal', (d['lteSignalPercent'] as num?) != null && (d['lteSignalPercent'] as num) >= 0 ? '${d['lteSignalPercent']}%' : 'No reading yet'),
                    if ('${d['lastLteFailReason'] ?? ''}'.isNotEmpty)
                      _row('Last failure', '${d['lastLteFailReason']}'),
                  ]),
                  _section('Cloudflare (device job queue)', [
                    _row('HTTP code', '${d['cloudHttpCode']}'),
                    _statusRow('Download', d['lastDownloadOk'] == true),
                    _statusRow('ACK', d['lastAckOk'] == true),
                    _row('ACK HTTP code', '${d['lastAckHttpCode']}'),
                    if ('${d['lastAckFailReason'] ?? ''}'.isNotEmpty)
                      _row('ACK failure', '${d['lastAckFailReason']}'),
                    if ('${d['lastAckResponseBody']}'.isNotEmpty) _row('ACK reply', '${d['lastAckResponseBody']}'),
                    _row('Last successful job', ('${d['lastImageJobCode']}').isEmpty ? '(none)' : '${d['lastImageJobCode']}'),
                    _row('Last successful size', '${d['lastImageSize']}'),
                    if ('${d['lastDownloadFailReason'] ?? ''}'.isNotEmpty)
                      _row('Last failure', '${d['lastDownloadFailReason']}'),
                  ]),
                  _section('EE02 Slave', [
                    _row('IP', '${d['slaveIp']}'),
                    _statusRow('TCP', d['slaveTcpConnected'] == true),
                    _statusRow('Pending image', d['slavePendingImage'] == true),
                  ]),
                  _section('GPS / GNSS', [
                    _statusRow('Modem', d['gpsModemResponding'] == true),
                    _statusRow('GNSS powered on', d['gpsGnssPoweredOn'] == true),
                    if (d['gpsFixValid'] == true) ...[
                      _row('Fix', '${(d['gpsLat'] as num).toStringAsFixed(6)}, ${(d['gpsLon'] as num).toStringAsFixed(6)}'),
                      _row('Fix age', '${d['gpsFixAgeSec']} sec'),
                    ] else
                      _statusRow('Fix', false, label2: 'No fix yet'),
                  ]),
                  _section('Victron SmartSolar (Bluetooth)', [
                    _statusRow('Seen', d['victronSeen'] == true, label2: d['victronSeen'] == true ? null : 'Never decoded a packet yet'),
                    if (d['victronSeen'] == true) ...[
                      _row('Battery', '${d['victronBatteryVoltage']} V · ${d['victronBatteryCurrent']} A'),
                      _row('Solar power', '${d['victronSolarPowerW']} W'),
                      _row('Yield today', '${d['victronYieldTodayKwh']} kWh'),
                      _row('Last seen', '${d['victronLastSeenSec']} sec ago'),
                    ],
                  ]),
                  _section('Last Event', [
                    Text('${d['lastEvent']}', style: const TextStyle(fontSize: 12, color: NeumorphicPalette.textPrimary)),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: NeumorphicPalette.accent)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11))),
          Expanded(child: Text(value, style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _statusRow(String label, bool ok, {String? label2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11))),
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 14, color: ok ? NeumorphicPalette.success : NeumorphicPalette.danger),
          const SizedBox(width: 6),
          Expanded(child: Text(label2 ?? (ok ? 'OK' : 'NOT OK'), style: TextStyle(color: ok ? NeumorphicPalette.success : NeumorphicPalette.danger, fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
