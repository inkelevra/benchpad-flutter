import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import 'device_screen.dart';

/// Devices — hardware fleet management, ported from devices.html.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _api = BenchpadApi();
  List<Map<String, dynamic>> _devices = [];
  String _statusText = 'Loading devices…';
  bool _showRegisterForm = false;

  final _deviceIdController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _modelController = TextEditingController(text: 'BenchPad 13.3 Spectra 6');
  final _locationController = TextEditingController();
  final _controllerController = TextEditingController(text: 'ESP32-S3 + A7670E');
  final _resolutionController = TextEditingController(text: '1600 × 1200');
  final _notesController = TextEditingController();
  bool _safetyConfirmed = false;
  String? _registerStatus;
  bool _registering = false;

  final _heartbeatResults = <String, String>{};
  final _heartbeatChecking = <String>{};

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
    _modelController.dispose();
    _locationController.dispose();
    _controllerController.dispose();
    _resolutionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _statusText = 'Loading devices…');
    try {
      final devices = await _api.getDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _statusText = '${devices.length} device${devices.length == 1 ? '' : 's'} · Updated ${TimeOfDay.now().format(context)}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Error: $e');
    }
  }

  Future<void> _checkHeartbeat(String deviceId) async {
    setState(() { _heartbeatChecking.add(deviceId); _heartbeatResults[deviceId] = 'Checking authenticated heartbeat status…'; });
    try {
      final data = await _api.checkDeviceHeartbeat(deviceId);
      final heartbeat = (data['heartbeat'] as Map?) ?? {};
      final receiver = (data['receiver'] as Map?) ?? {};
      String result;
      if (heartbeat['online'] == true) {
        result = 'ONLINE · ${heartbeat['firmwareVersion'] ?? 'firmware unknown'} · ${heartbeat['networkStatus'] ?? 'network unknown'}';
      } else {
        result = receiver['claimed'] == true
            ? 'OFFLINE · onboarding exists, but no fresh heartbeat was received.'
            : 'NOT ONBOARDED · create the physical-device record first.';
      }
      setState(() => _heartbeatResults[deviceId] = result);
    } catch (e) {
      setState(() => _heartbeatResults[deviceId] = 'Verification failed: $e');
    } finally {
      setState(() => _heartbeatChecking.remove(deviceId));
    }
  }

  Future<void> _register() async {
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      setState(() => _registerStatus = 'Device ID is required.');
      return;
    }
    if (!_safetyConfirmed) {
      setState(() => _registerStatus = 'Confirm the power-off safety check before onboarding.');
      return;
    }
    setState(() { _registering = true; _registerStatus = 'Creating physical-device onboarding…'; });
    try {
      final result = await _api.registerDevice(
        deviceId: deviceId,
        displayName: _displayNameController.text.trim(),
        modelName: _modelController.text.trim(),
        locationLabel: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        controllerModel: _controllerController.text.trim(),
        displayResolution: _resolutionController.text.trim(),
      );
      final device = result['device'] as Map<String, dynamic>;
      setState(() {
        _registerStatus = 'Onboarding created for ${device['deviceId']}. Waiting for the first authenticated heartbeat.';
        _deviceIdController.clear();
        _displayNameController.clear();
        _locationController.clear();
        _notesController.clear();
        _safetyConfirmed = false;
      });
      await _load();
    } catch (e) {
      setState(() => _registerStatus = 'Error: $e');
    } finally {
      setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _devices.length;
    final connected = _devices.where((d) => d['online'] == true).length;
    final offline = total - connected;

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
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: [
                _metric('TOTAL', '$total'),
                _metric('CONNECTED', '$connected'),
                _metric('OFFLINE', '$offline'),
              ],
            ),
            const SizedBox(height: 12),
            Text(_statusText, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
            const SizedBox(height: 16),
            _buildRegisterPanel(),
            const SizedBox(height: 16),
            if (_devices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
                child: const Text(
                  'No BenchPad devices are known yet. A device appears here after telemetry or a delivery job exists for its deviceId.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
                ),
              )
            else
              ..._devices.map(_buildDeviceCard),
          ],
        ),
      ),
    ));
  }

  Widget _metric(String label, String value) {
    return Container(
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildRegisterPanel() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _showRegisterForm = !_showRegisterForm),
              child: Row(
                children: [
                  const Expanded(child: Text('+ Register new BenchPad', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w700, fontSize: 13))),
                  Icon(_showRegisterForm ? Icons.expand_less : Icons.expand_more, color: NeumorphicPalette.accent),
                ],
              ),
            ),
            if (_showRegisterForm) ...[
              const SizedBox(height: 12),
              TextField(controller: _deviceIdController, decoration: const InputDecoration(labelText: 'Device ID *', hintText: 'e.g. benchpad-001')),
              const SizedBox(height: 8),
              TextField(controller: _displayNameController, decoration: const InputDecoration(labelText: 'Display name', hintText: 'e.g. Main Entrance')),
              const SizedBox(height: 8),
              TextField(controller: _modelController, decoration: const InputDecoration(labelText: 'BenchPad model')),
              const SizedBox(height: 8),
              TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Installation location', hintText: 'e.g. Building A')),
              const SizedBox(height: 8),
              TextField(controller: _controllerController, decoration: const InputDecoration(labelText: 'Controller')),
              const SizedBox(height: 8),
              TextField(controller: _resolutionController, decoration: const InputDecoration(labelText: 'Display resolution')),
              const SizedBox(height: 8),
              TextField(controller: _notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _safetyConfirmed,
                onChanged: (v) => setState(() => _safetyConfirmed = v ?? false),
                title: const Text(
                  'I confirm that power is disconnected. Before the first power-up I will re-check voltage, polarity, common ground and connector orientation.',
                  style: TextStyle(fontSize: 11, color: NeumorphicPalette.textPrimary),
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: _registering ? null : _register,
                child: Text(_registering ? 'Creating…' : 'Create physical-device onboarding'),
              ),
              if (_registerStatus != null) ...[
                const SizedBox(height: 8),
                Text(_registerStatus!, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ],
          ],
        ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final deviceId = device['deviceId'] as String;
    final online = device['online'] == true;
    final latestJob = device['latestJob'] as Map?;
    final latestJobText = latestJob != null ? '${(latestJob['status'] as String).toUpperCase()} · ${latestJob['jobId']}' : 'No delivery jobs';
    final checking = _heartbeatChecking.contains(deviceId);
    final heartbeatResult = _heartbeatResults[deviceId];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceScreen(deviceId: deviceId))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deviceId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${device['displayName'] ?? 'Unnamed BenchPad'}', style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                      Text([device['modelName'], device['locationLabel']].where((e) => e != null && e != '').join(' · '),
                          style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                      const SizedBox(height: 3),
                      Text('Last seen: ${device['lastSeen'] ?? 'Never'}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (online ? const Color(0xFF46D483) : NeumorphicPalette.danger).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(online ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: online ? const Color(0xFF46D483) : NeumorphicPalette.danger, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: [
                _smallMetric('BATTERY', device['batteryPercent'] != null ? '${device['batteryPercent']}%' : '—'),
                _smallMetric('POWER', '${device['powerValue'] ?? '—'}'),
                _smallMetric('E-INK', '${device['einkStatus'] ?? '—'}'),
                _smallMetric('NETWORK', '${device['networkStatus'] ?? '—'}'),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: NeumorphicPalette.background), borderRadius: BorderRadius.circular(10)),
              child: Text('Pending jobs: ${device['pendingJobs'] ?? 0} · Latest: $latestJobText', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: Text('ESP32 HEARTBEAT VERIFICATION', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800))),
                TextButton(
                  onPressed: checking ? null : () => _checkHeartbeat(deviceId),
                  child: Text(checking ? 'Checking…' : 'Check heartbeat'),
                ),
              ],
            ),
            if (heartbeatResult != null)
              Text(heartbeatResult, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _smallMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
          Text(value, style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
