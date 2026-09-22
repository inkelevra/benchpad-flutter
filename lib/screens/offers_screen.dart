import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_business.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import '../widgets/flip_digit_counter.dart';
import '../widgets/neumorphic_category_filter.dart';
import '../widgets/neumorphic_select.dart';

enum _SortMode { newest, nearest, value }

/// Current Offers — deals from nearby local businesses, ported from
/// offers.html. This is entirely static demo content in the PWA too
/// (zero server calls, no live business data) — saved/bookmarked state
/// is local-only, matching the PWA's localStorage approach.
///
/// UI-polish pass: restyled in the light neumorphic look and the whole
/// header ported from offers.html — subtitle, live "offers found
/// nearby" count, the saved-offers pill with its counter, the CONCEPT
/// PREVIEW* badge + footnote, real search, Distance + Sort selects,
/// and the "Live now / Discovery radius" status strip. Per instruction,
/// the "Connected to Local Partners" footer note is deliberately NOT
/// ported (everything else on the page is).
class OffersScreen extends StatefulWidget {
  final String? initialSlug;

  const OffersScreen({super.key, this.initialSlug});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  static const _savedKey = 'benchpad_saved_offers_v1';
  String _category = 'all';
  String _search = '';
  bool _nearestOnly = false;
  _SortMode _sortMode = _SortMode.newest;
  Set<String> _saved = {};

  static const _categories = [
    ['all', 'ALL'],
    ['food', 'FOOD & DRINK'],
    ['beauty', 'BEAUTY'],
    ['shopping', 'SHOPPING'],
    ['services', 'SERVICES'],
  ];

  static const _categoryIcons = {
    'food': Icons.restaurant_outlined,
    'beauty': Icons.face_retouching_natural_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'services': Icons.build_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadSaved();
    if (widget.initialSlug != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final match = DemoOffer.all.where((o) => o.slug == widget.initialSlug).toList();
        if (match.isNotEmpty) _openOffer(match.first);
      });
    }
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_savedKey) ?? [];
    if (mounted) setState(() => _saved = saved.toSet());
  }

  Future<void> _toggleSave(String slug) async {
    setState(() {
      if (_saved.contains(slug)) {
        _saved.remove(slug);
      } else {
        _saved.add(slug);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedKey, _saved.toList());
  }

  /// Rough "best value" heuristic — the demo data's `value` field isn't
  /// a uniform number (10% OFF / €6.50 / FREE / EARLY ACCESS aren't
  /// directly comparable), so this just gives free/exclusive offers
  /// top priority, then ranks percentage-off offers by size.
  /// Splits a value like '€0 DELIVERY' into a larger price/number span
  /// and a smaller trailing-word span, so a long word (DELIVERY)
  /// doesn't force the whole thing — including the number — down to a
  /// tiny size or get cut off. Pure values with no trailing word
  /// (FREE, €22, -10%) render as a single span at the normal size.
  TextSpan _valueSpans(String value) {
    const priceStyle = TextStyle(color: NeumorphicPalette.accent, fontSize: 13, fontWeight: FontWeight.w800, height: 1.1);
    const wordStyle = TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, height: 1.2);
    final match = RegExp(r'^(FREE|-?\d+%|€\d+(?:\.\d+)?)(\s+(.+))?$').firstMatch(value);
    if (match == null || match.group(3) == null) {
      return TextSpan(text: value, style: priceStyle);
    }
    return TextSpan(children: [
      TextSpan(text: match.group(1), style: priceStyle),
      TextSpan(text: '\n${match.group(3)}', style: wordStyle),
    ]);
  }

  int _valueScore(String value) {
    final v = value.toUpperCase();
    if (v.contains('FREE')) return 1000;
    if (v.contains('EARLY ACCESS')) return 900;
    final percent = RegExp(r'(\d+)%').firstMatch(v);
    if (percent != null) return int.parse(percent.group(1)!) * 10;
    return 0;
  }

  List<DemoOffer> get _visible {
    var list = _category == 'all' ? DemoOffer.all : DemoOffer.all.where((o) => o.category == _category).toList();
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((o) => o.title.toLowerCase().contains(q) || o.partner.toLowerCase().contains(q)).toList();
    }
    final sorted = [...list];
    if (_nearestOnly || _sortMode == _SortMode.nearest) {
      sorted.sort((a, b) => a.distance.compareTo(b.distance));
    } else if (_sortMode == _SortMode.value) {
      sorted.sort((a, b) => _valueScore(b.value).compareTo(_valueScore(a.value)));
    }
    // _SortMode.newest keeps the authored list order (no re-sort).
    return sorted;
  }

  void _openOffer(DemoOffer o) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NeumorphicPalette.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
              child: Text(o.badge, style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            Text(o.partner, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(o.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
            const SizedBox(height: 10),
            Text(o.desc, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _factCell('DISTANCE', o.distanceText)),
                const SizedBox(width: 8),
                Expanded(child: _factCell('EXPIRES', o.expiry)),
              ],
            ),
            const SizedBox(height: 16),
            NeumorphicBox(
              pressed: true,
              borderRadius: 14,
              child: Column(
                children: [
                  const Text('OFFER CODE', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(o.code, style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2, color: NeumorphicPalette.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: NeumorphicBox(
                borderRadius: 14,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: o.code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Code ${o.code} copied to clipboard')),
                    );
                  }
                },
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 15, color: NeumorphicPalette.accent),
                      SizedBox(width: 8),
                      Text('COPY CODE', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _factCell(String label, String value) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 12,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('Current Offers')),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(visible.length),
              const SizedBox(height: 16),
              _buildSearchField(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildDistanceSelect()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSortSelect()),
                ],
              ),
              const SizedBox(height: 12),
              NeumorphicCategoryFilter(
                categories: _categories,
                icons: _categoryIcons,
                value: _category,
                onChanged: (v) => setState(() => _category = v),
                sheetTitle: 'Category',
              ),
              const SizedBox(height: 16),
              _buildStatusStrip(),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Text('No matching offers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: NeumorphicPalette.textPrimary)),
                        SizedBox(height: 4),
                        Text('Try another category or search term.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                ...visible.map(_buildOfferCard),
              const SizedBox(height: 6),
              const Text(
                '* These offers are examples showing how the Current Offers marketplace will work. None are live offers yet.',
                style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10, fontStyle: FontStyle.italic, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ported from offers.html's coTitle/coSubtitle/coActiveCount +
  /// coConceptBadge. The disclosure footnote itself now lives at the
  /// very end of the page (matches Local Partners). "Offers found
  /// nearby" and "Saved" are paired as two boxed counters, side by
  /// side, instead of one buried in small text and the other isolated
  /// up in the app bar — so it's clear at a glance: 14 exist, 0 saved.
  Widget _buildHeader(int visibleCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LIVE OFFERS', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text('Live promotions from nearby BenchPad partners.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
          child: const Text('CONCEPT PREVIEW*',
              style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFlipStat(visibleCount, 'found nearby'),
            const SizedBox(width: 8),
            _buildFlipStat(_saved.length, 'saved'),
          ],
        ),
      ],
    );
  }

  /// Split-flap per-digit counter, thin flat outline instead of the
  /// raised/pressed look — informational, not a button.
  Widget _buildFlipStat(int count, String label) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlipDigitCounter(value: count, digitWidth: 16, digitHeight: 22, fontSize: 13),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 9, color: NeumorphicPalette.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: NeumorphicPalette.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search offers...',
                hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ported from offers.html's coDistanceSelect ("All Nearby" /
  /// "Nearest First").
  Widget _buildDistanceSelect() {
    return NeumorphicSelect<bool>(
      leadingIcon: Icons.location_on_outlined,
      values: const [false, true],
      labels: const ['All Nearby', 'Nearest First'],
      value: _nearestOnly,
      onChanged: (v) => setState(() => _nearestOnly = v),
    );
  }

  /// Ported from offers.html's coSortSelect (Newest First / Nearest
  /// First / Best Value).
  Widget _buildSortSelect() {
    return NeumorphicSelect<_SortMode>(
      leadingIcon: Icons.swap_vert,
      values: const [_SortMode.newest, _SortMode.nearest, _SortMode.value],
      labels: const ['Newest First', 'Nearest First', 'Best Value'],
      value: _sortMode,
      onChanged: (v) => setState(() => _sortMode = v),
    );
  }

  /// Ported from offers.html's co-status-strip-v14210.
  Widget _buildStatusStrip() {
    Widget cell(Widget leading, String title, String subtitle) {
      return Expanded(
        child: NeumorphicBox(
          flat: true,
          borderRadius: 14,
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                    Text(subtitle, style: const TextStyle(fontSize: 9, color: NeumorphicPalette.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        cell(Container(width: 8, height: 8, decoration: const BoxDecoration(color: NeumorphicPalette.success, shape: BoxShape.circle)), 'Live now',
            'Offers update locally'),
        const SizedBox(width: 10),
        cell(const Icon(Icons.radar, size: 16, color: NeumorphicPalette.accent), '500 m', 'Discovery radius'),
      ],
    );
  }

  Widget _buildOfferCard(DemoOffer o) {
    final saved = _saved.contains(o.slug);
    final profile = LocalPartnerProfile.bySlug[o.slug];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeumorphicBox(
        borderRadius: 18,
        onTap: () => _openOffer(o),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 52,
                child: profile != null
                    ? Image.asset(
                        profile.photoAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(color: NeumorphicPalette.surface),
                      )
                    : Container(color: NeumorphicPalette.surface),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            o.badge,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 8, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(o.distanceText, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(o.partner, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                  Text(o.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                ],
              ),
            ),
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 32,
                    child: Center(
                      child: Text.rich(
                        _valueSpans(o.value),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, size: 20, color: saved ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary),
                    onPressed: () => _toggleSave(o.slug),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
