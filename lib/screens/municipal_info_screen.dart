import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import '../widgets/neumorphic_category_filter.dart';

/// Municipal Info — local news/updates feed for Amsterdam, ported from
/// municipal-info.html. Falls back to the same static demo dataset the
/// PWA ships when the live endpoint is unavailable.
///
/// Simplification note: the PWA's map view with pin markers is skipped
/// (a mapping widget is avoided given recent plugin/compileSdk issues);
/// the search + category filter + article-detail feed is the core value
/// and is fully ported.
class MunicipalInfoScreen extends StatefulWidget {
  const MunicipalInfoScreen({super.key});

  @override
  State<MunicipalInfoScreen> createState() => _MunicipalInfoScreenState();
}

class _MunicipalInfoScreenState extends State<MunicipalInfoScreen> {
  final _api = BenchpadApi();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _notices = [];
  String _category = 'all';
  String _sourceState = 'Connecting to official Amsterdam data…';
  Map<String, dynamic>? _urgent;

  static const _categories = [
    ['all', 'ALL UPDATES'],
    ['events', 'CULTURE & EVENTS'],
    ['initiatives', 'NEIGHBOURHOOD INITIATIVES'],
    ['road', 'ROAD WORKS'],
    ['transport', 'TRANSPORT'],
    ['waste', 'WASTE'],
    ['services', 'CITY SERVICES'],
  ];

  static final _fallback = <Map<String, dynamic>>[
    {'id': 'road-works', 'cat': 'road', 'title': 'Road works nearby', 'type': 'Road works', 'distance': '320 m', 'when': 'Multi-day works — see official source', 'status': 'In progress', 'badge': 'IMPORTANT', 'desc': 'Temporary traffic changes are active near this BenchPad. Follow local diversion signs.', 'source': 'Gemeente Amsterdam · Public space'},
    {'id': 'tram-update', 'cat': 'transport', 'title': 'Tram service adjustment', 'type': 'Transport', 'distance': '450 m', 'when': 'Temporary service window', 'status': 'Service change', 'badge': 'NOTICE', 'desc': 'A temporary service adjustment affects nearby tram stops.', 'source': 'Gemeente Amsterdam · Transport information'},
    {'id': 'culture-weave', 'cat': 'events', 'title': 'Weave a monumental artwork about the history of slavery', 'type': 'Culture & art', 'distance': 'Amsterdam-Zuidoost', 'when': 'See official source for dates', 'status': 'Upcoming', 'badge': 'CULTURE', 'desc': 'Join a collaborative national tapestry project at SHEBANG.', 'source': 'Kalender Amsterdam'},
    {'id': 'initiative-g-buurt', 'cat': 'initiatives', 'title': 'G-Buurt United gives residents a stronger voice', 'type': 'Neighbourhood initiative', 'distance': 'G-Buurt · Zuidoost', 'when': 'Ongoing programme', 'status': 'Active', 'badge': 'NEIGHBOURHOOD', 'desc': 'Residents submit ideas and help shape a cleaner and safer G-Buurt.', 'source': 'Gemeente Amsterdam · Zuidoost'},
    {'id': 'waste-collection', 'cat': 'waste', 'title': 'Waste collection reminder', 'type': 'Waste & recycling', 'distance': 'Local area', 'when': 'Before the local collection window', 'status': 'Scheduled', 'badge': 'NOTICE', 'desc': 'Place eligible household waste outside before collection begins.', 'source': 'Gemeente Amsterdam · Waste services'},
    {'id': 'city-desk', 'cat': 'services', 'title': 'Mobile city service desk', 'type': 'City services', 'distance': '750 m', 'when': 'See official source', 'status': 'Available', 'badge': 'SERVICE', 'desc': 'A temporary desk will help residents with municipal questions.', 'source': 'Gemeente Amsterdam · City services'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getMunicipalUpdates();
      final updates = (data['updates'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _notices = updates.take(18).toList();
        _urgent = data['urgent'] as Map<String, dynamic>? ?? (_notices.isNotEmpty ? _notices.first : null);
        _sourceState = 'Official Amsterdam data connected';
      });
    } catch (_) {
      setState(() {
        _notices = _fallback;
        _urgent = _fallback.first;
        _sourceState = 'Showing the local demo feed; official sources remain linked.';
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _searchController.text.trim().toLowerCase();
    return _notices.where((n) {
      final matchesCat = _category == 'all' || n['cat'] == _category;
      if (!matchesCat) return false;
      if (q.isEmpty) return true;
      final haystack = '${n['title']} ${n['desc']} ${n['type']} ${n['distance']}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  void _openArticle(Map<String, dynamic> n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NeumorphicPalette.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: NeumorphicPalette.shadowDark, borderRadius: BorderRadius.circular(2))),
            ),
            Text((n['type'] ?? 'LOCAL UPDATE').toString().toUpperCase(), style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Text('${n['title']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
            const SizedBox(height: 10),
            Text('${n['desc']}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [n['distance'], n['when'], n['status']].where((v) => v != null && v != '').map((v) {
                return NeumorphicBox(
                  flat: true,
                  borderRadius: 999,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('$v', style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textPrimary)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            NeumorphicBox(
              flat: true,
              borderRadius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SOURCE', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text('${n['source'] ?? 'Gemeente Amsterdam'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: NeumorphicPalette.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('Municipal Info')),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: NeumorphicPalette.success, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('LIVE LOCAL INFORMATION', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'News, public-space updates, cultural events and neighbourhood initiatives for Amsterdam.',
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (_urgent != null) ...[
                  _buildUrgentCard(),
                  const SizedBox(height: 16),
                ],
                NeumorphicBox(
                  flat: true,
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20, color: NeumorphicPalette.textSecondary),
                      hintText: 'Search local information',
                      hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 10),
                NeumorphicCategoryFilter(
                  categories: _categories,
                  icons: const {
                    'all': Icons.apps_rounded,
                    'events': Icons.celebration_outlined,
                    'initiatives': Icons.groups_outlined,
                    'road': Icons.construction_outlined,
                    'transport': Icons.directions_bus_outlined,
                    'waste': Icons.delete_outline,
                    'services': Icons.support_agent_outlined,
                  },
                  value: _category,
                  onChanged: (v) => setState(() => _category = v),
                  sheetTitle: 'Category',
                ),
                const SizedBox(height: 10),
                Text(_sourceState, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  NeumorphicBox(
                    flat: true,
                    borderRadius: 16,
                    child: const Center(child: Text('No matching updates.', style: TextStyle(color: NeumorphicPalette.textSecondary))),
                  )
                else
                  ...rows.map(_buildUpdateCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentCard() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      onTap: () => _openArticle(_urgent!),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: NeumorphicPalette.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('!', style: TextStyle(color: NeumorphicPalette.danger, fontWeight: FontWeight.w900, fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('IMPORTANT NEAR THIS BENCHPAD', style: TextStyle(color: NeumorphicPalette.danger, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Text('${_urgent!['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: NeumorphicPalette.textPrimary)),
                const SizedBox(height: 6),
                const Text('READ UPDATE', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        onTap: () => _openArticle(n),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text((n['type'] ?? '').toString().toUpperCase(), style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(999), border: Border.all(color: NeumorphicPalette.shadowDark.withOpacity(0.6))),
                  child: Text('${n['badge'] ?? n['status'] ?? ''}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: NeumorphicPalette.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${n['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
            const SizedBox(height: 6),
            Text('${n['desc']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11, height: 1.4)),
            const SizedBox(height: 8),
            Text('${n['distance']} · ${n['when']}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
