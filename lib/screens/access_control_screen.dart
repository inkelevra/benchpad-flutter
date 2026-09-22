import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// Platform Access — owner security controls, ported from
/// access-control.html.
class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  final _api = BenchpadApi();
  final _deviceNameController = TextEditingController(text: "This device");
  final _guestLabelController = TextEditingController(text: 'BenchPad guest');
  int _guestMinutes = 60;

  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _activity = [];
  String? _message;
  bool _messageIsError = false;
  String? _recoveryCode;
  String? _guestLink;
  String? _pendingChallenge;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _deviceNameController.dispose();
    _guestLabelController.dispose();
    super.dispose();
  }

  void _setMessage(String text, {bool isError = false}) {
    setState(() { _message = text; _messageIsError = isError; });
  }

  Future<void> _load() async {
    try {
      final status = await _api.getPlatformAccessStatus();
      setState(() => _status = status);
      _setMessage(
        status['safetyFallback'] != null
            ? 'Safe PUBLIC fallback: ${status['safetyFallback']}.'
            : (status['recoveryReady'] == true ? 'Trusted access and recovery protection are ready.' : 'Complete device trust and create a recovery code before PRIVATE.'),
        isError: status['safetyFallback'] != null,
      );
      final devices = await _api.getTrustedDevices();
      if (mounted) setState(() => _devices = devices);
      if (status['trusted'] == true) {
        final activity = await _api.getAccessActivity();
        if (mounted) setState(() => _activity = activity);
      }
    } catch (e) {
      _setMessage(e.toString(), isError: true);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? successMessage}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (successMessage != null) _setMessage(successMessage);
      await _load();
    } catch (e) {
      _setMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final trusted = status?['trusted'] == true;

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
      appBar: AppBar(title: const Text('Platform Access')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Controls who can reach BenchPad's public website — separate from this app's own owner sign-in. Starts in PUBLIC mode and cannot enter PRIVATE until this browser is trusted and a recovery code exists.",
              style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(_message!, style: TextStyle(color: _messageIsError ? NeumorphicPalette.danger : const Color(0xFF78E29A), fontSize: 12)),
            ],
            const SizedBox(height: 16),
            if (status != null)
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: [
                  _metric('MODE', '${status['effectiveMode'] ?? '—'}'),
                  _metric('TRUSTED', '${status['trustedCount'] ?? '—'}'),
                  _metric('THIS DEVICE', trusted ? 'TRUSTED' : 'NOT TRUSTED'),
                ],
              ),
            const SizedBox(height: 20),
            _sectionCard(
              title: '1. Trust this device',
              subtitle: 'Register this device before closing the platform.',
              children: [
                TextField(controller: _deviceNameController, decoration: const InputDecoration(labelText: 'DEVICE NAME')),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _busy ? null : () => _run(() => _api.trustThisDevice(_deviceNameController.text.trim()), successMessage: 'This device is now trusted.'),
                  child: Text(trusted ? 'UPDATE DEVICE NAME' : 'TRUST THIS DEVICE'),
                ),
              ],
            ),
            _sectionCard(
              title: '2. Recovery access',
              subtitle: 'Create and save one recovery code. It is shown once.',
              children: [
                if (!trusted) ...[
                  const Text('Trust this device first (step 1 above).', style: TextStyle(color: NeumorphicPalette.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  onPressed: !trusted || _busy ? null : () async {
                    try {
                      final code = await _api.createRecoveryCode();
                      setState(() => _recoveryCode = code);
                      _setMessage('Recovery code created. Save it now.');
                    } catch (e) {
                      _setMessage(e.toString(), isError: true);
                    }
                  },
                  child: const Text('CREATE NEW RECOVERY CODE'),
                ),
                if (_recoveryCode != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFE4BF69).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4BF69).withOpacity(0.35))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(_recoveryCode!, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1)),
                        const SizedBox(height: 6),
                        const Text('Save this code outside BenchPad. Creating another invalidates the previous one.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            _sectionCard(
              title: '3. Platform mode',
              subtitle: 'PRIVATE uses a two-step confirmation.',
              children: [
                if (!trusted) ...[
                  const Text('Trust this device first (step 1 above).', style: TextStyle(color: NeumorphicPalette.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: !trusted || _busy ? null : () => _run(() => _api.setPlatformMode('PUBLIC'), successMessage: 'PUBLIC mode enabled.'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D754B), foregroundColor: const Color(0xFFA6EFB7)),
                      child: const Text('PUBLIC'),
                    ),
                    ElevatedButton(
                      onPressed: !trusted || _busy ? null : () async {
                        try {
                          final result = await _api.preparePrivateMode();
                          setState(() => _pendingChallenge = result['challenge'] as String);
                          _setMessage('Private confirmation prepared for ${result['trustedCount']} trusted device(s).');
                        } catch (e) {
                          _setMessage(e.toString(), isError: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: NeumorphicPalette.danger, foregroundColor: Colors.white),
                      child: const Text('PREPARE PRIVATE'),
                    ),
                    OutlinedButton(
                      onPressed: !trusted || _busy ? null : () => _run(() => _api.setPlatformMode('MAINTENANCE'), successMessage: 'MAINTENANCE mode enabled.'),
                      child: const Text('MAINTENANCE'),
                    ),
                    OutlinedButton(
                      onPressed: !trusted || _busy ? null : () => _run(() async {
                        final until = await _api.temporaryPublicAccess(30);
                        _setMessage('Public access open until $until.');
                      }),
                      child: const Text('PUBLIC FOR 30 MIN'),
                    ),
                  ],
                ),
                if (_pendingChallenge != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: NeumorphicPalette.danger.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current trusted device verified.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(height: 4),
                        const Text('Confirm within 60 seconds.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _busy ? null : () => _run(() async {
                                  await _api.confirmPrivateMode(_pendingChallenge!);
                                  setState(() => _pendingChallenge = null);
                                }, successMessage: 'PRIVATE mode enabled.'),
                                style: ElevatedButton.styleFrom(backgroundColor: NeumorphicPalette.danger, foregroundColor: Colors.white),
                                child: const Text('CONFIRM PRIVATE'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _pendingChallenge = null),
                                child: const Text('CANCEL'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            _sectionCard(
              title: 'Trusted devices',
              subtitle: 'Register each device separately before enabling PRIVATE.',
              children: [
                if (_devices.isEmpty)
                  const Text('No trusted devices.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))
                else
                  ..._devices.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: NeumorphicBox(
                          flat: true,
                          borderRadius: 12,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${d['displayName']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                    const SizedBox(height: 3),
                                    Text('Last active: ${d['lastSeenAt'] ?? '—'}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _busy ? null : () => _run(() => _api.revokeDevice(d['deviceId'] as String), successMessage: 'Device access removed.'),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: NeumorphicPalette.background,
                                    boxShadow: [
                                      BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.6), offset: const Offset(2, 2), blurRadius: 4),
                                      const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                                    ],
                                  ),
                                  child: const Icon(Icons.delete_outline, color: NeumorphicPalette.danger, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(() => _api.revokeOtherDevices(), successMessage: 'All other devices were revoked.'),
                  style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.danger, side: const BorderSide(color: NeumorphicPalette.danger)),
                  child: const Text('REVOKE ALL EXCEPT THIS DEVICE'),
                ),
              ],
            ),
            _sectionCard(
              title: 'Temporary guest access',
              subtitle: 'Create an expiring invitation.',
              children: [
                TextField(controller: _guestLabelController, decoration: const InputDecoration(labelText: 'LABEL')),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _guestMinutes,
                  decoration: const InputDecoration(labelText: 'DURATION'),
                  style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 14),
                  dropdownColor: NeumorphicPalette.background,
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 minutes')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                    DropdownMenuItem(value: 1440, child: Text('24 hours')),
                  ],
                  onChanged: (v) => setState(() => _guestMinutes = v ?? 60),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _run(() async {
                          final link = await _api.createGuestLink(minutes: _guestMinutes, singleUse: false, label: _guestLabelController.text.trim());
                          setState(() => _guestLink = link);
                        }, successMessage: 'Guest link created.'),
                        child: const Text('CREATE LINK'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _run(() async {
                          final link = await _api.createGuestLink(minutes: _guestMinutes, singleUse: true, label: _guestLabelController.text.trim());
                          setState(() => _guestLink = link);
                        }, successMessage: 'Single-use link created.'),
                        child: const Text('SINGLE-USE'),
                      ),
                    ),
                  ],
                ),
                if (_guestLink != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(10)),
                    child: SelectableText(_guestLink!, style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ],
            ),
            _sectionCard(
              title: 'Access activity',
              subtitle: 'Recent allowed and blocked navigation attempts.',
              children: [
                if (_activity.isEmpty)
                  const Text('No access events yet.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))
                else
                  ..._activity.map((e) {
                    final allowed = (e['decision'] as String?)?.toUpperCase() == 'ALLOWED';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${e['reason'] ?? ''}', style: const TextStyle(fontSize: 11)),
                                Text('${e['path'] ?? '/'}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9)),
                              ],
                            ),
                          ),
                          Text('${e['decision']}', style: TextStyle(color: allowed ? const Color(0xFF78E29A) : NeumorphicPalette.danger, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    );
                  }),
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
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
