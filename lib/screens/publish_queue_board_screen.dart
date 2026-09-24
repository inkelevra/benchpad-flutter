import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/benchpad_api.dart';

/// Public, system-wide publish queue board — a real airport-departures
/// board layout (the user's own reference image), repurposed:
///   (header) BP-AMS-001 is the "airport" itself — shown once at the
///            top, not repeated per row.
///   TIME   -> when the publication was submitted (takeoff)
///   FROM   -> the publisher's city — the whole point of this board:
///             showing publications arriving from all over the world
///   TO     -> always "AMSTERDAM" (single physical display for now)
///   GATE   -> landing time — the real displayed_at once it has
///             actually shown, otherwise an estimate
///   REMARK -> total time in transit (takeoff -> landing), "CANCELLED"
///             for a failed/rejected job, or the live elapsed time for
///             one still in flight
/// Shows the last 50 publications system-wide (not just this device's
/// own — that's the separate, private PublishQueueScreen) — active and
/// already-landed both, so the board isn't empty just because nothing
/// is queued right now.
class PublishQueueBoardScreen extends StatefulWidget {
  const PublishQueueBoardScreen({super.key});

  @override
  State<PublishQueueBoardScreen> createState() => _PublishQueueBoardScreenState();
}

class _PublishQueueBoardScreenState extends State<PublishQueueBoardScreen> {
  final _api = BenchpadApi();
  List<Map<String, dynamic>> _board = [];
  String? _error;
  bool _loading = true;
  Timer? _refreshTimer;

  static const _bg = Color(0xFF0A0A0F);
  static const _amber = Color(0xFFFFC94D);

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await _api.getPublishQueueBoard();
      if (!mounted) return;
      setState(() {
        _board = (data['board'] as List? ?? []).cast<Map<String, dynamic>>();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = silent ? _error : e.toString();
        _loading = false;
      });
    }
  }

  String _hhmm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// "1h 04m", "3m 12s", "12s" — whichever units apply, dropping the
  /// larger unit entirely when it's zero rather than padding with
  /// "0h".
  String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  /// The dot-matrix "split-flap board" font, wrapped so the rest of
  /// this file never has to spell out GoogleFonts.dotGothic16's full
  /// (many-optional-parameter) signature.
  TextStyle _font({Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing}) {
    return GoogleFonts.dotGothic16(color: color, fontSize: fontSize, fontWeight: fontWeight, letterSpacing: letterSpacing);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: _bg),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _DotGridPainter(dotColor: _amber.withOpacity(0.05)))),
              RefreshIndicator(
                onRefresh: () => _load(),
                child: NotificationListener<OverscrollIndicatorNotification>(
                  onNotification: (n) {
                    n.disallowIndicator();
                    return true;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _titleBlock(),
                      const SizedBox(height: 14),
                      _headerRow(),
                      const SizedBox(height: 6),
                      Container(height: 2, color: _amber.withOpacity(0.5)),
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ],
                      if (_loading && _board.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: _amber)))
                      else if (_board.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('NO PUBLICATIONS YET', style: _font(color: Colors.white.withOpacity(0.5), fontSize: 14, letterSpacing: 1)),
                          ),
                        )
                      else
                        ..._board.map(_boardRow),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// BP-AMS-001 is the "airport" this board belongs to — stated once
  /// here, at the top, instead of repeated on every row.
  Widget _titleBlock() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: _amber, width: 1.6), borderRadius: BorderRadius.circular(4)),
          child: Icon(Icons.flight_takeoff, color: _amber, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AMSTERDAM', style: _font(color: _amber, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1)),
            Text('BP-AMS-001 · ARRIVALS', style: _font(color: _amber.withOpacity(0.6), fontSize: 11, letterSpacing: 1)),
          ],
        ),
      ],
    );
  }

  Widget _headerRow() {
    final style = _font(color: _amber, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5);
    return Row(
      children: [
        Expanded(flex: 2, child: Text('TIME', style: style)),
        Expanded(flex: 3, child: Text('FROM', style: style)),
        Expanded(flex: 3, child: Text('TO', style: style)),
        Expanded(flex: 2, child: Text('GATE', style: style)),
        Expanded(flex: 2, child: Text('REMARK', style: style, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _boardRow(Map<String, dynamic> job) {
    final createdAt = DateTime.tryParse(job['createdAt'] as String? ?? '')?.toLocal();
    final displayedAt = DateTime.tryParse(job['displayedAt'] as String? ?? '')?.toLocal();
    final etaSeconds = (job['estimatedWaitSeconds'] as num?)?.toInt() ?? 0;
    final estimatedGate = createdAt?.add(Duration(seconds: etaSeconds));
    final status = job['status'] as String? ?? '';
    final cancelled = status == 'FAILED' || status == 'REJECTED';

    final sourceCity = (job['sourceCity'] as String?)?.trim();
    final sourceCountry = (job['sourceCountry'] as String?)?.trim();
    final from = (sourceCity == null || sourceCity.isEmpty) ? (sourceCountry?.isNotEmpty == true ? sourceCountry! : 'UNKNOWN') : sourceCity;
    final destinationCity = (job['destinationCity'] as String?)?.trim();

    // GATE: the real landing time once it's landed, otherwise the
    // estimate.
    final gateTime = displayedAt ?? estimatedGate;

    // REMARK: total time in transit once landed; "CANCELLED" for a
    // failed/rejected job (matches the reference board's own
    // vocabulary); live elapsed time so far for one still in flight.
    String remark;
    if (cancelled) {
      remark = 'CANCELLED';
    } else if (displayedAt != null && createdAt != null) {
      remark = _duration(displayedAt.difference(createdAt));
    } else if (createdAt != null) {
      remark = _duration(DateTime.now().difference(createdAt));
    } else {
      remark = '—';
    }

    final valueStyle = _font(color: cancelled ? Colors.white38 : Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5);
    final remarkStyle = valueStyle.copyWith(fontSize: 12, color: cancelled ? Colors.redAccent.withOpacity(0.85) : (displayedAt != null ? _amber : Colors.white70));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 2, child: Text(createdAt != null ? _hhmm(createdAt) : '--:--', style: valueStyle)),
          Expanded(flex: 3, child: Text(from.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: valueStyle)),
          Expanded(flex: 3, child: Text((destinationCity ?? 'AMSTERDAM').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: valueStyle)),
          Expanded(flex: 2, child: Text(gateTime != null ? _hhmm(gateTime) : '--:--', style: valueStyle)),
          Expanded(flex: 2, child: Text(remark, textAlign: TextAlign.right, style: remarkStyle)),
        ],
      ),
    );
  }
}

/// Faint background texture of "unlit" LED dots, like the reference
/// split-flap board — cheap to draw once, static (doesn't repaint on
/// scroll or data refresh).
class _DotGridPainter extends CustomPainter {
  final Color dotColor;
  const _DotGridPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 10.0;
    const dotRadius = 1.1;
    final paint = Paint()..color = dotColor;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => oldDelegate.dotColor != dotColor;
}
