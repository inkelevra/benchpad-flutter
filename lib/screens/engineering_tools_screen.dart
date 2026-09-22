import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import 'publish_queue_screen.dart';
import 'content_moderation_screen.dart';
import 'devices_screen.dart';
import 'interactions_screen.dart';
import 'backup_screen.dart';
import 'bench_engineering_screen.dart';
import 'environment_screen.dart';
import 'network_control_screen.dart';

/// Engineering Tools — device receiver management, ported from
/// engineering-tools.html.
///
/// "Devices", "NFC/QR Interactions", and "Backup" link out to PWA pages
/// (devices.html, interactions.html, benchpad-backup.html) not yet
/// ported — shown disabled with a note.
class EngineeringToolsScreen extends StatefulWidget {
  const EngineeringToolsScreen({super.key});

  @override
  State<EngineeringToolsScreen> createState() => _EngineeringToolsScreenState();
}

class _EngineeringToolsScreenState extends State<EngineeringToolsScreen> {
  final _api = BenchpadApi();
  final _deviceIdController = TextEditingController(text: 'BP-AMS-001');
  final _displayNameController = TextEditingController(text: 'BenchPad Amsterdam Prototype');
  final _controllerController = TextEditingController(text: 'ESP32-S3 + A7670E');
  final _resolutionController = TextEditingController(text: '1600 × 1200');
  String _onboardingMode = 'VIRTUAL';

  Map<String, dynamic>? _receiver;
  Map<String, dynamic>? _heartbeat;
  String _receiverMode = 'VIRTUAL';
  String _claimStatus = 'Ready.';
  String _simulationStatus = 'Applies to the latest publish job.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _deviceIdController.dispose();
    _displayNameController.dispose();
    _controllerController.dispose();
    _resolutionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getDeviceReceiver();
      if (mounted) {
        setState(() {
          _receiver = data['receiver'] as Map<String, dynamic>?;
          _heartbeat = data['heartbeat'] as Map<String, dynamic>?;
          _receiverMode = (_receiver?['receiverMode'] as String?) ?? 'VIRTUAL';
        });
      }
    } catch (_) {}
  }

  Future<void> _setMode(String mode) async {
    try {
      await _api.setReceiverMode(
        deviceId: _deviceIdController.text.trim(),
        mode: mode,
        controllerModel: _controllerController.text.trim(),
        displayResolution: _resolutionController.text.trim(),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _claim() async {
    setState(() => _claimStatus = 'Claiming device…');
    try {
      final result = await _api.claimDevice(
        deviceId: _deviceIdController.text.trim(),
        displayName: _displayNameController.text.trim(),
        controllerModel: _controllerController.text.trim(),
        displayResolution: _resolutionController.text.trim(),
        receiverMode: _onboardingMode,
      );
      setState(() => _claimStatus = '${result['message']} ✓ · ${(result['device'] as Map)['deviceId']} · ${(result['device'] as Map)['receiverMode']}');
      _load();
    } catch (e) {
      setState(() => _claimStatus = e.toString());
    }
  }

  Future<void> _simulate(String action) async {
    setState(() => _simulationStatus = 'Simulating $action…');
    try {
      final result = await _api.simulateJob(action);
      setState(() => _simulationStatus = '${result['jobCode']} · ${result['action']} · VIRTUAL RECEIVER');
    } catch (e) {
      setState(() => _simulationStatus = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhysical = _receiverMode == 'PHYSICAL';

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
      appBar: AppBar(title: const Text('Engineering Tools')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Receiver mode, device onboarding, heartbeat readiness and Virtual Receiver simulation.',
              style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Platform Engineering',
              subtitle: 'Hardware, publishing, NFC/QR and backup controls',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishQueueScreen())), child: const Text('PUBLISH JOBS')),
                    OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContentModerationScreen())), child: const Text('MODERATION')),
                    OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevicesScreen())), child: const Text('DEVICES')),
                    OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BenchEngineeringScreen())), child: const Text('THE BENCH')),
                    OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnvironmentScreen())), child: const Text('ENVIRONMENT')),
                    OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InteractionsScreen())), child: const Text('NFC / QR')),
                    OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())), child: const Text('BACKUP')),
                  ],
                ),
              ],
            ),
            _sectionCard(
              title: 'Receiver Mode · BP-AMS-001',
              subtitle: 'Virtual mode auto-completes jobs. Physical waits for the ESP32.',
              children: [
                _row('Mode', _receiverMode),
                _row('Controller', '${_receiver?['controllerModel'] ?? '—'}'),
                _row('Display', '${_receiver?['displayResolution'] ?? '—'}'),
                _row('Claimed', _receiver?['claimed'] == true ? 'CLAIMED ✓' : 'NOT CLAIMED'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _setMode('VIRTUAL'), child: const Text('SET VIRTUAL'))),
                    const SizedBox(width: 8),
                    Expanded(child: ElevatedButton(onPressed: () => _setMode('PHYSICAL'), child: const Text('SET PHYSICAL'))),
                  ],
                ),
              ],
            ),
            _sectionCard(
              title: 'Network Control',
              subtitle: 'WiFi signal per network, LTE signal, remote network preference.',
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkControlScreen())),
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('OPEN NETWORK CONTROL'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Local network only — same WiFi/hotspot as the board.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ),
            _sectionCard(
              title: 'Device Last Seen',
              subtitle: 'Online = heartbeat received within the last 60 seconds.',
              children: [
                _row('Status', _heartbeat?['online'] == true ? 'ONLINE' : 'OFFLINE'),
                _row('Last seen', '${_heartbeat?['lastSeen'] ?? '—'}'),
                _row('Firmware', '${_heartbeat?['firmwareVersion'] ?? '—'}'),
                _row('Battery', _heartbeat?['batteryPercent'] != null ? '${_heartbeat!['batteryPercent']}%' : '—'),
                _row('Network', '${_heartbeat?['networkStatus'] ?? '—'}'),
                _row('Signal', _heartbeat?['signalDbm'] != null ? '${_heartbeat!['signalDbm']} dBm' : '—'),
              ],
            ),
            _sectionCard(
              title: 'Claim Device',
              subtitle: 'Prepare a device before physical receiver activation.',
              children: [
                TextField(controller: _deviceIdController, decoration: const InputDecoration(labelText: 'Device ID')),
                const SizedBox(height: 8),
                TextField(controller: _displayNameController, decoration: const InputDecoration(labelText: 'Display name')),
                const SizedBox(height: 8),
                TextField(controller: _controllerController, decoration: const InputDecoration(labelText: 'Controller')),
                const SizedBox(height: 8),
                TextField(controller: _resolutionController, decoration: const InputDecoration(labelText: 'Display resolution')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 14),
                  dropdownColor: NeumorphicPalette.background,
                  value: _onboardingMode,
                  decoration: const InputDecoration(labelText: 'Receiver mode'),
                  items: const [
                    DropdownMenuItem(value: 'VIRTUAL', child: Text('VIRTUAL')),
                    DropdownMenuItem(value: 'PHYSICAL', child: Text('PHYSICAL')),
                  ],
                  onChanged: (v) => setState(() => _onboardingMode = v ?? 'VIRTUAL'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _claim, child: const Text('REGISTER / CLAIM DEVICE')),
                const SizedBox(height: 8),
                Text(_claimStatus, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ),
            _sectionCard(
              title: 'Virtual Receiver',
              subtitle: 'Engineering-only test controls — not for use once physical is active.',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isPhysical ? null : () => _simulate('DISPLAYED'),
                        child: const Text('SIMULATE DISPLAYED'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isPhysical ? null : () => _simulate('FAILED'),
                        style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.danger, side: const BorderSide(color: NeumorphicPalette.danger)),
                        child: const Text('SIMULATE FAILED'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isPhysical ? 'PHYSICAL mode active · simulation controls disabled.' : _simulationStatus,
                  style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }
  void _notReady() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not ported yet — coming in a future update.')));
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11))),
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
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
