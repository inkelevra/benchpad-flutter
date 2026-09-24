import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../services/capsule_store.dart';
import '../services/geosphere.dart';
import '../theme/benchpad_dark_theme.dart';
import '../widgets/home_back_leading.dart';
import 'capsule_creator_screen.dart';
import 'capsule_certificate_screen.dart';
import 'broadcast_calendar_screen.dart';
import 'profile_screen.dart';

/// Time Capsule 1 — personal time capsules as an interactive 3D
/// point-cloud, ported from benchpad-time-capsule.html. Same rendering
/// approach as Time Capsule 2 (Fibonacci sphere distribution, drag to
/// rotate, pinch to zoom, tap to select) — 162 points instead of 500 (12
/// "core" cells rendered larger/square, 150 "standard" cells the rest).
class VaultSphereScreen extends StatefulWidget {
  const VaultSphereScreen({super.key});

  @override
  State<VaultSphereScreen> createState() => _VaultSphereScreenState();
}

class _VaultSphereScreenState extends State<VaultSphereScreen> with SingleTickerProviderStateMixin {
  final _api = BenchpadApi();
  List<VaultCell> _cells = [];
  bool _loading = true;
  String? _error;

  double _rotationY = 0;
  double _rotationX = -0.15;
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset? _lastPanPos;
  bool _spinning = true;

  int? _selectedIndex;
  String _statusFilter = 'all';

  late final AnimationController _spinController;

  static const _statusColors = {
    'empty': Color(0xFF75E7FF),
    'locked': Color(0xFFFFD84D),
    'sealed': Color(0xFFFF4D68),
    'open': BPColors.success,
  };

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..addListener(() {
        if (_spinning) setState(() => _rotationY += 0.0006);
      })
      ..repeat();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cells = await _api.getVaultCells();
      final byKey = {for (final c in cells) '${c.type}:${c.number}': c};
      final core = List.generate(12, (i) => byKey['core:${i + 1}'] ?? VaultCell(type: 'core', number: i + 1, status: 'empty'));
      final standard = List.generate(150, (i) => byKey['standard:${i + 1}'] ?? VaultCell(type: 'standard', number: i + 1, status: 'empty'));
      if (mounted) {
        final combined = [...core, ...standard];
        setState(() {
          _cells = combined;
          _loading = false;
          _selectedIndex ??= _defaultSelection(combined);
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Picks a sensible cell to show by default so the info card isn't
  /// blank on first open — prefers 'open', falls back to any
  /// non-empty cell, null only if the sphere is entirely empty.
  int? _defaultSelection(List<VaultCell> cells) {
    for (int i = 0; i < cells.length; i++) {
      if (cells[i].status == 'open') return i;
    }
    for (int i = 0; i < cells.length; i++) {
      if (cells[i].status != 'empty') return i;
    }
    return null;
  }

  List<VaultCell> get _visibleCells {
    if (_statusFilter == 'all') return _cells;
    return _cells.where((c) => c.status == _statusFilter).toList();
  }

  Map<String, int> get _statusCounts {
    final counts = {'empty': 0, 'locked': 0, 'sealed': 0, 'open': 0};
    for (final c in _cells) {
      counts[c.status] = (counts[c.status] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _openCell(VaultCell cell) async {
    if (cell.status == 'empty' || cell.status == 'locked') {
      final ownerKey = await CapsuleStore.findKey('vault', cell.type, cell.number);
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: cell.type, number: cell.number, ownerKey: ownerKey)),
      );
      if (result == true) _load();
    } else {
      _showCellDetail(cell);
    }
  }

  void _showCellDetail(VaultCell cell) {
    final color = _statusColors[cell.status] ?? BPColors.yellow;
    showModalBottomSheet(
      context: context,
      backgroundColor: BPColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cell.displayId, style: const TextStyle(color: BPColors.yellow, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(cell.ownerName ?? 'Sealed capsule', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BPColors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
              child: Text(cell.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            if (cell.status == 'open' && cell.message != null) ...[
              const SizedBox(height: 16),
              Text('"${cell.message}"', style: const TextStyle(fontSize: 14, height: 1.4, fontStyle: FontStyle.italic, color: BPColors.textPrimary)),
            ] else if (cell.status == 'sealed') ...[
              const SizedBox(height: 12),
              Text(
                'This capsule is sealed. Its message will be revealed on ${cell.openingDate ?? "its opening date"}.',
                style: const TextStyle(color: BPColors.textSecondary, fontSize: 12),
              ),
            ],
            if (cell.ownerCountry != null) ...[
              const SizedBox(height: 12),
              Text('From ${cell.ownerCountry}', style: const TextStyle(color: BPColors.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, side: const BorderSide(color: BPColors.yellow)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => CapsuleCertificateScreen(type: cell.type, number: cell.number)));
              },
              child: const Text('VIEW CERTIFICATE'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, side: const BorderSide(color: BPColors.yellow)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BroadcastCalendarScreen(
                  sphere: 'vault',
                  capsuleType: cell.type,
                  capsuleNumber: cell.number,
                  ownerName: cell.ownerName ?? '',
                  ownerCountry: cell.ownerCountry ?? '',
                  contentReady: cell.message != null && cell.message!.isNotEmpty,
                )));
              },
              child: const Text('SCHEDULE BROADCAST'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: BPColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: BPColors.bg,
          foregroundColor: BPColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, disabledForegroundColor: BPColors.textSecondary, side: const BorderSide(color: BPColors.yellow)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: BPColors.yellow),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(builder: backLeading),
          leadingWidth: 64,
          centerTitle: true,
          title: const Text('Time Capsule 1'),
          actions: [
            IconButton(
              tooltip: 'My Capsules',
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            IconButton(
              tooltip: _spinning ? 'Pause rotation' : 'Resume rotation',
              icon: Icon(_spinning ? Icons.pause : Icons.play_arrow),
              onPressed: () => setState(() => _spinning = !_spinning),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: BPColors.yellow))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: BPColors.danger)))
                : Column(
                    children: [
                      _buildStatsBar(),
                      Expanded(child: _buildSphereStage()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _buildSelectedCard()),
                            const SizedBox(width: 8),
                            _roundIconButton(icon: Icons.search, tooltip: 'Search cells', onTap: _loading ? null : _showCellSearchSheet),
                            const SizedBox(width: 8),
                            _roundIconButton(icon: Icons.tune, tooltip: 'Jump to', onTap: _loading ? null : _showJumpSheet),
                          ],
                        ),
                      ),
                      _buildLegend(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: BPColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), offset: const Offset(3, 3), blurRadius: 6),
          BoxShadow(color: BPColors.yellow.withOpacity(0.18), offset: Offset(-3, -3), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          _statItem('12', 'CORE'),
          _statItem('150', 'STANDARD'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: BPColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ],
      ),
    );
  }

  Widget _buildSphereStage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: const RadialGradient(center: Alignment(-0.3, -0.3), radius: 1.3, colors: [Color(0xFF1A1F3A), Color(0xFF05060F)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BPColors.yellow.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), offset: const Offset(4, 4), blurRadius: 10),
          BoxShadow(color: BPColors.yellow.withOpacity(0.18), offset: Offset(-4, -4), blurRadius: 10),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
        onTapDown: (_) => _spinning = false,
        onScaleStart: (details) {
          _lastPanPos = details.focalPoint;
          _baseScale = _scale;
          _spinning = false;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 1 && _lastPanPos != null) {
              final delta = details.focalPoint - _lastPanPos!;
              _rotationY += delta.dx * 0.01;
              _rotationX = (_rotationX + delta.dy * 0.01).clamp(-1.4, 1.4);
              _lastPanPos = details.focalPoint;
            }
            _scale = (_baseScale * details.scale).clamp(0.6, 2.2);
          });
        },
        onTapUp: (details) => _handleTap(details.localPosition, constraints.biggest),
        child: CustomPaint(
          size: Size.infinite,
          painter: _VaultSpherePainter(
            cells: _visibleCells,
            totalCells: _cells.length,
            rotationX: _rotationX,
            rotationY: _rotationY,
            scale: _scale,
            selectedCell: _selectedIndex != null && _selectedIndex! < _cells.length ? _cells[_selectedIndex!] : null,
            statusColors: _statusColors,
          ),
        ),
        ),
      ),
    );
  }

  void _handleTap(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.46 * _scale;
    VaultCell? closest;
    double closestDist = 30;

    final visible = _visibleCells;
    for (int i = 0; i < visible.length; i++) {
      final p = _cellPosition(visible[i]);
      final rotated = _rotate(p, _rotationX, _rotationY);
      if (rotated.z < -0.1) continue;
      final screen = Offset(center.dx + rotated.x * radius, center.dy + rotated.y * radius);
      final dist = (screen - local).distance;
      if (dist < closestDist) {
        closestDist = dist;
        closest = visible[i];
      }
    }

    if (closest != null) {
      setState(() => _selectedIndex = _cells.indexOf(closest!));
    }
  }

  Widget _buildSelectedCard() {
    // Always the full card shape/size, selected or not (matches Hex
    // Grid's pattern) — a narrower text-only placeholder here made the
    // card visibly narrower whenever nothing was auto-selected yet.
    final cell = _selectedIndex != null && _selectedIndex! < _cells.length ? _cells[_selectedIndex!] : null;
    final color = cell != null ? (_statusColors[cell.status] ?? BPColors.yellow) : BPColors.textSecondary;
    return GestureDetector(
      onTap: cell == null ? null : () => _openCell(cell),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BPColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(3, 3), blurRadius: 6),
            BoxShadow(color: BPColors.yellow.withOpacity(0.18), offset: Offset(-3, -3), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: cell == null || cell.type != 'core' ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: cell != null && cell.type == 'core' ? BorderRadius.circular(12) : null,
                color: color.withOpacity(0.15),
                border: Border.all(color: color),
              ),
              child: Center(
                child: cell != null
                    ? Text('${cell.number}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13))
                    : const Icon(Icons.touch_app_outlined, size: 20, color: BPColors.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cell != null
                    ? [
                        Text(cell.type == 'core' ? 'CORE CELL' : 'STANDARD CELL', style: const TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(cell.ownerName ?? cell.displayId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(cell.status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]
                    : const [
                        Text('NO CELL SELECTED', style: TextStyle(color: BPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Tap a cell to open it', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BPColors.textSecondary)),
                      ],
              ),
            ),
            if (cell != null) Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  Widget _roundIconButton({required IconData icon, required String tooltip, required VoidCallback? onTap}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BPColors.card,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.55), offset: const Offset(3, 3), blurRadius: 6),
              BoxShadow(color: BPColors.yellow.withOpacity(0.18), offset: Offset(-3, -3), blurRadius: 6),
            ],
          ),
          child: Icon(icon, size: 20, color: onTap == null ? BPColors.textSecondary.withOpacity(0.4) : BPColors.yellow),
        ),
      ),
    );
  }

  void _showCellSearchSheet() {
    final controller = TextEditingController();
    List<VaultCell> results = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: BPColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void runSearch(String query) {
            final q = query.trim().toLowerCase();
            setSheetState(() {
              results = q.isEmpty
                  ? []
                  : _cells.where((c) {
                      return c.displayId.toLowerCase().contains(q) ||
                          (c.ownerName ?? '').toLowerCase().contains(q) ||
                          c.number.toString() == q;
                    }).toList();
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                const Text('SEARCH', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Text('Find a cell', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: runSearch,
                  decoration: const InputDecoration(hintText: 'Cell ID, number, or owner name'),
                ),
                const SizedBox(height: 16),
                if (controller.text.trim().isEmpty)
                  const Text('Start typing to search.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12))
                else if (results.isEmpty)
                  const Text('No matching cells.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12))
                else
                  ...results.map((c) {
                    final color = _statusColors[c.status] ?? BPColors.yellow;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(c.type == 'core' ? Icons.crop_square : Icons.circle, color: color, size: 18),
                      title: Text(c.ownerName ?? c.displayId, style: const TextStyle(fontSize: 13, color: BPColors.textPrimary)),
                      subtitle: Text(c.displayId, style: const TextStyle(color: BPColors.textSecondary, fontSize: 11)),
                      trailing: Text(c.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedIndex = _cells.indexOf(c));
                      },
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showJumpSheet() {
    void jumpToNext(String status) {
      Navigator.pop(context);
      final match = _cells.where((c) => c.status == status);
      if (match.isNotEmpty) {
        setState(() => _selectedIndex = _cells.indexOf(match.first));
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: BPColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            const Text('JUMP TO', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text('Find a cell by status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ...['empty', 'locked', 'sealed', 'open'].map((status) {
              final color = _statusColors[status] ?? BPColors.yellow;
              final count = _cells.where((c) => c.status == status).length;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.circle, color: color, size: 14),
                title: Text('Next ${status.toUpperCase()} cell', style: const TextStyle(fontSize: 13, color: BPColors.textPrimary, fontWeight: FontWeight.w700)),
                trailing: Text('$count', style: const TextStyle(color: BPColors.textSecondary, fontSize: 12)),
                onTap: count == 0 ? null : () => jumpToNext(status),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final counts = _statusCounts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          _legendButton('all', 'ALL', _cells.length, BPColors.yellow),
          const SizedBox(width: 6),
          _legendButton('empty', 'EMPTY', counts['empty']!, _statusColors['empty']!),
          const SizedBox(width: 6),
          _legendButton('locked', 'LOCKED', counts['locked']!, _statusColors['locked']!),
          const SizedBox(width: 6),
          _legendButton('sealed', 'SEALED', counts['sealed']!, _statusColors['sealed']!),
          const SizedBox(width: 6),
          _legendButton('open', 'OPEN', counts['open']!, _statusColors['open']!),
        ],
      ),
    );
  }

  Widget _legendButton(String key, String label, int count, Color color) {
    final active = _statusFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.15) : BPColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: active ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Text('$count', style: const TextStyle(color: BPColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: BPColors.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);
}

const _vaultSubdivisions = 4; // -> exactly 162 tiles (12 pentagons + 150 hexagons), matching the 162 cells exactly

/// Maps a cell to its tile's center point — core cells (12 of them) to
/// the sphere's 12 natural pentagon tiles, standard cells (150) to its
/// 150 hexagon tiles. Shared by the painter and tap hit-testing so
/// both agree on where each cell actually sits.
_Vec3 _cellPosition(VaultCell cell) {
  final tiles = Geosphere.build(subdivisions: _vaultSubdivisions);
  if (cell.type == 'core') {
    final pentagons = tiles.where((t) => t.corners.length == 5).toList();
    final c = pentagons[(cell.number - 1) % pentagons.length].center;
    return _Vec3(c.x, c.y, c.z);
  } else {
    final hexagons = tiles.where((t) => t.corners.length == 6).toList();
    final c = hexagons[(cell.number - 1) % hexagons.length].center;
    return _Vec3(c.x, c.y, c.z);
  }
}

_Vec3 _rotate(_Vec3 p, double rotX, double rotY) {
  final cosY = math.cos(rotY), sinY = math.sin(rotY);
  final x1 = p.x * cosY - p.z * sinY;
  final z1 = p.x * sinY + p.z * cosY;

  final cosX = math.cos(rotX), sinX = math.sin(rotX);
  final y2 = p.y * cosX - z1 * sinX;
  final z2 = p.y * sinX + z1 * cosX;

  return _Vec3(x1, y2, z2);
}

_Vec3 _cross(_Vec3 a, _Vec3 b) => _Vec3(
      a.y * b.z - a.z * b.y,
      a.z * b.x - a.x * b.z,
      a.x * b.y - a.y * b.x,
    );

/// The two unit tangent directions ("east"/"north") of the sphere's
/// surface at [normal] — used to glue a flat number onto a curved tile
/// so it follows the tile's own skew/foreshortening as the sphere turns,
/// instead of staying flat/horizontal like a label floating above it.
(_Vec3 east, _Vec3 north) _tangentBasis(_Vec3 normal) {
  const worldUp = _Vec3(0, 1, 0);
  var e = _cross(worldUp, normal);
  final eLen = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  e = eLen < 1e-6 ? const _Vec3(1, 0, 0) : _Vec3(e.x / eLen, e.y / eLen, e.z / eLen);
  final n = _cross(normal, e); // already unit length: cross of two orthonormal unit vectors
  return (e, n);
}

class _VaultSpherePainter extends CustomPainter {
  final List<VaultCell> cells;
  final int totalCells;
  final double rotationX, rotationY, scale;
  final VaultCell? selectedCell;
  final Map<String, Color> statusColors;

  _VaultSpherePainter({
    required this.cells,
    required this.totalCells,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.selectedCell,
    required this.statusColors,
  });

  // Cell numbers are "stamped" flat onto each tile rather than kept
  // upright/counter-rotated as the sphere turns. Each digit's TextPainter
  // is laid out once (expensive step) and cached here; every frame we
  // only translate+scale the cached painter to the tile's current screen
  // position (cheap), instead of re-running text layout per tile per
  // frame during drag/rotation.
  static final Map<int, TextPainter> _numberCache = {};

  static TextPainter _numberPainter(int number) {
    return _numberCache.putIfAbsent(number, () {
      final tp = TextPainter(
        text: TextSpan(
          text: '$number',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      return tp;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.46 * scale;

    final tiles = Geosphere.build(subdivisions: _vaultSubdivisions);
    final pentagons = tiles.where((t) => t.corners.length == 5).toList();
    final hexagons = tiles.where((t) => t.corners.length == 6).toList();

    final cellByCore = <int, VaultCell>{};
    final cellByStandard = <int, VaultCell>{};
    for (final cell in cells) {
      if (cell.type == 'core') {
        cellByCore[cell.number - 1] = cell;
      } else {
        cellByStandard[cell.number - 1] = cell;
      }
    }

    final entries = <MapEntry<GeoTile, VaultCell?>>[];
    for (int i = 0; i < pentagons.length; i++) {
      entries.add(MapEntry(pentagons[i], cellByCore[i]));
    }
    for (int i = 0; i < hexagons.length; i++) {
      entries.add(MapEntry(hexagons[i], cellByStandard[i]));
    }

    final rotated = entries.map((e) {
      final corners = e.key.corners.map((c) => _rotate(_Vec3(c.x, c.y, c.z), rotationX, rotationY)).toList();
      return MapEntry(e, corners);
    }).toList();

    rotated.sort((a, b) {
      final az = a.value.fold<double>(0, (s, v) => s + v.z) / a.value.length;
      final bz = b.value.fold<double>(0, (s, v) => s + v.z) / b.value.length;
      return az.compareTo(bz);
    });

    for (final entry in rotated) {
      final corners = entry.value;
      final cell = entry.key.value;
      final avgZ = corners.fold<double>(0, (s, v) => s + v.z) / corners.length;
      if (avgZ < -0.15) continue;

      final depthFactor = ((avgZ + 1) / 2).clamp(0.0, 1.0);
      final color = cell != null ? (statusColors[cell.status] ?? Colors.grey) : const Color(0xFF2A3050);
      final isSelected = cell != null && selectedCell != null && selectedCell!.type == cell.type && selectedCell!.number == cell.number;

      // Project corners to screen space first, then shrink each tile toward
      // its own centroid so a visible dark gap appears between neighboring
      // cells (matching the reference look) instead of edges touching.
      final screenPoints = corners
          .map((v) => Offset(center.dx + v.x * radius, center.dy + v.y * radius))
          .toList();
      final tileCenter = screenPoints.fold<Offset>(
            Offset.zero,
            (sum, p) => sum + p,
          ) /
          screenPoints.length.toDouble();

      const _tileShrink = 0.86; // <1.0 pulls corners toward centroid -> gap between cells
      final shrunkPoints = screenPoints
          .map((p) => tileCenter + (p - tileCenter) * _tileShrink)
          .toList();

      final path = Path();
      for (int i = 0; i < shrunkPoints.length; i++) {
        final p = shrunkPoints[i];
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(cell != null ? (0.35 + depthFactor * 0.55) : (0.12 + depthFactor * 0.18))
          ..style = PaintingStyle.fill,
      );

      // Neon-ish glow on the tile edge instead of a flat black outline —
      // NOT using MaskFilter.blur here: blurring a path stroke is
      // expensive to rasterize, and doing it per-tile (up to hundreds of
      // times) every frame during drag is what was causing the sphere to
      // stutter. This fakes the glow cheaply instead: a slightly wider,
      // more transparent solid stroke underneath a crisp bright one — no
      // blur filter, so no per-tile rasterization cost.
      if (cell != null) {
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withOpacity(0.35 * depthFactor)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withOpacity(0.9 * depthFactor + 0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.black.withOpacity(0.25 * depthFactor)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6,
        );
      }

      if (isSelected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }

      // Stamp the cell number onto the tile, glued to the sphere's actual
      // curvature at this point (not kept flat/horizontal) — the number
      // is skewed/foreshortened along the tile's own east/north tangent
      // directions, so it visually lies on the curved surface instead of
      // floating above it. This means it can appear upside-down or
      // mirrored at extreme viewing angles, by design.
      if (cell != null && depthFactor > 0.35) {
        final tileGeo = entry.key.key;
        final normal = _Vec3(tileGeo.center.x, tileGeo.center.y, tileGeo.center.z);
        final (east, north) = _tangentBasis(normal);
        final eastRotated = _rotate(east, rotationX, rotationY);
        final northRotated = _rotate(north, rotationX, rotationY);

        final avgTileRadius =
            shrunkPoints.map((p) => (p - tileCenter).distance).reduce((a, b) => a + b) / shrunkPoints.length;
        final halfSize = avgTileRadius * 0.40;

        final tp = _numberPainter(cell.number);
        canvas.save();
        canvas.translate(tileCenter.dx, tileCenter.dy);
        canvas.transform(Float64List.fromList([
          eastRotated.x * halfSize, eastRotated.y * halfSize, 0, 0,
          northRotated.x * halfSize, northRotated.y * halfSize, 0, 0,
          0, 0, 1, 0,
          0, 0, 0, 1,
        ]));
        canvas.scale(1 / (tp.width / 2), 1 / (tp.height / 2));
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VaultSpherePainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedCell != selectedCell ||
        oldDelegate.cells.length != cells.length;
  }
}
