import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// Device detail — ported from device.html.
class DeviceScreen extends StatefulWidget {
  final String deviceId;
  const DeviceScreen({super.key, required this.deviceId});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final _api = BenchpadApi();
  Map<String, dynamic>? _device;
  String _statusNote = 'Loading device…';

  final _displayNameController = TextEditingController();
  final _modelController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  String _profileStatus = '';
  bool _savingProfile = false;

  List<Map<String, dynamic>> _jobs = [];

  // Hardware spec form
  final _hwDisplayModel = TextEditingController();
  final _hwDisplayResolution = TextEditingController();
  final _hwControllerModel = TextEditingController();
  final _hwModemModel = TextEditingController();
  final _hwNfcModel = TextEditingController();
  final _hwBatteryModel = TextEditingController();
  final _hwSolarPanelModel = TextEditingController();
  final _hwChargeControllerModel = TextEditingController();
  final _hwDcDcModel = TextEditingController();
  final _hwNotes = TextEditingController();
  String _hardwareStatus = '';
  bool _savingHardware = false;

  // NFC tag assignment
  final _nfcTagIdController = TextEditingController();
  String _nfcUrl = '';
  String _nfcStatus = '';
  bool _savingNfc = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _displayNameController.dispose();
    _modelController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _hwDisplayModel.dispose();
    _hwDisplayResolution.dispose();
    _hwControllerModel.dispose();
    _hwModemModel.dispose();
    _hwNfcModel.dispose();
    _hwBatteryModel.dispose();
    _hwSolarPanelModel.dispose();
    _hwChargeControllerModel.dispose();
    _hwDcDcModel.dispose();
    _hwNotes.dispose();
    _nfcTagIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _statusNote = 'Loading device…');
    try {
      final device = await _api.getSingleDevice(widget.deviceId);
      if (device == null) throw Exception('Device not found');
      if (mounted) setState(() { _device = device; _statusNote = ''; });
    } catch (e) {
      if (mounted) setState(() => _statusNote = 'Error: $e');
    }
    await _loadProfile();
    await _loadJobs();
    await _loadHardware();
    await _loadNfc();
  }

  Future<void> _loadProfile() async {
    setState(() => _profileStatus = 'Loading profile…');
    try {
      final profile = await _api.getDeviceProfile(widget.deviceId);
      _displayNameController.text = (profile['displayName'] ?? '') as String;
      _modelController.text = (profile['modelName'] ?? '') as String;
      _locationController.text = (profile['locationLabel'] ?? '') as String;
      _notesController.text = (profile['notes'] ?? '') as String;
      setState(() => _profileStatus = profile['updatedAt'] != null ? 'Profile updated: ${profile['updatedAt']}' : 'No profile data saved yet.');
    } catch (e) {
      setState(() => _profileStatus = 'Error: $e');
    }
  }

  Future<void> _saveProfile() async {
    setState(() { _savingProfile = true; _profileStatus = 'Saving profile…'; });
    try {
      final profile = await _api.saveDeviceProfile(
        deviceId: widget.deviceId,
        displayName: _displayNameController.text.trim(),
        modelName: _modelController.text.trim(),
        locationLabel: _locationController.text.trim(),
        notes: _notesController.text.trim(),
      );
      setState(() => _profileStatus = 'Profile saved: ${profile['updatedAt']}');
    } catch (e) {
      setState(() => _profileStatus = 'Error: $e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await _api.getDeliveryJobs(widget.deviceId);
      if (mounted) setState(() => _jobs = jobs);
    } catch (_) {}
  }

  Future<void> _loadHardware() async {
    setState(() => _hardwareStatus = 'Loading hardware configuration…');
    try {
      final hw = await _api.getDeviceHardware(widget.deviceId);
      _hwDisplayModel.text = (hw['displayModel'] ?? '') as String;
      _hwDisplayResolution.text = (hw['displayResolution'] ?? '') as String;
      _hwControllerModel.text = (hw['controllerModel'] ?? '') as String;
      _hwModemModel.text = (hw['modemModel'] ?? '') as String;
      _hwNfcModel.text = (hw['nfcModel'] ?? '') as String;
      _hwBatteryModel.text = (hw['batteryModel'] ?? '') as String;
      _hwSolarPanelModel.text = (hw['solarPanelModel'] ?? '') as String;
      _hwChargeControllerModel.text = (hw['chargeControllerModel'] ?? '') as String;
      _hwDcDcModel.text = (hw['dcDcModel'] ?? '') as String;
      _hwNotes.text = (hw['hardwareNotes'] ?? '') as String;
      setState(() => _hardwareStatus = hw['updatedAt'] != null ? 'Hardware last saved: ${hw['updatedAt']}' : 'No hardware configuration saved yet.');
    } catch (e) {
      setState(() => _hardwareStatus = 'Error: $e');
    }
  }

  void _loadPrototypeHardwareDefaults() {
    setState(() {
      _hwDisplayModel.text = '13.3-inch E-Ink Spectra 6';
      _hwDisplayResolution.text = '1600 × 1200';
      _hwControllerModel.text = 'Seeed XIAO ePaper EE02';
      _hwModemModel.text = 'ESP32-S3 + A7670E 4G';
      _hwNfcModel.text = 'NTAG215';
      _hwBatteryModel.text = 'LiFePO4 12.8 V 6 Ah';
      _hwSolarPanelModel.text = '18 V 20 W';
      _hwChargeControllerModel.text = 'PWM 12/24 V';
      _hwDcDcModel.text = '12/24 V → 5 V, up to 10 A';
      _hwNotes.text = 'BenchPad prototype: 13.3-inch 1600 × 1200 color E-Ink, dedicated EE02 display controller and ESP32-S3 + A7670E communications controller. Camera is not used. Verify wiring and voltage before every power-on.';
      _hardwareStatus = 'Prototype hardware loaded into the form. Review and save when ready.';
    });
  }

  Future<void> _saveHardware() async {
    setState(() { _savingHardware = true; _hardwareStatus = 'Saving hardware configuration…'; });
    try {
      final hw = await _api.saveDeviceHardware({
        'deviceId': widget.deviceId,
        'displayModel': _hwDisplayModel.text.trim(),
        'displayResolution': _hwDisplayResolution.text.trim(),
        'controllerModel': _hwControllerModel.text.trim(),
        'modemModel': _hwModemModel.text.trim(),
        'nfcModel': _hwNfcModel.text.trim(),
        'batteryModel': _hwBatteryModel.text.trim(),
        'solarPanelModel': _hwSolarPanelModel.text.trim(),
        'chargeControllerModel': _hwChargeControllerModel.text.trim(),
        'dcDcModel': _hwDcDcModel.text.trim(),
        'hardwareNotes': _hwNotes.text.trim(),
      });
      setState(() => _hardwareStatus = 'Hardware saved: ${hw['updatedAt']}');
    } catch (e) {
      setState(() => _hardwareStatus = 'Error: $e');
    } finally {
      if (mounted) setState(() => _savingHardware = false);
    }
  }

  String _buildNfcUrl(String tagId) {
    if (tagId.isEmpty) return '';
    return 'https://benchpad.pages.dev/index.html?source=nfc&tag=${Uri.encodeComponent(tagId)}&bench=${Uri.encodeComponent(widget.deviceId)}';
  }

  Future<void> _loadNfc() async {
    try {
      final assignment = await _api.getDeviceNfc(widget.deviceId);
      _nfcTagIdController.text = (assignment['tagId'] ?? '') as String;
      setState(() => _nfcUrl = _buildNfcUrl(_nfcTagIdController.text));
    } catch (_) {}
  }

  Future<void> _saveNfc() async {
    final tagId = _nfcTagIdController.text.trim();
    if (tagId.isEmpty) {
      setState(() => _nfcStatus = 'Tag ID is required.');
      return;
    }
    setState(() { _savingNfc = true; _nfcStatus = 'Saving NFC assignment…'; });
    try {
      final assignment = await _api.saveDeviceNfc(deviceId: widget.deviceId, tagId: tagId);
      setState(() { _nfcUrl = _buildNfcUrl(tagId); _nfcStatus = 'NFC assignment saved: ${assignment['updatedAt']}'; });
    } catch (e) {
      setState(() => _nfcStatus = 'Error: $e');
    } finally {
      if (mounted) setState(() => _savingNfc = false);
    }
  }

  Future<void> _copyNfcUrl() async {
    final url = _buildNfcUrl(_nfcTagIdController.text.trim());
    if (url.isEmpty) {
      setState(() => _nfcStatus = 'Enter a Tag ID first.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    setState(() { _nfcUrl = url; _nfcStatus = 'NFC URL copied.'; });
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final online = device?['online'] == true;

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
      appBar: AppBar(title: Text(widget.deviceId)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (device == null)
              Text(_statusNote, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))
            else ...[
              Row(
                children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? const Color(0xFF46D483) : NeumorphicPalette.danger)),
                  const SizedBox(width: 8),
                  Text(online ? 'Online' : 'Offline', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(width: 10),
                  Text('Last seen: ${device['lastSeen'] ?? 'Never'}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [
                  _metric('BATTERY', device['batteryPercent'] != null ? '${device['batteryPercent']}%' : '—'),
                  _metric('POWER', '${device['powerValue'] ?? '—'}'),
                  _metric('E-INK', '${device['einkStatus'] ?? '—'}'),
                  _metric('NETWORK', '${device['networkStatus'] ?? '—'}'),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _sectionCard(
              title: 'Device profile',
              children: [
                TextField(controller: _displayNameController, decoration: const InputDecoration(labelText: 'Display name')),
                const SizedBox(height: 8),
                TextField(controller: _modelController, decoration: const InputDecoration(labelText: 'Model name')),
                const SizedBox(height: 8),
                TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 8),
                TextField(controller: _notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _savingProfile ? null : _saveProfile, child: Text(_savingProfile ? 'Saving…' : 'Save profile')),
                const SizedBox(height: 8),
                Text(_profileStatus, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ),
            _sectionCard(
              title: 'Recent delivery jobs',
              children: [
                if (_jobs.isEmpty)
                  const Text('No jobs yet.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))
                else
                  ..._jobs.take(10).map((job) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text('${job['contentType']} · ${job['jobId']}', style: const TextStyle(fontSize: 11))),
                            Text('${job['status']}', style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      )),
              ],
            ),
            _sectionCard(
              title: 'Hardware configuration',
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _loadPrototypeHardwareDefaults, child: const Text('LOAD PROTOTYPE DEFAULTS')),
                ),
                TextField(controller: _hwDisplayModel, decoration: const InputDecoration(labelText: 'Display model')),
                const SizedBox(height: 8),
                TextField(controller: _hwDisplayResolution, decoration: const InputDecoration(labelText: 'Display resolution')),
                const SizedBox(height: 8),
                TextField(controller: _hwControllerModel, decoration: const InputDecoration(labelText: 'Controller model')),
                const SizedBox(height: 8),
                TextField(controller: _hwModemModel, decoration: const InputDecoration(labelText: 'Modem model')),
                const SizedBox(height: 8),
                TextField(controller: _hwNfcModel, decoration: const InputDecoration(labelText: 'NFC chip model')),
                const SizedBox(height: 8),
                TextField(controller: _hwBatteryModel, decoration: const InputDecoration(labelText: 'Battery model')),
                const SizedBox(height: 8),
                TextField(controller: _hwSolarPanelModel, decoration: const InputDecoration(labelText: 'Solar panel model')),
                const SizedBox(height: 8),
                TextField(controller: _hwChargeControllerModel, decoration: const InputDecoration(labelText: 'Charge controller model')),
                const SizedBox(height: 8),
                TextField(controller: _hwDcDcModel, decoration: const InputDecoration(labelText: 'DC-DC converter model')),
                const SizedBox(height: 8),
                TextField(controller: _hwNotes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _savingHardware ? null : _saveHardware, child: Text(_savingHardware ? 'Saving…' : 'Save hardware configuration')),
                const SizedBox(height: 8),
                Text(_hardwareStatus, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ),
            _sectionCard(
              title: 'NFC tag assignment',
              children: [
                const Text(
                  'Assign a physical NFC tag ID to this device. Write the generated URL to the tag using an external NFC-writing app or tool.',
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 10),
                TextField(controller: _nfcTagIdController, decoration: const InputDecoration(labelText: 'Tag ID')),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _savingNfc ? null : _saveNfc, child: Text(_savingNfc ? 'Saving…' : 'Save assignment')),
                if (_nfcUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(10)),
                    child: SelectableText(_nfcUrl, style: const TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: _copyNfcUrl, icon: const Icon(Icons.copy, size: 16), label: const Text('COPY NFC URL')),
                ],
                const SizedBox(height: 8),
                Text(_nfcStatus, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  Widget _metric(String label, String value) {
    return Container(
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
