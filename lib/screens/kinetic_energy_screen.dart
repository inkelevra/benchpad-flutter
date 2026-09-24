import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// Kinetic Energy Level — a live-telemetry visualization of the
/// bench's power path: sun -> solar panel -> controller -> battery
/// (and back) -> USB -> ESP32-S3 -> XIAO -> E-Ink pixel assembly ->
/// display flicker -> Kinesus logo.
///
/// Shows the real fields the Master board's Victron BLE decode
/// actually reports to /api/device/status: battery voltage/current,
/// solar input wattage, charging status. Deliberately does NOT show
/// a battery charge PERCENTAGE — the Victron SmartSolar MPPT is a
/// charge controller, not a battery monitor; it has no way to
/// determine state-of-charge, only voltage and current. An earlier
/// version of this screen showed a percentage anyway, permanently
/// stuck on a hardcoded 0.76 'DEMO' placeholder (labeled, but easy to
/// miss) since the field it expected never actually arrives — exactly
/// the kind of fabricated-looking number this project's own firmware
/// comments elsewhere explicitly reject ("controller reports voltage,
/// not state-of-charge — sending a made-up percentage would be a
/// guess dressed up as a real reading").
class KineticEnergyScreen extends StatefulWidget {
  const KineticEnergyScreen({super.key});

  @override
  State<KineticEnergyScreen> createState() => _KineticEnergyScreenState();
}

class _KineticEnergyScreenState extends State<KineticEnergyScreen> {
  final _api = BenchpadApi();
  double? _batteryVoltage;
  double? _batteryCurrent;
  double? _solarInputW;
  String? _chargingStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadTelemetry() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await _api.getDeviceEngineeringStatus('BP-AMS-001');
      if (!mounted) return;
      setState(() {
        _batteryVoltage = (data['batteryVoltage'] as num?)?.toDouble();
        _batteryCurrent = (data['batteryCurrent'] as num?)?.toDouble();
        _solarInputW = (data['solarInputW'] as num?)?.toDouble();
        _chargingStatus = data['chargingStatus'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasLiveData => _batteryVoltage != null || _batteryCurrent != null || _solarInputW != null || _chargingStatus != null;

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
        appBar: AppBar(title: const Text('Kinetic Energy Level')),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: RefreshIndicator(
            onRefresh: _loadTelemetry,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_loading) _statusBadge(),
                const SizedBox(height: 14),
                const Text('Solar & battery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                const SizedBox(height: 4),
                const Text('Read from the Victron SmartSolar 75/15 over Bluetooth.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: NeumorphicPalette.accent)))
                else if (!_hasLiveData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('The device has not reported solar/battery telemetry yet.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
                  )
                else
                  NeumorphicBox(
                    flat: true,
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _telemetryRow(Icons.bolt, 'Battery voltage', _batteryVoltage != null ? '${_batteryVoltage!.toStringAsFixed(2)} V' : '—'),
                        const Divider(height: 1, color: Color(0x22000000)),
                        _telemetryRow(Icons.electrical_services, 'Battery current', _batteryCurrent != null ? '${_batteryCurrent!.toStringAsFixed(2)} A' : '—'),
                        const Divider(height: 1, color: Color(0x22000000)),
                        _telemetryRow(Icons.wb_sunny_outlined, 'Solar input', _solarInputW != null ? '${_solarInputW!.toStringAsFixed(0)} W' : '—'),
                        const Divider(height: 1, color: Color(0x22000000)),
                        _telemetryRow(Icons.battery_charging_full, 'Charging status', _chargingStatus ?? '—'),
                      ],
                    ),
                  ),
                const SizedBox(height: 36),
                const Text('Power & signal path', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                const SizedBox(height: 4),
                const Text('Illustrated flow — not a live current reading.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                const SizedBox(height: 20),
                const _FlowPath(),
                const SizedBox(height: 36),
                const _PixelAssemblyAndReveal(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _telemetryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NeumorphicPalette.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13))),
          Text(value, style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    if (_hasLiveData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: NeumorphicPalette.success.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 13, color: NeumorphicPalette.success),
            SizedBox(width: 6),
            Text('LIVE — real telemetry from the device', style: TextStyle(color: NeumorphicPalette.success, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: NeumorphicPalette.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 13, color: NeumorphicPalette.danger),
          SizedBox(width: 6),
          Text('No live data yet', style: TextStyle(color: NeumorphicPalette.danger, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// The full stage chain, sun down to the XIAO board, with pulsing
/// connectors between each stage.
class _FlowPath extends StatelessWidget {
  const _FlowPath();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _stageIcon(Icons.wb_sunny_rounded, 'Sun', const Color(0xFFF5B942)),
        const _PulseConnector(color: Color(0xFFF5B942)),
        _stageIcon(Icons.solar_power_outlined, 'Solar panel', const Color(0xFFF5B942)),
        const _PulseConnector(color: Color(0xFFF5B942)),
        _stageIcon(Icons.memory_outlined, 'Controller', NeumorphicPalette.accent),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(width: 20, child: _PulseConnector(color: NeumorphicPalette.accent)),
            SizedBox(width: 24),
            SizedBox(width: 20, child: _PulseConnector(color: Color(0xFF3FA6A0), reverse: true)),
          ],
        ),
        _stageIcon(Icons.battery_charging_full_outlined, 'Battery', const Color(0xFFB4693F)),
        const _PulseConnector(color: NeumorphicPalette.accent),
        _stageIcon(Icons.developer_board_outlined, 'ESP32-S3 · LTE to Cloudflare', NeumorphicPalette.accent),
        const _PulseConnector(color: Color(0xFF7A5CF0)),
        _stageIcon(Icons.developer_board, 'XIAO · image processing', const Color(0xFF7A5CF0)),
      ],
    );
  }

  Widget _stageIcon(IconData icon, String label, Color color) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary))),
        ],
      ),
    );
  }
}

/// A vertical connector line with a small dot pulsing along it,
/// looping continuously.
class _PulseConnector extends StatefulWidget {
  final Color color;
  final bool reverse;

  const _PulseConnector({required this.color, this.reverse = false});

  @override
  State<_PulseConnector> createState() => _PulseConnectorState();
}

class _PulseConnectorState extends State<_PulseConnector> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(width: 2, height: 30, color: widget.color.withOpacity(0.25)),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = widget.reverse ? 1 - _controller.value : _controller.value;
              return Positioned(
                top: t * 24,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.color.withOpacity(0.7), blurRadius: 6)]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Pixels assembling into an image, an E-Ink-style flicker, then the
/// Kinesus logo settling into place.
class _PixelAssemblyAndReveal extends StatefulWidget {
  const _PixelAssemblyAndReveal();

  @override
  State<_PixelAssemblyAndReveal> createState() => _PixelAssemblyAndRevealState();
}

class _PixelAssemblyAndRevealState extends State<_PixelAssemblyAndReveal> with TickerProviderStateMixin {
  late final AnimationController _assembleController;
  late final AnimationController _flashController;
  static const _gridSize = 6;

  @override
  void initState() {
    super.initState();
    _assembleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _assembleController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('E-Ink assembly', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
        const SizedBox(height: 4),
        const Text('Pixels assemble, the display flickers, then settles.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: NeumorphicBox(
            flat: true,
            borderRadius: 20,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedBuilder(
                animation: Listenable.merge([_assembleController, _flashController]),
                builder: (context, child) {
                  final loop = _assembleController.value;
                  // 0.0-0.7 assembling, 0.7-0.85 flicker, 0.85-1.0 settled logo
                  if (loop < 0.7) {
                    return _buildPixelGrid(loop / 0.7);
                  } else if (loop < 0.85) {
                    return Container(color: Colors.white.withOpacity(_flashController.value * 0.8));
                  } else {
                    return _buildLogoReveal();
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPixelGrid(double progress) {
    final total = _gridSize * _gridSize;
    final revealCount = (progress * total).floor();
    return Container(
      color: NeumorphicPalette.background,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _gridSize),
        itemCount: total,
        itemBuilder: (context, i) {
          final revealed = i < revealCount;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: revealed ? Color.lerp(const Color(0xFFDD3355), const Color(0xFF2255DD), (i % _gridSize) / _gridSize) : NeumorphicPalette.shadowDark.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoReveal() {
    return Container(
      color: NeumorphicPalette.background,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Image.asset('assets/images/kinesus-flower-logo.webp', fit: BoxFit.contain),
      ),
    );
  }
}
