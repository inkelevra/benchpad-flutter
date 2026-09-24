import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/capsule_profile.dart';
import '../services/benchpad_api.dart';
import '../services/capsule_store.dart';
import '../services/geosphere.dart';
import '../theme/benchpad_dark_theme.dart';
import '../widgets/home_back_leading.dart';
import 'capsule_creator_screen.dart';
import 'broadcast_calendar_screen.dart';
import 'profile_screen.dart';
/// Time Capsule 2 — interactive 3D geosphere of 492 hexagon/pentagon
/// capsule tiles, ported from benchpad-memory-orbit.html's canvas-based
/// Living Sphere.
///
/// Covers: sphere layout, drag-to-rotate, pinch-to-zoom, tap-to-select,
/// status legend/filter, stats bar, selected card, country search,
/// discovery menu (random/recent/next-opening/opening-today), recently-
/// viewed history, and share/copy-link. Not covered: a rendered QR code
/// image (Copy Link + native share cover the same end goal without it).
///
/// Tile geometry: a real hexasphere (icosahedron subdivided + dual
/// mesh, see services/geosphere.dart — same technique as hexasphere.js)
/// rather than scattered points. Tile count follows 10*n*n+2 for
/// subdivision level n, so exact round numbers aren't all reachable —
/// 492 (not 500) is the closest real value, agreed with the user.
class MemorySphereScreen extends StatefulWidget {
  const MemorySphereScreen({super.key});

  @override
  State<MemorySphereScreen> createState() => _MemorySphereScreenState();
}

class _MemorySphereScreenState extends State<MemorySphereScreen> with SingleTickerProviderStateMixin {
  final _api = BenchpadApi();
  List<CapsuleProfile> _profiles = [];
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
  bool _isOwner = false;

  late final AnimationController _spinController;

  static const _statusColors = {
    'empty': Color(0xFF75E7FF),
    'locked': Color(0xFFFFD84D),
    'sealed': Color(0xFFFF4D68),
    'open': Color(0xFF68F56A),
  };

  // Fixed reference date matching the PWA's demo data anchor, so
  // "opening today" / "next opening" line up with the same seeded
  // dataset instead of drifting against the real device clock.
  static final DateTime _referenceToday = DateTime.parse('2026-07-17');

  static const _historyKey = 'benchpad_memory_sphere_recently_viewed';
  List<int> _recentlyViewed = [];

  Future<void> _rememberViewed(int index) async {
    setState(() {
      _recentlyViewed = [index, ..._recentlyViewed.where((i) => i != index)].take(8).toList();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _recentlyViewed.map((e) => e.toString()).toList());
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_historyKey) ?? [];
    setState(() => _recentlyViewed = saved.map(int.parse).toList());
  }

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..addListener(() {
        if (_spinning) {
          setState(() => _rotationY += 0.0006);
        }
      })
      ..repeat();
    _loadProfiles();
    _loadHistory();
    _api.getOwnerStatus().then((owner) {
      if (mounted) setState(() => _isOwner = owner);
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _api.dispose();
    super.dispose();
  }

  static const _tileCount = 492; // matches the real hexasphere geometry — see class doc comment

  // Small, practical country-name -> flag-emoji lookup for the real
  // capsule data (built from ISO 3166 regional-indicator pairs) —
  // covers common cases; unmapped countries fall back to a plain
  // globe rather than a wrong flag.
  static const Map<String, String> _countryFlags = {
    'Netherlands': '🇳🇱', 'Belgium': '🇧🇪', 'Germany': '🇩🇪', 'France': '🇫🇷',
    'United Kingdom': '🇬🇧', 'Ireland': '🇮🇪', 'Spain': '🇪🇸', 'Portugal': '🇵🇹',
    'Italy': '🇮🇹', 'Switzerland': '🇨🇭', 'Austria': '🇦🇹', 'Denmark': '🇩🇰',
    'Sweden': '🇸🇪', 'Norway': '🇳🇴', 'Finland': '🇫🇮', 'Poland': '🇵🇱',
    'United States': '🇺🇸', 'Canada': '🇨🇦', 'Mexico': '🇲🇽', 'Brazil': '🇧🇷',
    'Australia': '🇦🇺', 'New Zealand': '🇳🇿', 'Japan': '🇯🇵', 'South Korea': '🇰🇷',
    'India': '🇮🇳', 'China': '🇨🇳', 'Turkey': '🇹🇷', 'Greece': '🇬🇷',
    'South Africa': '🇿🇦', 'Nigeria': '🇳🇬', 'Egypt': '🇪🇬', 'Morocco': '🇲🇦',
  };

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _loadProfiles() async {
    try {
      final real = await _api.getSphereCapsules('orbit');

      final byIndex = <int, Map<String, dynamic>>{};
      for (final c in real) {
        final n = (c['cellNumber'] as num?)?.toInt();
        if (n == null) continue;
        final idx = n - 1;
        if (idx >= 0 && idx < _tileCount) byIndex[idx] = c;
      }

      final list = List<CapsuleProfile>.generate(_tileCount, (i) {
        final r = byIndex[i];
        if (r == null) {
          return CapsuleProfile(
            index: i,
            privateNumber: i + 1,
            flag: '',
            country: '',
            name: '',
            worldId: 'BW-${(i + 1).toString().padLeft(6, '0')}',
            capsuleId: '',
            memberSince: '',
            openingDate: '',
            status: 'empty',
            message: '',
            avatarHue: (i * 47) % 360,
            initials: '',
            createdVia: '',
            openedOn: '',
            visibility: 'Private',
          );
        }
        final isPublic = r['visibility'] == 'Public';
        final ownerName = (r['ownerName'] as String?) ?? '';
        final ownerCountry = (r['ownerCountry'] as String?) ?? '';
        // Only show the real name/country for capsules the owner
        // explicitly made Public — Private ones stay anonymous even
        // though they're real (not fabricated) entries.
        final name = isPublic ? ownerName : '';
        final country = isPublic ? ownerCountry : '';
        return CapsuleProfile(
          index: i,
          privateNumber: i + 1,
          flag: isPublic ? (_countryFlags[country] ?? '🌍') : '',
          country: country,
          name: name,
          worldId: 'BW-${(i + 1).toString().padLeft(6, '0')}',
          capsuleId: 'BP-MO-${(i + 1).toString().padLeft(6, '0')}',
          memberSince: (r['createdAt'] as String?) ?? '',
          openingDate: (r['openingDate'] as String?) ?? '',
          status: (r['status'] as String?) ?? 'empty',
          message: (r['status'] == 'open') ? ((r['message'] as String?) ?? '') : '',
          avatarHue: (i * 47) % 360,
          initials: isPublic ? _initialsOf(ownerName) : '',
          createdVia: '',
          openedOn: '',
          visibility: (r['visibility'] as String?) ?? 'Private',
        );
      });

      if (mounted) {
        setState(() {
          _profiles = list;
          _loading = false;
          _selectedIndex ??= _defaultSelection(list);
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load capsules: $e'; _loading = false; });
    }
  }

  /// Picks a sensible capsule to show by default so the info card is
  /// never blank on first open — matches the PWA reference, which
  /// always has something populated rather than an empty prompt.
  /// Prefers an 'open' one (most interesting to land on), falls back
  /// to any non-empty capsule, and only returns null if the sphere is
  /// entirely empty.
  int? _defaultSelection(List<CapsuleProfile> list) {
    for (final p in list) {
      if (p.status == 'open') return p.index;
    }
    for (final p in list) {
      if (p.status != 'empty') return p.index;
    }
    return null;
  }

  List<CapsuleProfile> get _visibleProfiles {
    if (_statusFilter == 'all') return _profiles;
    return _profiles.where((p) => p.status == _statusFilter).toList();
  }

  Map<String, int> get _statusCounts {
    final counts = {'empty': 0, 'locked': 0, 'sealed': 0, 'open': 0};
    for (final p in _profiles) {
      counts[p.status] = (counts[p.status] ?? 0) + 1;
    }
    return counts;
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
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(builder: backLeading),
          leadingWidth: 64,
          centerTitle: true,
          title: const Text('Time Capsule 2'),
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
                            _roundIconButton(icon: Icons.search, tooltip: 'Search countries', onTap: _loading ? null : _showCountrySearchSheet),
                            const SizedBox(width: 8),
                            _roundIconButton(icon: Icons.tune, tooltip: 'Discover', onTap: _loading ? null : _showDiscoverySheet),
                          ],
                        ),
                      ),
                      _buildLegend(),
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

  Widget _buildStatsBar() {
    final today = _referenceToday.toIso8601String().substring(0, 10);
    final openingToday = _profiles.where((p) => p.openingDate.startsWith(today)).toList();
    return GestureDetector(
      onTap: openingToday.isEmpty ? null : () => _flyTo(openingToday.first.index),
      child: Container(
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
            _statItem('${openingToday.length}', 'OPENING TODAY'),
          ],
        ),
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
          painter: _SpherePainter(
            profiles: _visibleProfiles,
            rotationX: _rotationX,
            rotationY: _rotationY,
            scale: _scale,
            selectedIndex: _selectedIndex,
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
    CapsuleProfile? closest;
    double closestDist = 30;
    int? closestGlobalIndex;

    final visible = _visibleProfiles;
    for (int i = 0; i < visible.length; i++) {
      final p = _tileCenter(visible[i].index);
      final rotated = _rotate(p, _rotationX, _rotationY);
      if (rotated.z < -0.1) continue;
      final screen = Offset(center.dx + rotated.x * radius, center.dy + rotated.y * radius);
      final dist = (screen - local).distance;
      if (dist < closestDist) {
        closestDist = dist;
        closest = visible[i];
        closestGlobalIndex = visible[i].index;
      }
    }

    if (closest != null) {
      setState(() => _selectedIndex = closestGlobalIndex);
    }
  }

  /// Opens an empty position's reservation flow (mirrors Time Capsule 1's
  /// _openCell) — claiming here works the same way as Vault: fill in
  /// the form, get an access key back. To instead hand a *specific*
  /// position to a specific person, use "Generate reservation code" on
  /// that position (owner-only) — that pre-creates the reservation and
  /// issues the key up front, before anyone fills anything in.
  Future<void> _openPosition(CapsuleProfile p) async {
    final ownerKey = await CapsuleStore.findKey('orbit', 'orb', p.privateNumber);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: 'orb', number: p.privateNumber, sphere: 'orbit', ownerKey: ownerKey)),
    );
    if (result == true) _loadProfiles();
  }

  /// Trims a possibly-full ISO datetime down to just the date part
  /// ("2029-06-15T00:00:00.000Z" -> "2029-06-15") — the raw string was
  /// long enough to wrap the card's third line onto a second line,
  /// making the whole card visibly taller than Time Capsule 1's.
  String _shortDate(String iso) {
    final t = iso.indexOf('T');
    return t > 0 ? iso.substring(0, t) : iso;
  }

  Widget _buildSelectedCard() {
    // Always the full card shape/size, selected or not (matches Hex
    // Grid's pattern) — a narrower text-only placeholder here made the
    // card visibly narrower whenever nothing was auto-selected yet.
    final p = _selectedIndex != null && _selectedIndex! < _profiles.length ? _profiles[_selectedIndex!] : null;
    final isEmptyPosition = p != null && p.status == 'empty';
    // Both "empty" (never touched) and "locked" (reserved, still being
    // filled in — not sealed yet) need to reopen the actual form so the
    // person can finish it. Only "sealed"/"open" are read-only and show
    // the identity sheet instead. Vault Sphere's equivalent tap handler
    // already does this; this one didn't, so a locked-but-unsealed
    // position here had no way back into its own photo/message step.
    final canOpenForm = p != null && (p.status == 'empty' || p.status == 'locked');
    final color = p != null ? (_statusColors[p.status] ?? BPColors.yellow) : BPColors.textSecondary;
    return GestureDetector(
      onTap: p == null ? null : (canOpenForm ? () => _openPosition(p) : () => _showIdentitySheet(p)),
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
                shape: BoxShape.circle,
                color: p == null || isEmptyPosition ? BPColors.bg : HSLColor.fromAHSL(1, p.avatarHue, 0.6, 0.4).toColor(),
                border: p == null || isEmptyPosition ? Border.all(color: BPColors.border) : null,
              ),
              alignment: Alignment.center,
              child: p == null
                  ? const Icon(Icons.touch_app_outlined, size: 20, color: BPColors.textSecondary)
                  : isEmptyPosition
                      ? const Icon(Icons.person_outline, size: 20, color: BPColors.textSecondary)
                      : Text(p.initials, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: p == null
                    ? const [
                        Text('NO POSITION SELECTED', style: TextStyle(color: BPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Tap a point to open it', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BPColors.textSecondary)),
                      ]
                    : isEmptyPosition
                        ? [
                            Text('Position #${p.privateNumber}', style: const TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            const Text('Reserved', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BPColors.textPrimary)),
                            const SizedBox(height: 2),
                            const Text('Not yet claimed', style: TextStyle(color: BPColors.textSecondary, fontSize: 11)),
                          ]
                        : [
                            Text('${p.flag} ${p.country}', style: const TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(p.name.isEmpty ? 'Private' : p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BPColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              p.status == 'open' ? 'Opened ${_shortDate(p.openingDate)}' : 'Opens ${_shortDate(p.openingDate)}',
                              style: const TextStyle(color: BPColors.textSecondary, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
              ),
            ),
            if (p == null)
              const SizedBox.shrink()
            else if (!isEmptyPosition)
              Icon(Icons.chevron_right, color: color)
            else if (_isOwner)
              IconButton(
                tooltip: 'Generate reservation code',
                icon: const Icon(Icons.qr_code, color: BPColors.yellow),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _issueReservation(p),
              )
            else
              const Icon(Icons.chevron_right, color: BPColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Owner-only: pre-reserves this specific empty position and returns
  /// an access key up front, before anyone fills anything in — for
  /// handing a *specific* position to a *specific* person (as opposed
  /// to the open self-serve claim flow, which anyone reaches by
  /// tapping an empty position and hands out a random key only once
  /// they've already filled in the form).
  Future<void> _issueReservation(CapsuleProfile p) async {
    try {
      final result = await _api.saveCapsule(
        type: 'orb',
        number: p.privateNumber,
        sphere: 'orbit',
        ownerName: '',
        ownerCountry: '',
        message: '',
        openingDateIso: DateTime.now().add(const Duration(days: 365 * 3)).toIso8601String(),
        visibility: 'public',
      );
      final issuedKey = result['issuedAccessKey'] as String?;
      if (!mounted) return;
      if (issuedKey == null || issuedKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This position already has a reservation code issued.')));
        return;
      }
      _loadProfiles();
      _showReservationCodeSheet(p, issuedKey);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate a code: $e')));
    }
  }

  void _showReservationCodeSheet(CapsuleProfile p, String code) {
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
            Text('Position #${p.privateNumber}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: BPColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Give this to one specific person. It lets them claim exactly this position — nobody else can use it once they do.',
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
                    onPressed: () => Share.share('Your BenchPad World Time Capsule 2 position #${p.privateNumber} — claim it with this code in the app under "My Capsule": $code'),
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

  /// Rotates the sphere so [index]'s point faces the viewer — the
  /// equivalent of the PWA's startFlight(). Simplified to a direct jump
  /// (no eased animation) for this pass; smooth flight can be added later.
  void _flyTo(int index, {bool openCard = true}) {
    final point = _tileCenter(index);
    // Solve rotationY/rotationX such that the rotated point faces +z.
    final targetY = math.atan2(point.x, point.z);
    final ring = math.sqrt(point.x * point.x + point.z * point.z);
    final targetX = -math.atan2(point.y, ring == 0 ? 0.0001 : ring);
    setState(() {
      _rotationY = targetY;
      _rotationX = targetX.clamp(-1.4, 1.4);
      _selectedIndex = index;
      _spinning = false;
    });
    if (openCard) {
      _showIdentitySheet(_profiles[index]);
    }
  }

  void _showCountrySearchSheet() {
    final controller = TextEditingController();
    List<CapsuleProfile> results = [];
    final countries = _profiles.map((p) => p.country).where((c) => c.isNotEmpty).toSet().toList()..sort();
    final countryCounts = <String, int>{};
    for (final p in _profiles) {
      countryCounts[p.country] = (countryCounts[p.country] ?? 0) + 1;
    }
    final popular = (List<String>.from(countries)
      ..sort((a, b) => (countryCounts[b] ?? 0).compareTo(countryCounts[a] ?? 0)))
        .take(6)
        .toList();

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
                  : _profiles.where((p) {
                      return p.status != 'empty' &&
                          (p.name.toLowerCase().contains(q) ||
                              p.country.toLowerCase().contains(q) ||
                              p.privateNumber.toString() == q);
                    }).toList();
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                const Text('SEARCH', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Text('Find a person', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(controller: controller, autofocus: true, onChanged: runSearch, decoration: const InputDecoration(hintText: 'Name, country, or position number')),
                const SizedBox(height: 16),
                if (controller.text.trim().isEmpty) ...[
                  const Text('POPULAR COUNTRIES', style: TextStyle(color: BPColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  if (popular.isEmpty)
                    const Text('No public capsules yet.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: popular.map((c) {
                        final flag = _profiles.firstWhere((p) => p.country == c).flag;
                        return ActionChip(
                          backgroundColor: BPColors.card,
                          label: Text('$flag $c (${countryCounts[c]})', style: const TextStyle(fontSize: 11, color: BPColors.textPrimary)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            final first = _profiles.firstWhere((p) => p.country == c);
                            _flyTo(first.index);
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  const Text('ALL COUNTRIES', style: TextStyle(color: BPColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  if (countries.isEmpty)
                    const Text('No public capsules yet — check back once more capsules are opened.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12))
                  else
                    ...countries.map((c) {
                      final flag = _profiles.firstWhere((p) => p.country == c).flag;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text(flag, style: const TextStyle(fontSize: 20, color: BPColors.textPrimary)),
                        title: Text(c, style: const TextStyle(fontSize: 13, color: BPColors.textPrimary)),
                        trailing: Text('${countryCounts[c]}', style: const TextStyle(color: BPColors.textSecondary, fontSize: 12)),
                        onTap: () {
                          Navigator.pop(ctx);
                          final first = _profiles.firstWhere((p) => p.country == c);
                          _flyTo(first.index);
                        },
                      );
                    }),
                ] else if (results.isEmpty)
                  const Text('No matching capsules.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12))
                else
                  ...results.map((p) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text(p.flag, style: const TextStyle(fontSize: 20)),
                        title: Text(p.name.isEmpty ? 'Private' : p.name, style: const TextStyle(fontSize: 13, color: BPColors.textPrimary)),
                        subtitle: Text('${p.country} · #${p.privateNumber}', style: const TextStyle(color: BPColors.textSecondary, fontSize: 11)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _flyTo(p.index);
                        },
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDiscoverySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BPColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            const Text('DISCOVERY', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text('Explore a living digital world', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _discoveryButton('🎲 RANDOM CAPSULE', 'Meet someone unexpected', () {
              Navigator.pop(ctx);
              final random = _profiles[math.Random().nextInt(_profiles.length)];
              _flyTo(random.index);
            }),
            _discoveryButton('🆕 RECENTLY CREATED', 'Newest member of the world', () {
              Navigator.pop(ctx);
              final sorted = List<CapsuleProfile>.from(_profiles)
                ..sort((a, b) => b.memberSince.compareTo(a.memberSince));
              _flyTo(sorted.first.index);
            }),
            _discoveryButton('🔓 LATEST OPENED', 'Most recent revealed memory', () {
              Navigator.pop(ctx);
              final opened = _profiles.where((p) => p.status == 'open').toList()
                ..sort((a, b) => b.openingDate.compareTo(a.openingDate));
              if (opened.isNotEmpty) _flyTo(opened.first.index);
            }),
            _discoveryButton('⏳ NEXT OPENING', 'Closest future opening', () {
              Navigator.pop(ctx);
              final upcoming = _profiles.where((p) {
                final d = DateTime.tryParse(p.openingDate);
                return d != null && d.isAfter(_referenceToday) && p.status != 'open';
              }).toList()
                ..sort((a, b) => a.openingDate.compareTo(b.openingDate));
              if (upcoming.isNotEmpty) _flyTo(upcoming.first.index);
            }),
            _discoveryButton('📅 OPENING TODAY', 'Capsules reaching their date today', () {
              Navigator.pop(ctx);
              final today = _referenceToday.toIso8601String().substring(0, 10);
              final matches = _profiles.where((p) => p.openingDate.startsWith(today)).toList();
              if (matches.isNotEmpty) _flyTo(matches.first.index);
            }),
            _discoveryButton('🕘 RECENTLY VIEWED', 'Return to recent stories', () {
              Navigator.pop(ctx);
              _showHistorySheet();
            }),
          ],
        ),
      ),
    );
  }

  Widget _discoveryButton(String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BPColors.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: BPColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistorySheet() {
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
            const Text('RECENTLY VIEWED', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 12),
            if (_recentlyViewed.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Open an Identity Card to build your recent history.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12)),
              )
            else
              ..._recentlyViewed.map((i) {
                final p = _profiles[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: HSLColor.fromAHSL(1, p.avatarHue, 0.6, 0.4).toColor(),
                    child: Text(p.initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: BPColors.textPrimary)),
                  ),
                  title: Text('${p.flag} ${p.name}', style: const TextStyle(fontSize: 13, color: BPColors.textPrimary)),
                  subtitle: Text('${p.country} · ${p.status.toUpperCase()}', style: const TextStyle(fontSize: 11, color: BPColors.textPrimary)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    _flyTo(i);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  void _shareCapsule(CapsuleProfile p) {
    final text = '${p.name} · ${p.country}\n"${p.message}"\n\nBenchPad World capsule ${p.worldId}';
    Share.share(text, subject: 'BenchPad World — ${p.name}');
  }

  Future<void> _copyCapsuleLink(CapsuleProfile p) async {
    final link = 'https://benchpad.pages.dev/benchpad-memory-orbit.html?capsule=${p.worldId}';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
    }
  }


  void _showIdentitySheet(CapsuleProfile p) {
    _rememberViewed(p.index);
    final color = _statusColors[p.status] ?? BPColors.yellow;
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
            Row(
              children: [
                Expanded(
                  child: Text('${p.flag} ${p.country}', style: const TextStyle(color: BPColors.yellow, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.link, size: 20),
                  onPressed: () => _copyCapsuleLink(p),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.share_outlined, size: 20),
                  onPressed: () => _shareCapsule(p),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: BPColors.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                _pill('WORLD ID', p.worldId),
                const SizedBox(width: 8),
                _pill('CAPSULE', p.capsuleId),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
              child: Text(p.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            const Text('MESSAGE', style: TextStyle(color: BPColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('"${p.message}"', style: const TextStyle(fontSize: 14, height: 1.4, fontStyle: FontStyle.italic, color: BPColors.textPrimary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _factBlock('MEMBER SINCE', _formatDate(p.memberSince))),
                const SizedBox(width: 8),
                Expanded(child: _factBlock('VISIBILITY', p.visibility)),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, side: const BorderSide(color: BPColors.yellow)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BroadcastCalendarScreen(
                  sphere: 'orbit',
                  capsuleType: 'orb',
                  capsuleNumber: p.privateNumber,
                  ownerName: p.name,
                  ownerCountry: p.country,
                  contentReady: p.message.isNotEmpty,
                )));
              },
              child: const Text('SCHEDULE BROADCAST'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: BPColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BPColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// Formats an ISO timestamp/date string into 'D Mon YYYY' — the raw
  /// '2026-08-27T06:11:05.000Z' the server sends isn't something a
  /// person should have to read directly.
  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
  }

  Widget _factBlock(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: BPColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 11, color: BPColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final counts = _statusCounts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          _legendButton('all', 'ALL', _profiles.length, BPColors.yellow),
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

const _geosphereSubdivisions = 7; // -> exactly 492 tiles (10*n*n+2)

_Vec3 _tileCenter(int index) {
  final tiles = Geosphere.build(subdivisions: _geosphereSubdivisions);
  final t = tiles[index % tiles.length];
  return _Vec3(t.center.x, t.center.y, t.center.z);
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
/// so it follows the tile's own skew/foreshortening as the sphere turns.
/// Mirrors the same helper in vault_sphere_screen.dart.
(_Vec3 east, _Vec3 north) _tangentBasis(_Vec3 normal) {
  const worldUp = _Vec3(0, 1, 0);
  var e = _cross(worldUp, normal);
  final eLen = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  e = eLen < 1e-6 ? const _Vec3(1, 0, 0) : _Vec3(e.x / eLen, e.y / eLen, e.z / eLen);
  final n = _cross(normal, e);
  return (e, n);
}

class _SpherePainter extends CustomPainter {
  final List<CapsuleProfile> profiles;
  final double rotationX, rotationY, scale;
  final int? selectedIndex;
  final Map<String, Color> statusColors;

  _SpherePainter({
    required this.profiles,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.selectedIndex,
    required this.statusColors,
  });

  // Same cached-per-digit approach as Time Capsule 1's painter: text layout
  // for a given number runs once, then every frame we just transform the
  // cached painter into place — no per-frame layout during drag/rotation.
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
    final tiles = Geosphere.build(subdivisions: _geosphereSubdivisions);

    final profileByIndex = <int, CapsuleProfile>{for (final p in profiles) p.index % tiles.length: p};

    // Rotate + project every tile's corners once, then sort tiles by
    // (average) depth for a simple but effective painter's-algorithm
    // draw order on a convex shape.
    final entries = <MapEntry<GeoTile, List<_Vec3>>>[];
    for (final tile in tiles) {
      final rotatedCorners = tile.corners.map((c) => _rotate(_Vec3(c.x, c.y, c.z), rotationX, rotationY)).toList();
      entries.add(MapEntry(tile, rotatedCorners));
    }
    entries.sort((a, b) {
      final az = a.value.fold<double>(0, (s, v) => s + v.z) / a.value.length;
      final bz = b.value.fold<double>(0, (s, v) => s + v.z) / b.value.length;
      return az.compareTo(bz);
    });

    for (final entry in entries) {
      final tile = entry.key;
      final corners = entry.value;
      final avgZ = corners.fold<double>(0, (s, v) => s + v.z) / corners.length;
      if (avgZ < -0.15) continue; // back of the sphere — skip entirely

      final depthFactor = ((avgZ + 1) / 2).clamp(0.0, 1.0);
      final profile = profileByIndex[tile.index];
      final baseColor = profile != null ? (statusColors[profile.status] ?? Colors.grey) : const Color(0xFF2A3050);
      final isSelected = profile != null && profile.index == selectedIndex;

      // Project corners to screen space first, then shrink each tile toward
      // its own centroid so a visible gap appears between neighboring
      // cells — matches Time Capsule 1's tile treatment.
      final screenPoints = corners
          .map((v) => Offset(center.dx + v.x * radius, center.dy + v.y * radius))
          .toList();
      final tileCenter = screenPoints.fold<Offset>(
            Offset.zero,
            (sum, p) => sum + p,
          ) /
          screenPoints.length.toDouble();

      const _tileShrink = 0.86;
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
          ..color = baseColor.withOpacity(profile != null ? (0.35 + depthFactor * 0.55) : (0.12 + depthFactor * 0.18))
          ..style = PaintingStyle.fill,
      );

      // Neon-ish glow on occupied cells (matches Time Capsule 1's
      // treatment) — no MaskFilter.blur (expensive to rasterize per
      // tile every frame, especially at 500 tiles); a wider, more
      // transparent solid stroke under a crisp one fakes the glow cheaply.
      if (profile != null) {
        canvas.drawPath(
          path,
          Paint()
            ..color = baseColor.withOpacity(0.35 * depthFactor)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = baseColor.withOpacity(0.9 * depthFactor + 0.1)
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

      // Stamp the position number onto occupied capsules only — glued to
      // the tile's actual curvature, same approach as Time Capsule 1. Empty
      // positions stay bare to avoid cluttering the denser 492-tile sphere.
      if (profile != null && depthFactor > 0.35) {
        final normal = _Vec3(tile.center.x, tile.center.y, tile.center.z);
        final (east, north) = _tangentBasis(normal);
        final eastRotated = _rotate(east, rotationX, rotationY);
        final northRotated = _rotate(north, rotationX, rotationY);

        final avgTileRadius =
            shrunkPoints.map((p) => (p - tileCenter).distance).reduce((a, b) => a + b) / shrunkPoints.length;
        final halfSize = avgTileRadius * 0.40;

        final tp = _numberPainter(profile.privateNumber);
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
  bool shouldRepaint(covariant _SpherePainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.profiles.length != profiles.length;
  }
}
