import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';

/// Network Control — the single page for all network control: WiFi
/// network list (live signal per configured network, tap to prefer),
/// force-WiFi-off (for testing LTE failover), LTE enable/connect
/// status, and remote (cloud-relayed) transport preference that works
/// from anywhere. Everything except the last section is local-network
/// only — reads from the Master board's own local web server
/// (/status.json) and posts to it directly, so needs the phone on the
/// board's own network. The Bench and Master Telemetry show related
/// status but are read-only by design — this is the one place to
/// actually change anything.
class NetworkControlScreen extends StatefulWidget {
  const NetworkControlScreen({super.key});

  @override
  State<NetworkControlScreen> createState() => _NetworkControlScreenState();
}

class _NetworkControlScreenState extends State<NetworkControlScreen> {
  final _api = BenchpadApi();
  final _ipController = TextEditingController(text: '192.168.4.1');
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;
  bool _sendingCommand = false;
  bool _sendingRemoteCommand = false;
  Timer? _autoRefresh;

  // v5.27 — remote (cloud) mirror of Full Diagnostics, works from
  // anywhere, independent of the local-only _data/_load above.
  Map<String, dynamic>? _remoteData;
  String? _remoteError;
  bool _remoteLoading = false;
  Timer? _remoteAutoRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    _loadRemote();
    _remoteAutoRefresh = Timer.periodic(const Duration(seconds: 20), (_) => _loadRemote());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _remoteAutoRefresh?.cancel();
    _ipController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadRemote() async {
    if (_remoteLoading) return;
    setState(() => _remoteLoading = true);
    try {
      final device = await _api.getRemoteDiagnostics('BP-AMS-001');
      if (mounted) {
        setState(() {
          _remoteData = device;
          _remoteError = device == null ? 'No remote diagnostics reported yet' : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _remoteError = '$e');
    } finally {
      if (mounted) setState(() => _remoteLoading = false);
    }
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

  Future<void> _setPreferred(int index) async {
    setState(() => _sendingCommand = true);
    try {
      final res = await http
          .post(Uri.parse('http://${_ipController.text.trim()}/api/network-command'), body: '$index')
          .timeout(const Duration(seconds: 15)); // reconnect can take a few seconds
      if (res.statusCode == 200) {
        await _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Command rejected by the board.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not reachable — same-network required.')));
    } finally {
      if (mounted) setState(() => _sendingCommand = false);
    }
  }

  Future<void> _setLteEnabled(bool enable) async {
    setState(() => _sendingCommand = true);
    try {
      final res = await http
          .post(Uri.parse('http://${_ipController.text.trim()}/api/lte-command'), body: enable ? '1' : '0')
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        await _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Command rejected by the board.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not reachable — same-network required.')));
    } finally {
      if (mounted) setState(() => _sendingCommand = false);
    }
  }

  Future<void> _setWifiForceDisabled(bool disable) async {
    setState(() => _sendingCommand = true);
    try {
      final res = await http
          .post(Uri.parse('http://${_ipController.text.trim()}/api/wifi-command'), body: disable ? '1' : '0')
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        await _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Command rejected by the board.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not reachable — same-network required.')));
    } finally {
      if (mounted) setState(() => _sendingCommand = false);
    }
  }

  Future<void> _setRemoteTransport(String transport) async {
    setState(() => _sendingRemoteCommand = true);
    try {
      await _api.setPreferredNetworkTransport('BP-AMS-001', transport);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent — board checks for this within a minute.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Command failed: $e')));
    } finally {
      if (mounted) setState(() => _sendingRemoteCommand = false);
    }
  }

  bool _sendingRemoteWifiForce = false;

  Future<void> _setRemoteWifiForceDisabled(bool disabled) async {
    setState(() => _sendingRemoteWifiForce = true);
    try {
      await _api.setWifiForceDisabled('BP-AMS-001', disabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent — board checks for this within a minute.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Command failed: $e')));
    } finally {
      if (mounted) setState(() => _sendingRemoteWifiForce = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final rd = _remoteData;
    final networks = (d?['wifiNetworks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final ltePercent = (d?['lteSignalPercent'] as num?)?.toInt();
    final lteEnabled = d?['lteInternetEnabled'] == true;
    final lteConnected = d?['lteConnected'] == true;

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
        appBar: AppBar(leading: Builder(builder: backLeading), leadingWidth: 64, centerTitle: true, title: const Text('Network Control')),
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
                  "Reads and controls the Master board directly — only works while your phone is on the same network as the board.",
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
                  const Text('WI-FI NETWORKS', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  ...networks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final net = entry.value;
                    final connected = net['connected'] == true;
                    final preferred = net['preferred'] == true;
                    final rssi = (net['rssiDbm'] as num?)?.toInt() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NeumorphicBox(
                        flat: true,
                        borderRadius: 14,
                        onTap: _sendingCommand ? null : () => _setPreferred(index),
                        child: Row(
                          children: [
                            _signalBars(rssi),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${net['ssid']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    rssi == 0 ? 'Not in range' : '$rssi dBm${connected ? ' · connected' : ''}${preferred ? ' · preferred' : ''}',
                                    style: TextStyle(color: connected ? NeumorphicPalette.success : NeumorphicPalette.textSecondary, fontSize: 11, fontWeight: connected ? FontWeight.w700 : FontWeight.w400),
                                  ),
                                ],
                              ),
                            ),
                            if (connected) const Icon(Icons.check_circle, size: 18, color: NeumorphicPalette.success) else const Icon(Icons.chevron_right, size: 18, color: NeumorphicPalette.textSecondary),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text('Tap a network to set it as preferred — the board reconnects using it right away.', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                  const SizedBox(height: 10),
                  NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Force WiFi off', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: NeumorphicPalette.textPrimary)),
                              Text(
                                d?['wifiForceDisabled'] == true ? 'Disabled — for testing LTE failover' : 'Off — normal reconnect behaviour',
                                style: TextStyle(color: d?['wifiForceDisabled'] == true ? NeumorphicPalette.danger : NeumorphicPalette.textSecondary, fontSize: 10, fontWeight: d?['wifiForceDisabled'] == true ? FontWeight.w700 : FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: d?['wifiForceDisabled'] == true,
                          onChanged: _sendingCommand ? null : (v) => _setWifiForceDisabled(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('LTE MODEM', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  const Text(
                    'When enabled, the whole publish pipeline — fetching new jobs, downloading images, confirmations, device status — uses LTE instead of WiFi (as long as LTE is actually connected at that moment; otherwise it uses WiFi if that\'s available).',
                    style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _signalBars(ltePercent == null ? 0 : -113 + (ltePercent * 0.63).round()), // approximate dBm equivalent just to reuse the same bar visual
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ltePercent == null || ltePercent < 0 ? 'No signal reading yet' : '$ltePercent% signal',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lteEnabled ? (lteConnected ? 'Enabled · connected' : 'Enabled · connecting…') : 'Disabled — using WiFi',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: lteEnabled && lteConnected ? NeumorphicPalette.success : NeumorphicPalette.textSecondary),
                              ),
                            ),
                            Switch(
                              value: lteEnabled,
                              onChanged: _sendingCommand ? null : (v) => _setLteEnabled(v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('FULL DIAGNOSTICS', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  const Text('Same data as Master Telemetry — merged here so testing doesn\'t need two separate screens.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                  const SizedBox(height: 8),
                  _section('System', [
                    _row('Uptime', '${d?['uptimeSec']} sec'),
                    _row('Free heap', '${d?['freeHeap']} bytes'),
                    _row('PSRAM', '${d?['psramFree']} / ${d?['psramTotal']} bytes free'),
                  ]),
                  _section('Master AP', [
                    _row('SSID', '${d?['masterApSsid']}'),
                    _row('IP', '${d?['masterApIp']}'),
                    _row('Clients', '${d?['masterApClients']}'),
                  ]),
                  _section('Internet', [
                    _statusRow('Connectivity', d?['internetConnected'] == true),
                    _row('IP', '${d?['internetIp']}'),
                  ]),
                  _section('Cloudflare (device job queue)', [
                    _row('HTTP code', '${d?['cloudHttpCode']}'),
                    _statusRow('Download', d?['lastDownloadOk'] == true),
                    _statusRow('ACK', d?['lastAckOk'] == true),
                    _row('ACK HTTP code', '${d?['lastAckHttpCode']}'),
                    if ('${d?['lastAckFailReason'] ?? ''}'.isNotEmpty) _row('ACK failure', '${d?['lastAckFailReason']}'),
                    if ('${d?['lastAckResponseBody'] ?? ''}'.isNotEmpty) _row('ACK reply', '${d?['lastAckResponseBody']}'),
                    _row('Last successful job', ('${d?['lastImageJobCode'] ?? ''}').isEmpty ? '(none)' : '${d?['lastImageJobCode']}'),
                    _row('Last successful size', '${d?['lastImageSize']}'),
                    if ('${d?['lastDownloadFailReason'] ?? ''}'.isNotEmpty) _row('Last failure', '${d?['lastDownloadFailReason']}'),
                  ]),
                  _section('EE02 Slave', [
                    _row('IP', '${d?['slaveIp']}'),
                    _statusRow('TCP', d?['slaveTcpConnected'] == true),
                    _statusRow('Pending image', d?['slavePendingImage'] == true),
                  ]),
                  _section('GPS / GNSS', [
                    _statusRow('Modem', d?['gpsModemResponding'] == true),
                    _statusRow('GNSS powered on', d?['gpsGnssPoweredOn'] == true),
                    if (d?['gpsFixValid'] == true) ...[
                      _row('Fix', '${(d?['gpsLat'] as num).toStringAsFixed(6)}, ${(d?['gpsLon'] as num).toStringAsFixed(6)}'),
                      _row('Fix age', '${d?['gpsFixAgeSec']} sec'),
                    ] else
                      _statusRow('Fix', false, label2: 'No fix yet'),
                  ]),
                  _section('Victron SmartSolar (Bluetooth)', [
                    _statusRow('Seen', d?['victronSeen'] == true, label2: d?['victronSeen'] == true ? null : 'Never decoded a packet yet'),
                    if (d?['victronSeen'] == true) ...[
                      _row('Battery', '${d?['victronBatteryVoltage']} V · ${d?['victronBatteryCurrent']} A'),
                      _row('Solar power', '${d?['victronSolarPowerW']} W'),
                      _row('Yield today', '${d?['victronYieldTodayKwh']} kWh'),
                      _row('Last seen', '${d?['victronLastSeenSec']} sec ago'),
                    ],
                  ]),
                  _section('Last Event', [
                    Text('${d?['lastEvent']}', style: const TextStyle(fontSize: 12, color: NeumorphicPalette.textPrimary)),
                  ]),
                ],
                // v5.27_3 — REMOTE CONTROL + REMOTE DIAGNOSTICS moved out of
                // the `if (d != null)` block above: those two sections work
                // via the cloud and must NOT depend on the local (same-
                // network) /status.json fetch succeeding, unlike everything
                // else on this screen. Previously they were nested inside
                // that block, so a flaky/unreachable local AP hid the
                // cloud-based controls too — exactly the controls meant to
                // be the fallback when the local connection is unreliable.
                const SizedBox(height: 20),
                const Text('REMOTE CONTROL', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text(
                  'Works from anywhere via the cloud (unlike everything above, which needs your phone on the board\'s own network) — the board checks for this within a minute.',
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sendingRemoteCommand ? null : () => _setRemoteTransport('WIFI'),
                        child: const Text('PREFER WIFI', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sendingRemoteCommand ? null : () => _setRemoteTransport('LTE'),
                        child: const Text('PREFER LTE', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // v5.28 — remote counterpart of "Force WiFi off" above
                // (which requires being on the board's own local AP).
                // This is the fix for exactly that: send-from-anywhere,
                // same as Prefer WiFi/LTE right above.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sendingRemoteWifiForce ? null : () => _setRemoteWifiForceDisabled(true),
                        child: const Text('FORCE WIFI OFF', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sendingRemoteWifiForce ? null : () => _setRemoteWifiForceDisabled(false),
                        child: const Text('RESTORE WIFI', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('REMOTE DIAGNOSTICS', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text(
                  'Same fields as Full Diagnostics above, reported to the cloud roughly every 90s — works from anywhere, unlike the local section above it.',
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10),
                ),
                const SizedBox(height: 8),
                if (rd == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _remoteLoading ? 'Loading…' : (_remoteError ?? 'No remote diagnostics reported yet'),
                      style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
                    ),
                  )
                else ...[
                  _section('System', [
                    _row('Uptime', '${rd['uptimeSec']} sec'),
                    _row('Free heap', '${rd['freeHeap']} bytes'),
                    _row('Last updated', '${rd['updatedAt']}'),
                  ]),
                  _section('Network', [
                    _statusRow('WiFi', rd['wifiConnected'] == true, label2: rd['wifiConnected'] == true ? '${rd['wifiSsid']}' : null),
                    _statusRow('LTE', rd['lteConnected'] == true, label2: rd['lteConnected'] == true ? '${rd['lteSignalPercent']}% signal' : null),
                  ]),
                  _section('Cloudflare (device job queue)', [
                    _row('HTTP code', '${rd['cloudHttpCode']}'),
                    _statusRow('Download', rd['lastDownloadOk'] == true),
                    _statusRow('ACK', rd['lastAckOk'] == true),
                    if ('${rd['lastDownloadFailReason'] ?? ''}'.isNotEmpty) _row('Last failure', '${rd['lastDownloadFailReason']}'),
                  ]),
                  _section('EE02 Slave', [
                    _row('IP', '${rd['slaveIp']}'),
                    _statusRow('TCP', rd['slaveTcpConnected'] == true),
                    _statusRow('Pending image', rd['slavePendingImage'] == true),
                  ]),
                  _section('GPS / GNSS', [
                    _statusRow('Modem', rd['gpsModemResponding'] == true),
                    if (rd['gpsFixValid'] == true)
                      _row('Fix', '${(rd['gpsLat'] as num).toStringAsFixed(6)}, ${(rd['gpsLon'] as num).toStringAsFixed(6)}')
                    else
                      _statusRow('Fix', false, label2: 'No fix yet'),
                  ]),
                  _section('Victron SmartSolar (Bluetooth)', [
                    _statusRow('Seen', rd['victronSeen'] == true, label2: rd['victronSeen'] == true ? null : 'Never decoded a packet yet'),
                    if (rd['victronSeen'] == true) ...[
                      _row('Battery', '${rd['victronBatteryVoltage']} V'),
                      _row('Solar power', '${rd['victronSolarPowerW']} W'),
                    ],
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

  Widget _signalBars(int rssiDbm) {
    // Same rough scale phones use: -50 excellent, -60 good, -70 fair, -80 weak.
    int level;
    if (rssiDbm == 0) {
      level = 0;
    } else if (rssiDbm >= -55) {
      level = 4;
    } else if (rssiDbm >= -65) {
      level = 3;
    } else if (rssiDbm >= -75) {
      level = 2;
    } else {
      level = 1;
    }
    return SizedBox(
      width: 28,
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(4, (i) {
          final active = i < level;
          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Container(
              width: 4,
              height: 6.0 + i * 4,
              decoration: BoxDecoration(
                color: active ? NeumorphicPalette.accent : NeumorphicPalette.shadowDark.withOpacity(0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }),
      ),
    );
  }
}
