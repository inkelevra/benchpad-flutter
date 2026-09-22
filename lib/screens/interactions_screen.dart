import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// Interactions — NFC/QR activity log + location sharing, ported from
/// interactions.html.
///
/// Simplification note: the PWA reads deep-link query params (?tag=,
/// ?bench=, ?interaction=) set when someone taps an NFC tag or scans a
/// QR code that opens this page in a browser. The app doesn't have that
/// entry point yet (no NFC scanning or deep-link routing built), so this
/// shows the session/location controls and the real server-side
/// interaction log, without a "current interaction from URL" section.
class InteractionsScreen extends StatefulWidget {
  const InteractionsScreen({super.key});

  @override
  State<InteractionsScreen> createState() => _InteractionsScreenState();
}

class _InteractionsScreenState extends State<InteractionsScreen> {
  final _api = BenchpadApi();
  List<Map<String, dynamic>> _events = [];
  String _counterText = 'Connecting…';
  bool _locationSharing = false;
  Position? _lastPosition;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _counterText = 'Connecting…');
    try {
      final events = await _api.getRecentInteractions();
      if (mounted) {
        setState(() {
          _events = events;
          _counterText = '${events.length} event${events.length == 1 ? '' : 's'}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _counterText = 'Local mode — $e');
    }
  }

  Future<void> _toggleLocation() async {
    if (_locationSharing) {
      setState(() { _locationSharing = false; _lastPosition = null; });
      return;
    }

    setState(() => _locationError = null);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Permission denied');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() { _locationSharing = true; _lastPosition = position; });
      await _api.postInteractionEvent({
        'eventType': 'location_update',
        'occurredAt': DateTime.now().toIso8601String(),
        'location': {
          'permission': 'granted',
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
      });
    } catch (e) {
      setState(() => _locationError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: const Text('Interactions')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('NFC / QR ACTIVITY', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text('Waiting for an NFC or QR entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Session and location controls below; the server interaction log shows all recent activity.',
                style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            _buildLocationCard(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Platform interaction log', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(_counterText, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            if (_events.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
                child: const Text('No interactions yet.', textAlign: TextAlign.center, style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
              )
            else
              ..._events.map(_buildEventCard),
          ],
        ),
      ),
    ));
  }

  Widget _buildLocationCard() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('SMARTPHONE LOCATION', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9, fontWeight: FontWeight.w800))),
                Switch(value: _locationSharing, onChanged: (_) => _toggleLocation()),
              ],
            ),
            if (_locationSharing && _lastPosition != null)
              Text(
                '${_lastPosition!.latitude.toStringAsFixed(6)}, ${_lastPosition!.longitude.toStringAsFixed(6)} · ±${_lastPosition!.accuracy.round()} m',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              )
            else if (_locationError != null)
              Text(_locationError!, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 12))
            else
              const Text('Not requested', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            const Text(
              'Location is optional. BenchPad continues to work when location is declined.',
              style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10),
            ),
          ],
        ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e) {
    final eventType = ((e['eventType'] ?? e['event_type'] ?? 'event') as String).replaceAll('_', ' ');
    final occurredAt = e['occurredAt'] ?? e['occurred_at'] ?? e['received_at'];
    final benchId = e['benchId'] ?? e['bench_id'] ?? '—';
    final interactionId = e['interactionId'] ?? e['interaction_id'] ?? '—';
    final source = e['source'] ?? '—';
    String location = '—';
    if (e['latitude'] != null && e['longitude'] != null) {
      final acc = e['accuracy'] != null ? ' · ±${(e['accuracy'] as num).round()} m' : '';
      location = '${(e['latitude'] as num).toStringAsFixed(5)}, ${(e['longitude'] as num).toStringAsFixed(5)}$acc';
    } else {
      final parts = [e['city'], e['region'], e['country']].where((p) => p != null && p != '').toList();
      if (parts.isNotEmpty) location = parts.join(', ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(eventType, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Text('$occurredAt', style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            _metaRow('BenchPad', '$benchId'),
            _metaRow('Interaction', '$interactionId'),
            _metaRow('Source', '$source'),
            _metaRow('Location', location),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
