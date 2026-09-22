import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// BenchPad Environment — optional sensor package preview, ported from
/// benchpad-environment.html. The metric values are demo data hardcoded
/// in the PWA too, not live telemetry from BP-AMS-001.
class EnvironmentScreen extends StatelessWidget {
  const EnvironmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BenchPad Environment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF295243)),
              borderRadius: BorderRadius.circular(24),
              gradient: RadialGradient(center: Alignment.topRight, radius: 1.2, colors: [const Color(0xFF70DF8A).withOpacity(0.12), Colors.transparent]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BENCHPAD ENVIRONMENT', style: TextStyle(color: Color(0xFF70DF8A), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                const Text('SEE THE CITY\nAROUND THE BENCH.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 0.95, letterSpacing: -1)),
                const SizedBox(height: 10),
                const Text('An optional sensor package can turn BenchPad into a compact environmental sensing point for its immediate urban surroundings.', style: TextStyle(color: Color(0xFF92A19D), fontSize: 12, height: 1.6)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0x55E0B64C)), borderRadius: BorderRadius.circular(999), color: const Color(0x0BE0B64C)),
                  child: const Text('OPTIONAL SENSOR PACKAGE · PROTOTYPE PREVIEW', style: TextStyle(color: Color(0xFFE8C76C), fontSize: 8, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              _metric('TEMPERATURE', '18.7 °C', 'Ambient air temperature', const Color(0xFF65D7FF)),
              _metric('HUMIDITY', '64%', 'Relative humidity', const Color(0xFF65D7FF)),
              _metric('AIR QUALITY', 'GOOD', 'AQI 32 · Demo value', const Color(0xFF70DF8A)),
              _metric('NOISE LEVEL', '48 dB', 'Normal urban level · Demo value', Colors.white),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF203640)), borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SENSOR PACKAGE STATUS', style: TextStyle(color: Color(0xFF65D7FF), fontSize: 8, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Environment module preview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _row('Bench', 'BP-AMS-001 · Amsterdam'),
                _row('Configuration', 'Optional Environment Package'),
                _row('Last sensor update', 'Prototype Demo · Not live telemetry'),
                _row('Sensor status', 'Preview values'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: const Color(0x40E0B64C)), borderRadius: BorderRadius.circular(16), color: const Color(0x08E0B64C)),
            child: const Text(
              'Environmental sensing is an optional BenchPad configuration. The values shown on this page are demo data and are not measurements from BP-AMS-001. Real readings require physical sensors and device integration.',
              style: TextStyle(color: Color(0xFFA89B77), fontSize: 10, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF203B3A)), borderRadius: BorderRadius.circular(20), color: const Color(0xFF091315)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(color: Color(0xFF8A9996), fontSize: 8, fontWeight: FontWeight.w900)),
            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF70DF8A))),
          ]),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: Color(0xFF84928F), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1C3038)), borderRadius: BorderRadius.circular(12), color: const Color(0xFF061015)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF82908D), fontSize: 9)),
            Flexible(child: Text(value, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }
}
