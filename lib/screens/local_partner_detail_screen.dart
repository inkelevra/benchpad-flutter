import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/local_business.dart';
import '../theme/neumorphic_theme.dart';
import 'offers_screen.dart';

/// Local Partner detail profile — ported 1:1 from the lp-profile-view
/// section of local-partners-v142055.html, including its real assets:
/// each partner's actual cover photo (hero + gallery) and actual
/// presentation video (inline, autoplay, muted, looping, with a sound
/// toggle — same as the PWA's inline business video, not a separate
/// modal player). Shows a hero header, quick facts, current offer, a
/// demo block that changes shape by category (restaurant: browsable
/// menu with a running order total; beauty: bookable service list;
/// flowers: bouquet picker; everything else: a generic highlights
/// list), an About/Hours/Gallery "everything in one place" section,
/// and the investor-demo monetization note.
///
/// UI-polish pass: restyled in the light neumorphic look (same as
/// Home/Local Partners/Current Offers) — same structure and button/
/// label layout as before, just re-themed. The saved/heart toggle now
/// persists (shared with the list screen's save state) instead of
/// resetting whenever this screen is left.
class LocalPartnerDetailScreen extends StatefulWidget {
  final String slug;
  final String fallbackName;
  final String fallbackCategory;
  final String fallbackDistanceText;

  const LocalPartnerDetailScreen({
    super.key,
    required this.slug,
    required this.fallbackName,
    required this.fallbackCategory,
    required this.fallbackDistanceText,
  });

  @override
  State<LocalPartnerDetailScreen> createState() => _LocalPartnerDetailScreenState();
}

class _LocalPartnerDetailScreenState extends State<LocalPartnerDetailScreen> {
  // Same key the Local Partners list screen uses, so a heart tapped on
  // either screen shows up correctly on the other and survives app
  // restarts, instead of living only in this screen's local state.
  static const _savedPartnersKey = 'benchpad_saved_partners_v1';

  double _orderTotal = 0;
  bool _saved = false;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoMuted = true;

  static const _categoryIcons = {
    'food': Icons.restaurant_outlined,
    'beauty': Icons.face_retouching_natural_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'services': Icons.build_outlined,
  };

  late final LocalPartnerProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = LocalPartnerProfile.bySlug[widget.slug] ??
        LocalPartnerProfile(
          slug: widget.slug,
          name: widget.fallbackName,
          category: widget.fallbackCategory,
          distanceText: widget.fallbackDistanceText,
          description: 'This local partner profile is ready for rich content such as video, products, services, bookings or ordering.',
          rating: '4.8 ★',
          hours: '09:00–18:00',
          offer: 'Partner offer available',
          about: 'This local partner profile is ready for rich content such as video, products, services, bookings or ordering.',
          tags: const ['Local favourite', 'Neighbourhood spot', 'Open today'],
          demo: PartnerDemoKind.generic,
        );

    _loadSaved();

    _videoController = VideoPlayerController.asset(
      _profile.videoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoController?.play();
      }).catchError((_) {
        // No presentation video for this slug (or the asset failed to
        // load) — the hero photo stays visible on its own, same as the
        // PWA when localPartnerVideos has no entry for a business.
      });
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_savedPartnersKey) ?? [];
    if (mounted) setState(() => _saved = saved.contains(widget.slug));
  }

  Future<void> _toggleSaved() async {
    setState(() => _saved = !_saved);
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getStringList(_savedPartnersKey) ?? []).toSet();
    if (_saved) {
      saved.add(widget.slug);
    } else {
      saved.remove(widget.slug);
    }
    await prefs.setStringList(_savedPartnersKey, saved.toList());
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleVideoSound() {
    setState(() {
      _videoMuted = !_videoMuted;
      _videoController?.setVolume(_videoMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

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
        appBar: AppBar(
          title: Text(profile.name),
          actions: [
            IconButton(
              icon: Icon(_saved ? Icons.favorite : Icons.favorite_border, color: _saved ? Colors.redAccent : null),
              onPressed: _toggleSaved,
              tooltip: 'Save',
            ),
          ],
        ),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHero(profile),
              const SizedBox(height: 16),
              Text(profile.description, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              _buildContactActions(profile),
              const SizedBox(height: 16),
              _buildQuickFacts(profile),
              const SizedBox(height: 16),
              _buildMediaSection(profile),
              const SizedBox(height: 16),
              _buildOfferCard(profile),
              const SizedBox(height: 20),
              _buildDemoBlock(profile),
              const SizedBox(height: 20),
              _buildAboutSection(profile),
              const SizedBox(height: 16),
              _buildMonetizationNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(LocalPartnerProfile profile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              profile.photoAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: NeumorphicPalette.surface,
                child: Center(
                  child: Icon(_categoryIcons[_categoryKeyFor(profile.category)] ?? Icons.store_outlined,
                      size: 56, color: NeumorphicPalette.accent.withOpacity(0.5)),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                  stops: const [0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: NeumorphicPalette.accent.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: Text(profile.category.toUpperCase(),
                        style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 6),
                  Text(profile.name,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Open now · ${profile.distanceText}',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline business presentation video — autoplay, muted, looping, with
  /// a tap-to-unmute button — ported from local-partners-v142055.html's
  /// configureInlinePartnerVideo() (the video replaces the static photo
  /// in the media box, rather than opening a separate popup player).
  Widget _buildMediaSection(LocalPartnerProfile profile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoReady && _videoController != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              Image.asset(profile.photoAsset, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: NeumorphicPalette.surface)),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(999)),
                child: const Text('BUSINESS STORY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
            if (_videoReady)
              Positioned(
                right: 10,
                bottom: 10,
                child: Material(
                  color: Colors.black.withOpacity(0.45),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleVideoSound,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(_videoMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildContactActions(LocalPartnerProfile profile) {
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: NeumorphicBox(
          soft: true,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(vertical: 10),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: NeumorphicPalette.textPrimary),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        action(Icons.call_outlined, 'Call', () => _toast('No phone number for this demo partner.')),
        const SizedBox(width: 8),
        action(Icons.public, 'Website', () => _toast('No website for this demo partner.')),
        const SizedBox(width: 8),
        action(Icons.directions_outlined, 'Directions', () => _openDirections(profile)),
        const SizedBox(width: 8),
        action(Icons.share_outlined, 'Share', () => _shareProfile(profile)),
      ],
    );
  }

  /// Ported from openActiveLocalPartnerMap() in local-partners-v142055.html —
  /// since these are demo businesses with no real address, the PWA (and
  /// this) sends Google Maps a text query ("<name>, Amsterdam") instead
  /// of fake coordinates, and lets Maps' own search resolve it.
  Future<void> _openDirections(LocalPartnerProfile profile) async {
    final query = Uri.encodeComponent('${profile.name}, Amsterdam');
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _toast('Could not open Google Maps.');
  }

  Future<void> _shareProfile(LocalPartnerProfile profile) async {
    // Reuses the app's existing share_plus dependency (already used by
    // Time Capsule 2's "Share capsule" action).
    Share.share('${profile.name} — ${profile.category} on BenchPad Local Partners\n${profile.offer}', subject: profile.name);
  }

  Widget _buildQuickFacts(LocalPartnerProfile profile) {
    Widget fact(String label, String value) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: NeumorphicBox(
            flat: true,
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1, color: NeumorphicPalette.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        fact('RATING', profile.rating),
        fact('TODAY', profile.hours),
        fact('PARTNER', 'Verified'),
      ],
    );
  }

  Widget _buildOfferCard(LocalPartnerProfile profile) {
    final hasListedOffer = DemoOffer.all.any((o) => o.slug == profile.slug);

    return NeumorphicBox(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CURRENT OFFER', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(profile.offer, style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (hasListedOffer)
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OffersScreen(initialSlug: profile.slug))),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View in Current Offers', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 13, color: NeumorphicPalette.accent),
                ],
              ),
            )
          else
            const Text('This offer isn\'t listed in Current Offers yet.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDemoBlock(LocalPartnerProfile profile) {
    switch (profile.demo) {
      case PartnerDemoKind.restaurant:
        return _buildRestaurantDemo();
      case PartnerDemoKind.beauty:
        return _buildBeautyDemo();
      case PartnerDemoKind.flowers:
        return _buildFlowerDemo();
      case PartnerDemoKind.generic:
        return _buildGenericDemo();
    }
  }

  Widget _sectionHeader(String kicker, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kicker, style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildRestaurantDemo() {
    const items = [
      ('Truffle Burger', 'Beef, truffle mayo, aged cheese', 14.5),
      ('Canal Salad', 'Greens, goat cheese, roasted seeds', 11.0),
      ('House Fries', 'Sea salt, herbs, house sauce', 5.5),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader('DEMO ORDERING', 'Popular menu'),
            NeumorphicBox(
              flat: true,
              borderRadius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text('Order total: €${_orderTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeumorphicBox(
                borderRadius: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                          const SizedBox(height: 2),
                          Text(item.$2, style: const TextStyle(fontSize: 11, color: NeumorphicPalette.textSecondary)),
                        ],
                      ),
                    ),
                    Text('€${item.$3.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
                    const SizedBox(width: 10),
                    NeumorphicBox(
                      soft: true,
                      borderRadius: 10,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      onTap: () {
                        setState(() => _orderTotal += item.$3);
                        _toast('Added: ${item.$1}');
                      },
                      child: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NeumorphicPalette.accent)),
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 4),
        NeumorphicBox(
          borderRadius: 14,
          onTap: () => _toast(_orderTotal > 0 ? 'Demo order ready' : 'Add an item first'),
          child: Center(
            child: Text('Proceed to demo order', style: const TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildBeautyDemo() {
    const services = [
      ('Signature styling', '45 min', 35),
      ('Colour refresh', '90 min', 65),
      ('Express beauty session', '30 min', 29),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('BOOK A SERVICE', 'Popular services'),
        const SizedBox(height: 12),
        ...services.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeumorphicBox(
                borderRadius: 14,
                onTap: () => _toast('Booking demo: ${s.$1}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                          const SizedBox(height: 2),
                          Text(s.$2, style: const TextStyle(fontSize: 11, color: NeumorphicPalette.textSecondary)),
                        ],
                      ),
                    ),
                    Text('€${s.$3}', style: const TextStyle(fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildFlowerDemo() {
    const bouquets = [
      ('✿', 'Morning Bloom', '€24'),
      ('❀', 'Canal Romance', '€32'),
      ('✾', 'Seasonal Mix', '€28'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('ORDER FLOWERS', 'Featured bouquets'),
        const SizedBox(height: 12),
        Row(
          children: bouquets
              .map((b) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: NeumorphicBox(
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        onTap: () => _toast('Order demo: ${b.$2}'),
                        child: Column(
                          children: [
                            Text(b.$1, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 8),
                            Text(b.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: NeumorphicPalette.textPrimary), textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text(b.$3, style: const TextStyle(fontSize: 11, color: NeumorphicPalette.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGenericDemo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('HIGHLIGHTS', 'What people love here'),
        const SizedBox(height: 12),
        ..._profile.tags.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeumorphicBox(
                borderRadius: 14,
                child: Text(h, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary)),
              ),
            )),
      ],
    );
  }

  Widget _buildAboutSection(LocalPartnerProfile profile) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final today = (DateTime.now().weekday - 1) % 7; // Monday=0 .. Sunday=6, matching the PWA's own indexing

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('PARTNER PROFILE', 'Everything in one place'),
        const SizedBox(height: 12),
        NeumorphicBox(
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ABOUT ${profile.name.toUpperCase()}',
                  style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(profile.about, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12, height: 1.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: profile.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: NeumorphicPalette.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(t, style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        NeumorphicBox(
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('OPENING HOURS', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: NeumorphicPalette.success.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                    child: const Text('Open now', style: TextStyle(color: NeumorphicPalette.success, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...List.generate(days.length, (i) {
                final isToday = i == today;
                final hours = i == 5 ? '10:00–17:00' : profile.hours; // Saturday (index 5) uses the PWA's own weekend-hours override
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isToday ? 'Today · ${days[i]}' : days[i],
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday ? NeumorphicPalette.textPrimary : NeumorphicPalette.textSecondary,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                          )),
                      Text(hours,
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                          )),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildGallery(profile),
        const SizedBox(height: 10),
        NeumorphicBox(
          borderRadius: 16,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.15), shape: BoxShape.circle),
                child: const Center(child: Text('BP', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 11))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('AVAILABLE ON THIS BENCHPAD', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    SizedBox(height: 4),
                    Text('Connected to BP-AMS-001', style: TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Offers and local information from this partner can be discovered directly from this BenchPad.',
                        style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Three shots — real distinct photos when the partner has
  /// galleryAssets set (currently just vata-originals), otherwise
  /// falls back to the same cover photo styled three ways (plain/
  /// zoomed-in/darkened), ported exactly from
  /// lpPopulateEnhancedProfile()'s gallery. Tap any shot to open it
  /// full-screen (pinch to zoom); tap again anywhere to close.
  Widget _buildGallery(LocalPartnerProfile profile) {
    Widget shot(String label, ImageProvider imageProvider, Widget preview) {
      return Expanded(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: GestureDetector(
                  onTap: () => _openGalleryZoom(imageProvider),
                  child: preview,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
          ],
        ),
      );
    }

    final hasRealGallery = profile.galleryAssets.length >= 3;

    if (hasRealGallery) {
      final labels = ['Atmosphere', 'Inside', 'Style'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GALLERY', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                shot(
                  labels[i],
                  AssetImage(profile.galleryAssets[i]),
                  Image.asset(profile.galleryAssets[i], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: NeumorphicPalette.surface)),
                ),
              ],
            ],
          ),
        ],
      );
    }

    final photoProvider = AssetImage(profile.photoAsset);
    final photo = Image.asset(profile.photoAsset, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: NeumorphicPalette.surface));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GALLERY', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(
          children: [
            shot('Main view', photoProvider, photo),
            const SizedBox(width: 8),
            shot('Inside', photoProvider, Transform.scale(scale: 1.35, child: photo)),
            const SizedBox(width: 8),
            shot('Atmosphere', photoProvider, ColorFiltered(colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.45), BlendMode.darken), child: photo)),
          ],
        ),
      ],
    );
  }

  /// Full-screen pinch-zoomable viewer — tap anywhere (background or
  /// the image itself) to close.
  void _openGalleryZoom(ImageProvider image) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black,
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image(image: image, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    ));
  }

  Widget _buildMonetizationNote() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 12,
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Investor demo', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
          SizedBox(height: 4),
          Text('5€/month presence + 5% commission on orders placed through the platform',
              style: TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _categoryKeyFor(String category) {
    final c = category.toLowerCase();
    if (c.contains('restaurant') || c.contains('bakery') || c.contains('café') || c.contains('cafe') || c.contains('sushi')) return 'food';
    if (c.contains('beauty') || c.contains('nail') || c.contains('barber')) return 'beauty';
    if (c.contains('fashion') || c.contains('boutique') || c.contains('toy') || c.contains('flower') || c.contains('book')) return 'shopping';
    return 'services';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
