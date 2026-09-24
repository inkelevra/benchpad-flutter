import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_business.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import '../widgets/flip_digit_counter.dart';
import '../widgets/neumorphic_category_filter.dart';
import 'local_partner_detail_screen.dart';
import 'offers_screen.dart';

enum _ViewMode { large, grid, list }

/// Local Partners — directory of nearby businesses, ported from
/// local-partners-v142055.html. Same static demo business roster as
/// Offers (zero server calls in the PWA).
///
/// UI-polish pass: restyled in the light neumorphic look, with the
/// PWA's own header block ported in full (tagline, live business
/// count, the CONCEPT PREVIEW disclosure + footnote, the 5%/5€
/// business-model stats, and a real name search), plus the PWA's three
/// view modes — large photo cards (default), a 2-per-row compact grid,
/// and a narrow list — via lpViewOptionTwo/Three/List in the source.
///
/// Simplification note: the PWA's interactive map view (businesses
/// placed at x/y coordinates on a fictional city map image) is still
/// skipped — these three list/grid views cover the same information
/// without needing a mapping widget.
class LocalPartnersScreen extends StatefulWidget {
  const LocalPartnersScreen({super.key});

  @override
  State<LocalPartnersScreen> createState() => _LocalPartnersScreenState();
}

class _LocalPartnersScreenState extends State<LocalPartnersScreen> {
  static const savedPartnersKey = 'benchpad_saved_partners_v1';

  String _category = 'all';
  String _search = '';
  _ViewMode _viewMode = _ViewMode.large;
  String? _expandedStat;
  Set<String> _savedSlugs = {};
  // Fresh random order each time this screen opens — real distance-sort
  // will come back once partners are real businesses with real
  // distances (see DemoPartner.all), but with all 20 still fake demo
  // data, always showing the "nearest" one first just meant the same
  // card every single time.
  late final List<DemoPartner> _shuffledOrder = [...DemoPartner.all]..shuffle();

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(savedPartnersKey) ?? [];
    if (mounted) setState(() => _savedSlugs = saved.toSet());
  }

  Future<void> _persistSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(savedPartnersKey, _savedSlugs.toList());
  }

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

  /// The only two partners with a real, distinct brand logo among the
  /// 20 — the rest of assets/partner-logos-v14119/ are generic
  /// auto-generated per-category icons, not real business identities.
  static const _brandLogos = {
    'vata-originals': 'assets/images/partner-logos/vata-originals.png',
    'bulko-toys': 'assets/images/partner-logos/bulko-toys.png',
  };

  static const _badgeSize = 52.0;

  List<DemoPartner> get _visible {
    var list = _category == 'all' ? _shuffledOrder : _shuffledOrder.where((p) => p.category == _category).toList();
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    return list;
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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('Local Partners')),
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
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: NeumorphicCategoryFilter(
                      categories: _categories,
                      icons: _categoryIcons,
                      value: _category,
                      onChanged: (v) => setState(() => _category = v),
                      sheetTitle: 'Category',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildViewModeButton(_ViewMode.large, Icons.crop_square)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildViewModeButton(_ViewMode.grid, Icons.grid_view_rounded)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildViewModeButton(_ViewMode.list, Icons.view_list_rounded)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No businesses match your search.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
                  ),
                )
              else
                _buildResults(visible),
              const SizedBox(height: 16),
              _buildOffersCrossLink(),
              const SizedBox(height: 14),
              const Text(
                '* These businesses are examples showing how the Local Partners marketplace will work. None are live partners yet.',
                style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10, fontStyle: FontStyle.italic, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ported from index.html's lpOffersTitle/lpOffersText — now a real
  /// button to Current Offers instead of just a static note.
  Widget _buildOffersCrossLink() {
    return NeumorphicBox(
      borderRadius: 18,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OffersScreen())),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.local_offer_outlined, color: NeumorphicPalette.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Special offers stay connected', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                const SizedBox(height: 2),
                Text('Partner promotions can appear in Current Offers and link back to the same business profile.',
                    style: TextStyle(fontSize: 11, color: NeumorphicPalette.textSecondary, height: 1.3)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: NeumorphicPalette.textSecondary),
        ],
      ),
    );
  }

  /// Ported from index.html's lpKicker/lpTitle/lpSubtitle + the
  /// CONCEPT PREVIEW badge/footnote and the 5%/5€ business-model stats.
  Widget _buildHeader(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DISCOVER NEARBY', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text('Support local. Shop local. Grow local.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
              child: const Text('CONCEPT PREVIEW*',
                  style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            Expanded(child: Align(alignment: Alignment.centerRight, child: _buildFlipCounter(count))),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStatChip(
                'commission',
                '5%',
                'commission per order',
                'BenchPad takes a 5% commission on each order placed through the app for this partner.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatChip(
                'membership',
                '5€',
                'membership per month',
                'Partners pay a flat 5€/month to have a presence on BenchPad Local Partners.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildViewModeButton(_ViewMode mode, IconData icon) {
    final selected = _viewMode == mode;
    return NeumorphicBox(
      pressed: selected,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(vertical: 9),
      onTap: () => setState(() => _viewMode = mode),
      child: Center(
        child: Icon(icon, size: 17, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary),
      ),
    );
  }

  /// Split-flap per-digit counter (see lib/widgets/flip_digit_counter.dart)
  /// in a thin flat outline — not raised/pressed like a button, since
  /// this is informational, not tappable.
  Widget _buildFlipCounter(int count) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlipDigitCounter(value: count),
          const SizedBox(width: 6),
          const Text('businesses', style: TextStyle(fontSize: 11, color: NeumorphicPalette.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStatChip(String key, String value, String label, String explanation) {
    final expanded = _expandedStat == key;
    return NeumorphicBox(
      soft: true,
      pressed: expanded,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => setState(() => _expandedStat = expanded ? null : key),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NeumorphicPalette.accent)),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary, height: 1.2))),
              Icon(expanded ? Icons.expand_less_rounded : Icons.info_outline_rounded, size: 14, color: NeumorphicPalette.textSecondary),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(explanation, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary, height: 1.35)),
                  )
                : const SizedBox(width: double.infinity),
          ),
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
                hintText: 'Search',
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

  Widget _buildResults(List<DemoPartner> visible) {
    switch (_viewMode) {
      case _ViewMode.large:
        return Column(children: visible.map(_buildLargeCard).toList());
      case _ViewMode.list:
        return Column(children: visible.map(_buildListRow).toList());
      case _ViewMode.grid:
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
          children: visible.map(_buildGridCard).toList(),
        );
    }
  }

  void _openDetail(DemoPartner p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocalPartnerDetailScreen(
          slug: p.slug,
          fallbackName: p.name,
          fallbackCategory: p.category,
          fallbackDistanceText: p.distanceText,
        ),
      ),
    );
    _loadSaved();
  }

  Widget _buildPhoto(DemoPartner p, LocalPartnerProfile? profile, double size) {
    return profile != null
        ? Image.asset(
            profile.photoAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              color: NeumorphicPalette.background,
              child: Icon(_categoryIcons[p.category] ?? Icons.store_outlined, color: NeumorphicPalette.accent, size: size),
            ),
          )
        : Container(
            color: NeumorphicPalette.background,
            child: Icon(_categoryIcons[p.category] ?? Icons.store_outlined, color: NeumorphicPalette.accent, size: size),
          );
  }

  /// Default view — the large single-column photo cards with the save
  /// toggle, rating, offer ribbon and logo/category badge.
  Widget _buildLargeCard(DemoPartner p) {
    final profile = LocalPartnerProfile.bySlug[p.slug];
    final categoryLabel = profile?.category ?? (p.category[0].toUpperCase() + p.category.substring(1));
    final saved = _savedSlugs.contains(p.slug);
    final brandLogo = _brandLogos[p.slug];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // All partner photos are square (1:1) — sizing the photo box
          // to match that exactly (rather than a fixed short height)
          // shows the whole photo instead of cover-cropping its top
          // and bottom to fit a wide rectangle.
          final photoSize = constraints.maxWidth;
          const inset = 5.0; // small gap so the card's own background shows as a thin border around the photo
          const photoRadius = 18.0;
          return NeumorphicBox(
            borderRadius: 22,
            padding: EdgeInsets.zero,
            onTap: () => _openDetail(p),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(inset),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(photoRadius),
                        child: SizedBox(
                          height: photoSize - inset * 2,
                          width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPhoto(p, profile, 40),
                            Positioned(top: 10, left: 10, child: _buildSaveButton(p.slug, saved)),
                            if (profile != null)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(999)),
                                  child: Text(profile.rating, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            if (profile != null)
                              Positioned(
                                left: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(999)),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🏷️', style: TextStyle(fontSize: 10)),
                                      SizedBox(width: 4),
                                      Text('Active offer', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: NeumorphicPalette.textPrimary)),
                          const SizedBox(height: 2),
                          Text(categoryLabel, style: const TextStyle(fontSize: 12, color: NeumorphicPalette.textSecondary)),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 14, color: NeumorphicPalette.textSecondary),
                              const SizedBox(width: 3),
                              Text(p.distanceText, style: const TextStyle(fontSize: 12, color: NeumorphicPalette.textSecondary, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: NeumorphicPalette.success, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              const Text('Open', style: TextStyle(fontSize: 12, color: NeumorphicPalette.success, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: photoSize - inset - _badgeSize / 2,
                  right: 14,
                  child: Container(
                    width: _badgeSize,
                    height: _badgeSize,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: NeumorphicPalette.background,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(3, 3), blurRadius: 8),
                        BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-3, -3), blurRadius: 8),
                      ],
                    ),
                    child: ClipOval(
                      child: brandLogo != null
                          ? Image.asset(brandLogo, fit: BoxFit.cover)
                          : Container(
                              color: NeumorphicPalette.accent.withOpacity(0.12),
                              child: Icon(_categoryIcons[p.category] ?? Icons.store_outlined, color: NeumorphicPalette.accent, size: 22),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 2-per-row compact grid — kept deliberately simple (photo, name,
  /// distance + Open) since there isn't room for the save/offer/badge
  /// details at this size without it looking cluttered.
  Widget _buildGridCard(DemoPartner p) {
    final profile = LocalPartnerProfile.bySlug[p.slug];

    return NeumorphicBox(
      borderRadius: 18,
      padding: EdgeInsets.zero,
      onTap: () => _openDetail(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            child: AspectRatio(aspectRatio: 1, child: _buildPhoto(p, profile, 28)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: NeumorphicPalette.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 11, color: NeumorphicPalette.textSecondary),
                    const SizedBox(width: 2),
                    Text(p.distanceText, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary)),
                    const Spacer(),
                    Container(width: 5, height: 5, decoration: const BoxDecoration(color: NeumorphicPalette.success, shape: BoxShape.circle)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Narrow list view — a compact single row per business (small
  /// thumbnail, name/category, distance + chevron), for scanning many
  /// businesses quickly rather than browsing photos.
  Widget _buildListRow(DemoPartner p) {
    final profile = LocalPartnerProfile.bySlug[p.slug];
    final categoryLabel = profile?.category ?? (p.category[0].toUpperCase() + p.category.substring(1));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeumorphicBox(
        borderRadius: 16,
        padding: const EdgeInsets.all(10),
        onTap: () => _openDetail(p),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 48, height: 48, child: _buildPhoto(p, profile, 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: NeumorphicPalette.textPrimary)),
                  const SizedBox(height: 2),
                  Text(categoryLabel, style: const TextStyle(fontSize: 11, color: NeumorphicPalette.textSecondary)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: NeumorphicPalette.success, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(p.distanceText, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: NeumorphicPalette.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(String slug, bool saved) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.vibrate();
          setState(() {
            if (saved) {
              _savedSlugs.remove(slug);
            } else {
              _savedSlugs.add(slug);
            }
          });
          _persistSaved();
        },
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
          child: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? Colors.redAccent : Colors.white, size: 16),
        ),
      ),
    );
  }
}
