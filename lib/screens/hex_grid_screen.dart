import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/benchpad_api.dart';
import '../services/capsule_store.dart';
import '../theme/benchpad_dark_theme.dart';
import '../widgets/home_back_leading.dart';
import '../widgets/neon_hex_reel.dart';
import 'broadcast_calendar_screen.dart';
import 'capsule_creator_screen.dart';
import 'profile_screen.dart';

/// Time Capsule 3 — a neon honeycomb reel wall of 48 reservable cells,
/// sharing the exact same reservation model as Time Capsule 1 (Vault)
/// and Time Capsule 2 (Memory): empty -> locked -> sealed -> open, real
/// data from the server (sphere: "hex"), same tap-to-reserve flow via
/// CapsuleCreatorScreen. Only the visual presentation (a scrolling
/// honeycomb wall instead of a 3D sphere) differs.
class HexGridScreen extends StatefulWidget {
  const HexGridScreen({super.key});

  @override
  State<HexGridScreen> createState() => _HexGridScreenState();
}

class _HexGridScreenState extends State<HexGridScreen> with SingleTickerProviderStateMixin {
  static const _hexSize = 46.0; // +15% (was 40.0)
  static const _tileCount = 48;

  final _api = BenchpadApi();
  List<HexCellData> _cells = [];
  bool _loading = true;
  String? _error;
  bool _isOwner = false;

  double _scrollX = 0;
  double _flingVelocity = 0; // px per tick, decays via friction
  bool _dragging = false;
  bool _spinning = true;
  Offset? _lastPanPos;
  HexCellData? _selectedCell;
  HexCellStatus? _statusFilter;
  int _rows = 3; // recomputed by LayoutBuilder each build
  double _cylinderRadius = 300; // recomputed by LayoutBuilder each build

  late final AnimationController _driver;

  static const _autoScrollSpeed = 0.25; // px per tick — halved (was 0.5)
  static const _friction = 0.93;

  @override
  void initState() {
    super.initState();
    _driver = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(() {
        setState(() {
          if (_flingVelocity.abs() > 0.03) {
            _scrollX -= _flingVelocity;
            _flingVelocity *= _friction;
          } else {
            _flingVelocity = 0;
            if (_spinning && !_dragging) _scrollX += _autoScrollSpeed;
          }
        });
      })
      ..repeat();
    _loadCells();
    _api.getOwnerStatus().then((owner) {
      if (mounted) setState(() => _isOwner = owner);
    });
  }

  @override
  void dispose() {
    _driver.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadCells() async {
    try {
      final real = await _api.getSphereCapsules('hex');
      final byNumber = <int, Map<String, dynamic>>{};
      for (final c in real) {
        final n = (c['cellNumber'] as num?)?.toInt();
        if (n != null) byNumber[n] = c;
      }

      final cells = List<HexCellData>.generate(_tileCount, (i) {
        final number = i + 1;
        final r = byNumber[number];
        if (r == null) {
          return HexCellData(id: 'hex-$number', label: '$number', status: HexCellStatus.empty, number: number);
        }
        final statusStr = (r['status'] as String?) ?? 'empty';
        final status = HexCellStatus.values.firstWhere((s) => s.name == statusStr, orElse: () => HexCellStatus.empty);
        final isPublic = r['visibility'] == 'Public' || r['visibility'] == 'public';
        return HexCellData(
          id: 'hex-$number',
          label: '$number',
          status: status,
          number: number,
          ownerName: isPublic ? ((r['ownerName'] as String?) ?? '') : '',
          ownerCountry: isPublic ? ((r['ownerCountry'] as String?) ?? '') : '',
          message: status == HexCellStatus.open ? ((r['message'] as String?) ?? '') : '',
          openingDate: (r['openingDate'] as String?) ?? '',
          visibility: (r['visibility'] as String?) ?? 'Private',
        );
      });

      if (!mounted) return;
      setState(() { _cells = cells; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  int _rowsThatFit(double height) {
    final rowSpacing = _hexSize * 1.7320508; // sqrt(3)
    // Odd columns are offset down by half a row (the honeycomb stagger),
    // so they need an extra half-row of headroom — without reserving it
    // here, those columns' bottom row gets clipped by the container edge.
    final usable = height - rowSpacing / 2;
    final fit = (usable / rowSpacing).floor();
    return fit < 1 ? 1 : fit;
  }

  void _handleTap(Offset local, Size size) {
    if (_cells.isEmpty) return;
    final geo = HexReelGeometry(_hexSize, _rows, _cylinderRadius);
    final center = Offset(size.width / 2, size.height / 2);
    HexCellData? closest;
    double closestDist = _hexSize * 0.9;

    final firstCol = geo.firstColFor(_scrollX);
    final lastCol = geo.lastColFor(_scrollX);
    for (int col = firstCol; col <= lastCol; col++) {
      for (int row = 0; row < _rows; row++) {
        final proj = geo.project(col, row, center, _scrollX);
        if (proj == null) continue;
        final dist = (proj.pos - local).distance;
        if (dist < closestDist) {
          closestDist = dist;
          closest = _cells[hexCellIndexAt(col, row, _rows, _cells.length)];
        }
      }
    }
    if (closest != null) setState(() => _selectedCell = closest);
  }

  void _jumpToLabel(String label) {
    if (_cells.isEmpty) return;
    final targetIndex = _cells.indexWhere((c) => c.label == label);
    if (targetIndex == -1) return;
    for (int col = 0; col < _cells.length; col++) {
      for (int row = 0; row < _rows; row++) {
        if (hexCellIndexAt(col, row, _rows, _cells.length) == targetIndex) {
          setState(() {
            _scrollX = col * HexReelGeometry(_hexSize, _rows, _cylinderRadius).colSpacing;
            _flingVelocity = 0;
            _selectedCell = _cells[targetIndex];
          });
          return;
        }
      }
    }
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
        textTheme: Theme.of(context).textTheme.apply(bodyColor: BPColors.textPrimary, displayColor: BPColors.textPrimary),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: BPColors.yellow, foregroundColor: BPColors.bg, disabledBackgroundColor: BPColors.border, disabledForegroundColor: BPColors.textSecondary),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, disabledForegroundColor: BPColors.textSecondary, side: const BorderSide(color: BPColors.yellow)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: BPColors.yellow),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BPColors.card,
          labelStyle: const TextStyle(color: BPColors.textSecondary),
          floatingLabelStyle: const TextStyle(color: BPColors.yellow),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.yellow, width: 1.5)),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(builder: backLeading),
          leadingWidth: 64,
          centerTitle: true,
          title: const Text('Time Capsule 3'),
          actions: [
            IconButton(
              tooltip: 'My Capsules',
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            IconButton(
              tooltip: _spinning ? 'Pause scrolling' : 'Resume scrolling',
              icon: Icon(_spinning ? Icons.pause : Icons.play_arrow),
              onPressed: () => setState(() => _spinning = !_spinning),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: BPColors.yellow))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Could not load Time Capsule 3: $_error', style: const TextStyle(color: BPColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, side: const BorderSide(color: BPColors.yellow)),
                            onPressed: () => setState(() { _loading = true; _error = null; _loadCells(); }),
                            child: const Text('RETRY'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _buildStatsBar(),
                      Expanded(child: _buildReelStage()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _buildSelectedCard()),
                            const SizedBox(width: 8),
                            _roundIconButton(icon: Icons.search, tooltip: 'Search cells', onTap: _showSearchSheet),
                            const SizedBox(width: 8),
                            _roundIconButton(icon: Icons.tune, tooltip: 'Jump to', onTap: _showJumpSheet),
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
    final open = _cells.where((c) => c.status == HexCellStatus.empty).length;
    final closed = _cells.length - open;
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
          _statItem('${_cells.length}', 'CELLS'),
          _statItem('$open', 'EMPTY'),
          _statItem('$closed', 'RESERVED'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BPColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: BPColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ],
      ),
    );
  }

  Widget _buildReelStage() {
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
        builder: (context, constraints) {
          _rows = _rowsThatFit(constraints.maxHeight);
          _cylinderRadius = constraints.maxWidth * 0.6; // smaller radius = tighter curl, more pronounced (was 0.85)
          return GestureDetector(
            onPanStart: (d) {
              _dragging = true;
              _lastPanPos = d.globalPosition;
            },
            onPanUpdate: (d) {
              final last = _lastPanPos;
              if (last == null) return;
              setState(() => _scrollX -= (d.globalPosition.dx - last.dx));
              _lastPanPos = d.globalPosition;
            },
            onPanEnd: (d) {
              _dragging = false;
              _lastPanPos = null;
              _flingVelocity = d.velocity.pixelsPerSecond.dx / 60;
            },
            onTapUp: (d) => _handleTap(d.localPosition, constraints.biggest),
            child: CustomPaint(
              size: Size.infinite,
              painter: HexReelPainter(cells: _cells, scrollX: _scrollX, hexSize: _hexSize, rows: _rows, cylinderRadius: _cylinderRadius, selectedId: _selectedCell?.id, filterStatus: _statusFilter),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedCard() {
    final cell = _selectedCell;
    final color = cell != null ? hexStatusColor(cell.status) : BPColors.textSecondary;
    final hasOwner = cell != null && cell.ownerName.isNotEmpty;
    // Both the "nothing selected" and "cell selected" states share the
    // exact same outer shape/padding/icon-slot layout — only the content
    // inside changes. This keeps the card's height constant, so the
    // stage above it (and the search/tune buttons beside it) never
    // resize or shift depending on whether a cell is selected.
    return GestureDetector(
      onTap: cell == null ? null : () => _openCell(cell),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BPColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(cell != null ? 0.4 : 0.2)),
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15), border: Border.all(color: color)),
              child: Center(
                child: cell != null
                    ? Text(cell.label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13))
                    : const Icon(Icons.touch_app_outlined, size: 20, color: BPColors.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cell != null
                    ? [
                        Text(cell.status.name.toUpperCase(), style: const TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(hasOwner ? cell.ownerName : 'Cell ${cell.label}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]
                    : const [
                        Text('NO CELL SELECTED', style: TextStyle(color: BPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Tap a cell to open it', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BPColors.textSecondary)),
                      ],
              ),
            ),
            if (cell == null)
              const SizedBox.shrink()
            else if (cell.status != HexCellStatus.empty)
              Icon(Icons.chevron_right, color: color)
            else if (_isOwner)
              IconButton(
                tooltip: 'Generate reservation code',
                icon: const Icon(Icons.qr_code, color: BPColors.yellow),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _issueReservation(cell),
              )
            else
              const Icon(Icons.chevron_right, color: BPColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Owner-only: pre-reserves this specific empty cell and returns an
  /// access key up front, before anyone fills anything in — for handing
  /// a *specific* cell to a *specific* person (as opposed to the open
  /// self-serve claim, which anyone reaches by tapping an empty cell
  /// and hands out a random key only once they've already filled in the
  /// form). Same mechanism as Time Capsule 2's owner tool.
  Future<void> _issueReservation(HexCellData cell) async {
    try {
      final result = await _api.saveCapsule(
        type: 'hex',
        number: cell.number,
        sphere: 'hex',
        ownerName: '',
        ownerCountry: '',
        message: '',
        openingDateIso: DateTime.now().add(const Duration(days: 365 * 3)).toIso8601String(),
        visibility: 'public',
      );
      final issuedKey = result['issuedAccessKey'] as String?;
      if (!mounted) return;
      if (issuedKey == null || issuedKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This cell already has a reservation code issued.')));
        return;
      }
      _loadCells();
      _showReservationCodeSheet(cell, issuedKey);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate a code: $e')));
    }
  }

  void _showReservationCodeSheet(HexCellData cell, String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BPColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('RESERVATION CODE', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Cell #${cell.number}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: BPColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Give this to one specific person. It lets them claim exactly this cell — nobody else can use it once they do.',
              style: TextStyle(color: BPColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: QrImageView(data: code, size: 180, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 16),
            SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1, color: BPColors.textPrimary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, side: const BorderSide(color: BPColors.yellow)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Code copied.')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('COPY'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, side: const BorderSide(color: BPColors.yellow)),
                    onPressed: () => Share.share('Your BenchPad World Time Capsule 3 cell #${cell.number} — claim it with this code in the app under "My Capsule": $code'),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('SHARE'),
                  ),
                ),
              ],
            ),
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

  Widget _buildLegend() {
    final counts = {
      for (final s in HexCellStatus.values) s: _cells.where((c) => c.status == s).length,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          _legendButton(null, 'ALL', _cells.length, BPColors.yellow),
          for (final s in HexCellStatus.values) ...[
            const SizedBox(width: 6),
            _legendButton(s, s.name.toUpperCase(), counts[s]!, hexStatusColor(s)),
          ],
        ],
      ),
    );
  }

  Widget _legendButton(HexCellStatus? status, String label, int count, Color color) {
    final active = _statusFilter == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = status),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
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

  void _showSearchSheet() {
    final controller = TextEditingController();
    List<HexCellData> results = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: BPColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void runSearch(String query) {
            final q = query.trim();
            setSheetState(() => results = q.isEmpty ? [] : _cells.where((c) => c.label.contains(q)).toList());
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
                TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Cell number'), onChanged: runSearch),
                const SizedBox(height: 16),
                if (controller.text.trim().isEmpty)
                  const Text('Start typing to search.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12))
                else if (results.isEmpty)
                  const Text('No matching cells.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12))
                else
                  ...results.map((c) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Cell ${c.label}', style: const TextStyle(fontSize: 13, color: BPColors.textPrimary)),
                        trailing: Text(c.status.name.toUpperCase(), style: TextStyle(color: hexStatusColor(c.status), fontSize: 10, fontWeight: FontWeight.w700)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _jumpToLabel(c.label);
                        },
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showJumpSheet() {
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
            const Text('JUMP TO', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const Text('Find a cell by status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...HexCellStatus.values.map((status) {
              final first = _cells.firstWhere((c) => c.status == status, orElse: () => _cells.first);
              return ListTile(
                title: Text('Next ${status.name.toUpperCase()} cell', style: const TextStyle(fontSize: 13, color: BPColors.textPrimary, fontWeight: FontWeight.w700)),
                trailing: Text('${_cells.where((c) => c.status == status).length}', style: const TextStyle(color: BPColors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _jumpToLabel(first.label);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _openCell(HexCellData cell) async {
    if (cell.status == HexCellStatus.empty || cell.status == HexCellStatus.locked) {
      final ownerKey = await CapsuleStore.findKey('hex', 'hex', cell.number);
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: 'hex', number: cell.number, sphere: 'hex', ownerKey: ownerKey)),
      );
      if (result == true) _loadCells();
    } else {
      _showCellDetail(cell);
    }
  }

  void _showCellDetail(HexCellData cell) {
    final color = hexStatusColor(cell.status);
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
            Text('BP-HEX-${cell.number.toString().padLeft(6, '0')}', style: const TextStyle(color: BPColors.yellow, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(cell.ownerName.isNotEmpty ? cell.ownerName : 'Sealed capsule', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BPColors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
              child: Text(cell.status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            if (cell.status == HexCellStatus.open && cell.message.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('"${cell.message}"', style: const TextStyle(fontSize: 14, height: 1.4, fontStyle: FontStyle.italic, color: BPColors.textPrimary)),
            ] else if (cell.status == HexCellStatus.sealed) ...[
              const SizedBox(height: 12),
              Text(
                'This capsule is sealed. Its message will be revealed on ${cell.openingDate.isNotEmpty ? cell.openingDate : "its opening date"}.',
                style: const TextStyle(color: BPColors.textSecondary, fontSize: 12),
              ),
            ],
            if (cell.ownerCountry.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('From ${cell.ownerCountry}', style: const TextStyle(color: BPColors.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, side: const BorderSide(color: BPColors.yellow)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BroadcastCalendarScreen(
                  sphere: 'hex',
                  capsuleType: 'hex',
                  capsuleNumber: cell.number,
                  ownerName: cell.ownerName,
                  ownerCountry: cell.ownerCountry,
                  contentReady: cell.message.isNotEmpty,
                )));
              },
              child: const Text('SCHEDULE BROADCAST'),
            ),
          ],
        ),
      ),
    );
  }
}
