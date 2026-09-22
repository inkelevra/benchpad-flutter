// Auto-generated demo data ported from offers.html / local-partners-v142055.html
// Both PWA pages share the same 20-business fictional Amsterdam roster and have
// zero server calls — this is static demo content, not real business data.

class DemoOffer {
  final String slug, category, partner, title, badge, expiry, value, distanceText, code, desc;
  final double distance;
  const DemoOffer({required this.slug, required this.category, required this.partner, required this.title, required this.badge, required this.expiry, required this.value, required this.distance, required this.distanceText, required this.code, required this.desc});

  static const all = [
    DemoOffer(slug: 'urban-bistro', category: 'food', partner: 'Urban Bistro', title: '10% off your order', badge: 'TODAY ONLY', expiry: 'Ends 22:00', value: '10% OFF', distance: 0.3, distanceText: '0.3 km', code: 'URBAN10', desc: 'Save 10% on your order today. Show the offer code before payment.'),
    DemoOffer(slug: 'cafe-bellissimo', category: 'food', partner: 'Café Bellissimo', title: 'Coffee + pastry combo', badge: 'MORNING', expiry: 'Until 11:30', value: '€6.50', distance: 0.3, distanceText: '0.3 km', code: 'MORNING65', desc: 'A speciality coffee and fresh pastry combination for the morning.'),
    DemoOffer(slug: 'green-table', category: 'food', partner: 'Green Table', title: 'Healthy lunch special', badge: 'LUNCH', expiry: '12:00–15:00', value: '-15%', distance: 0.6, distanceText: '0.6 km', code: 'GREEN15', desc: 'Take 15% off the seasonal lunch selection during lunchtime.'),
    DemoOffer(slug: 'harbor-sushi', category: 'food', partner: 'Harbor Sushi', title: 'Chef\'s selection', badge: 'DINNER', expiry: 'Today', value: '€19', distance: 0.8, distanceText: '0.8 km', code: 'HARBOR19', desc: 'A rotating chef\'s selection prepared fresh for today.'),
    DemoOffer(slug: 'glam-studio', category: 'beauty', partner: 'Glam Studio', title: 'Free styling consultation', badge: 'NEW CLIENTS', expiry: 'This week', value: 'FREE', distance: 0.2, distanceText: '0.2 km', code: 'GLAMFREE', desc: 'Book a complimentary styling consultation for new clients.'),
    DemoOffer(slug: 'luna-nails', category: 'beauty', partner: 'Luna Nails', title: 'Express manicure', badge: 'EXPRESS', expiry: 'Today', value: '€22', distance: 0.5, distanceText: '0.5 km', code: 'LUNA22', desc: 'A quick express manicure appointment, subject to availability.'),
    DemoOffer(slug: 'amber-cuts', category: 'beauty', partner: 'Amber Cuts', title: 'Walk-in grooming offer', badge: 'WALK-IN', expiry: 'Until 18:00', value: '-10%', distance: 0.7, distanceText: '0.7 km', code: 'AMBER10', desc: 'Get 10% off selected grooming services for walk-in appointments.'),
    DemoOffer(slug: 'bloom-boutique', category: 'shopping', partner: 'Bloom Boutique', title: 'Free local delivery', badge: 'LOCAL DELIVERY', expiry: 'Today', value: '€0 DELIVERY', distance: 0.4, distanceText: '0.4 km', code: 'BLOOMDEL', desc: 'Free local delivery on eligible bouquets ordered today.'),
    DemoOffer(slug: 'bulko-toys', category: 'shopping', partner: 'Bulko Toys', title: 'Meet Bulko in store', badge: 'KIDS FAVORITE', expiry: 'This week', value: '-10%', distance: 0.4, distanceText: '0.4 km', code: 'BULKO10', desc: 'Save 10% on any plush toy or gift when you visit Bulko this week.'),
    DemoOffer(slug: 'vata-originals', category: 'shopping', partner: 'VATA Originals', title: 'New season essentials', badge: 'NEW SEASON', expiry: 'This week', value: '-10%', distance: 0.5, distanceText: '0.5 km', code: 'VATA10', desc: 'Save 10% on selected new season essentials in natural fabrics.'),
    DemoOffer(slug: 'velvet-boutique', category: 'shopping', partner: 'Velvet Boutique', title: 'New collection preview', badge: 'MEMBERS', expiry: 'This weekend', value: 'EARLY ACCESS', distance: 0.9, distanceText: '0.9 km', code: 'VELVETEARLY', desc: 'Preview selected pieces from the new collection before general release.'),
    DemoOffer(slug: 'canal-books', category: 'shopping', partner: 'Canal Books', title: 'Staff picks bundle', badge: 'BOOKS', expiry: 'This week', value: '-15%', distance: 0.6, distanceText: '0.6 km', code: 'CANAL15', desc: 'Save 15% when choosing three titles from the current staff picks.'),
    DemoOffer(slug: 'pixel-repair', category: 'services', partner: 'Pixel Repair', title: 'Free quick diagnostic', badge: 'SERVICE', expiry: 'Today', value: 'FREE', distance: 0.4, distanceText: '0.4 km', code: 'PIXELCHECK', desc: 'A quick initial device diagnostic at no charge.'),
    DemoOffer(slug: 'north-cycle', category: 'services', partner: 'North Cycle', title: 'Free bike fit check', badge: 'CYCLING', expiry: 'This week', value: 'FREE', distance: 0.7, distanceText: '0.7 km', code: 'NORTHFIT', desc: 'A complimentary basic bike fit and setup check.'),
  ];
}

/// Demo type for the profile's category-specific section — matches the
/// PWA's lpRestaurantDemo / lpBeautyDemo / lpFlowerDemo / lpGenericProfile.
enum PartnerDemoKind { restaurant, beauty, flowers, generic }

/// Rich per-partner detail content, ported from the `localPartnerProfiles`
/// + `lpEnhancedProfiles` data objects in local-partners-v142055.html.
/// Backs LocalPartnerDetailScreen. Every partner has a real cover photo
/// (assets/images/partners/<slug>.png) and a real presentation video
/// (assets/video/partners/<slug>-presentation.mp4, except north-cycle
/// which is "-presentation-2"), both bundled 1:1 from the PWA's own
/// assets/card-photos/ and media/ folders.
class LocalPartnerProfile {
  final String slug, name, category, distanceText, description, rating, hours, offer, about;
  final List<String> tags;
  final PartnerDemoKind demo;
  /// Real distinct gallery photos, in display order — when empty (the
  /// default, for every partner except vata-originals so far), the
  /// gallery falls back to showing the single cover photo three ways
  /// (plain/zoomed/darkened) instead.
  final List<String> galleryAssets;
  const LocalPartnerProfile({
    required this.slug,
    required this.name,
    required this.category,
    required this.distanceText,
    required this.description,
    required this.rating,
    required this.hours,
    required this.offer,
    required this.about,
    required this.tags,
    required this.demo,
    this.galleryAssets = const [],
  });

  String get photoAsset => 'assets/images/partners/$slug.png';
  String get videoAsset =>
      'assets/video/partners/${slug == 'north-cycle' ? 'north-cycle-presentation-2' : '$slug-presentation'}.mp4';

  static const Map<String, LocalPartnerProfile> bySlug = {
    'urban-bistro': LocalPartnerProfile(slug: 'urban-bistro', name: 'Urban Bistro', category: 'Restaurant', distanceText: '0.3 km', description: 'A modern neighbourhood restaurant focused on seasonal ingredients and relaxed city dining.', rating: '4.8 ★', hours: '09:00–22:00', offer: '10% off today', about: 'A modern neighbourhood restaurant for seasonal dishes, relaxed city dining and quick local offers.', tags: ['Seasonal menu', 'Outdoor seating', 'Local favourite'], demo: PartnerDemoKind.restaurant),
    'bloom-boutique': LocalPartnerProfile(slug: 'bloom-boutique', name: 'Bloom Boutique', category: 'Flower Shop', distanceText: '0.4 km', description: 'Fresh seasonal bouquets and floral arrangements for everyday moments and special occasions.', rating: '4.7 ★', hours: '08:30–18:00', offer: 'Free local delivery today', about: 'A local flower boutique creating fresh bouquets, gifts and same-day neighbourhood delivery.', tags: ['Fresh flowers', 'Local delivery', 'Custom bouquets'], demo: PartnerDemoKind.flowers),
    'glam-studio': LocalPartnerProfile(slug: 'glam-studio', name: 'Glam Studio', category: 'Beauty Salon', distanceText: '0.2 km', description: 'A contemporary beauty studio offering styling, colour and express beauty services.', rating: '4.9 ★', hours: '10:00–19:00', offer: 'Free styling consultation', about: 'A contemporary beauty studio offering styling, consultations and express appointments.', tags: ['Appointments', 'New clients', 'Beauty services'], demo: PartnerDemoKind.beauty),
    'cafe-bellissimo': LocalPartnerProfile(slug: 'cafe-bellissimo', name: 'Café Bellissimo', category: 'Coffee & Pastries', distanceText: '0.3 km', description: 'A warm neighbourhood café serving speciality coffee, fresh pastries and relaxed city moments.', rating: '4.8 ★', hours: '07:30–19:00', offer: 'Coffee & pastry pairing today', about: 'Speciality coffee, fresh pastries and a welcoming stop for a quick break near BenchPad.', tags: ['Speciality coffee', 'Breakfast', 'Takeaway'], demo: PartnerDemoKind.generic),
    'grill-house': LocalPartnerProfile(slug: 'grill-house', name: 'Grill House', category: 'Grill Restaurant', distanceText: '0.5 km', description: 'Flame-grilled dishes, generous portions and a relaxed neighbourhood atmosphere.', rating: '4.7 ★', hours: '12:00–23:00', offer: 'Grill special today', about: 'Flame-grilled favourites, generous portions and casual neighbourhood dining.', tags: ['Grill', 'Dinner', 'Takeaway'], demo: PartnerDemoKind.restaurant),
    'vata-originals': LocalPartnerProfile(slug: 'vata-originals', name: 'VATA Originals', category: 'Fashion Store', distanceText: '0.5 km', description: 'A contemporary fashion store offering considered essentials, natural fabrics and quietly confident everyday pieces.', rating: '4.8 ★', hours: '10:00–19:00', offer: 'New season essentials in store', about: 'A contemporary fashion store with natural fabrics, considered essentials and a calm, personal shopping experience.', tags: ['Natural fabrics', 'New season', 'Personal service'], demo: PartnerDemoKind.generic, galleryAssets: ['assets/images/partners/vata-originals-1.jpg', 'assets/images/partners/vata-originals-2.jpg', 'assets/images/partners/vata-originals-3.jpg']),
    'bulko-toys': LocalPartnerProfile(slug: 'bulko-toys', name: 'Bulko Toys', category: 'Soft Toy Store', distanceText: '0.4 km', description: 'A cheerful soft toy store filled with plush characters, cuddly friends and gifts for children of all ages.', rating: '4.9 ★', hours: '10:00–18:00', offer: 'Meet Bulko in store', about: 'A cheerful soft toy store with a friendly fluffy mascot, cuddly plush characters and gifts for every age.', tags: ['Plush toys', 'Gifts', 'Family friendly'], demo: PartnerDemoKind.generic),
    'velvet-boutique': LocalPartnerProfile(slug: 'velvet-boutique', name: 'Velvet Boutique', category: 'Fashion Boutique', distanceText: '0.6 km', description: 'Curated fashion, accessories and contemporary pieces in a warm boutique setting.', rating: '4.8 ★', hours: '10:00–19:00', offer: 'New collection in store', about: 'A curated fashion boutique featuring seasonal collections and local style discoveries.', tags: ['Fashion', 'New collection', 'Personal service'], demo: PartnerDemoKind.generic),
    'studio-noord': LocalPartnerProfile(slug: 'studio-noord', name: 'Studio Noord', category: 'Photo Studio', distanceText: '0.6 km', description: 'A professional photography studio for portraits, products and creative productions.', rating: '4.9 ★', hours: '09:00–18:00', offer: 'Portrait session consultation', about: 'A professional photography studio for portraits, products and creative productions.', tags: ['Photography', 'Portraits', 'Product shoots'], demo: PartnerDemoKind.generic),
    'atelier-flora': LocalPartnerProfile(slug: 'atelier-flora', name: 'Atelier Flora', category: 'Fashion Atelier', distanceText: '0.4 km', description: 'A local atelier creating tailored garments, alterations and custom pieces.', rating: '4.8 ★', hours: '10:00–18:00', offer: 'Fitting consultation available', about: 'A small creative atelier with floral design, gifts and handcrafted seasonal pieces.', tags: ['Handmade', 'Floral design', 'Gifts'], demo: PartnerDemoKind.generic),
    'morning-bakehouse': LocalPartnerProfile(slug: 'morning-bakehouse', name: 'Morning Bakehouse', category: 'Bakery', distanceText: '0.5 km', description: 'Fresh bread, croissants and pastries baked daily for the neighbourhood.', rating: '4.9 ★', hours: '07:00–17:00', offer: 'Fresh morning selection', about: 'Fresh bread and pastries baked for the neighbourhood every morning.', tags: ['Fresh daily', 'Breakfast', 'Bakery'], demo: PartnerDemoKind.generic),
    'harbor-sushi': LocalPartnerProfile(slug: 'harbor-sushi', name: 'Harbor Sushi', category: 'Sushi Restaurant', distanceText: '0.8 km', description: 'Fresh sushi, sashimi and Japanese favourites prepared to order.', rating: '4.7 ★', hours: '12:00–22:00', offer: "Chef's selection today", about: 'Freshly prepared sushi and rotating chef selections for lunch and dinner.', tags: ['Fresh daily', 'Chef selection', 'Dinner'], demo: PartnerDemoKind.restaurant),
    'luna-nails': LocalPartnerProfile(slug: 'luna-nails', name: 'Luna Nails', category: 'Nail Studio', distanceText: '0.7 km', description: 'A modern nail studio offering manicures, nail care and polished finishes.', rating: '4.8 ★', hours: '10:00–19:00', offer: 'Express manicure available', about: 'A modern nail studio for express treatments and carefully finished appointments.', tags: ['Manicure', 'Appointments', 'Express service'], demo: PartnerDemoKind.beauty),
    'north-cycle': LocalPartnerProfile(slug: 'north-cycle', name: 'North Cycle', category: 'Cycling Store', distanceText: '0.9 km', description: 'Bikes, cycling apparel and practical gear for city riders and longer journeys.', rating: '4.8 ★', hours: '09:30–18:30', offer: 'Free bike fit check', about: 'Neighbourhood bicycle service for quick checks, maintenance and everyday cycling support.', tags: ['Bike service', 'Repairs', 'Local cycling'], demo: PartnerDemoKind.generic),
    'canal-books': LocalPartnerProfile(slug: 'canal-books', name: 'Canal Books', category: 'Bookshop', distanceText: '1.0 km', description: 'An independent neighbourhood bookshop with carefully selected titles and local favourites.', rating: '4.9 ★', hours: '10:00–19:00', offer: 'Staff picks this week', about: 'An independent bookshop with staff picks, local titles and a calm browsing atmosphere.', tags: ['Independent', 'Staff picks', 'Local titles'], demo: PartnerDemoKind.generic),
    'green-table': LocalPartnerProfile(slug: 'green-table', name: 'Green Table', category: 'Restaurant', distanceText: '0.6 km', description: 'Fresh, colourful dishes with seasonal ingredients and a relaxed local atmosphere.', rating: '4.7 ★', hours: '11:00–21:30', offer: 'Seasonal lunch special', about: 'Fresh, balanced lunch options built around seasonal ingredients and simple food.', tags: ['Healthy lunch', 'Seasonal', 'Vegetarian options'], demo: PartnerDemoKind.restaurant),
    'amber-cuts': LocalPartnerProfile(slug: 'amber-cuts', name: 'Amber Cuts', category: 'Barbershop', distanceText: '0.8 km', description: 'Precision cuts, grooming and classic barber services in a modern setting.', rating: '4.8 ★', hours: '09:00–19:00', offer: 'Walk-ins welcome today', about: 'A neighbourhood grooming studio with walk-in availability and personal service.', tags: ['Walk-ins', 'Grooming', 'Appointments'], demo: PartnerDemoKind.beauty),
    'pixel-repair': LocalPartnerProfile(slug: 'pixel-repair', name: 'Pixel Repair', category: 'Device Repair', distanceText: '0.5 km', description: 'Smartphone and tablet diagnostics, repairs and practical technical support.', rating: '4.9 ★', hours: '09:30–18:30', offer: 'Free quick diagnostic', about: 'Fast local support for phones and everyday devices, including quick diagnostics.', tags: ['Device repair', 'Diagnostics', 'Local service'], demo: PartnerDemoKind.generic),
    'little-canvas': LocalPartnerProfile(slug: 'little-canvas', name: 'Little Canvas', category: 'Art Studio', distanceText: '0.7 km', description: 'A creative local studio for art, workshops and original visual work.', rating: '4.7 ★', hours: '10:00–18:00', offer: 'Workshop places available', about: 'A small creative shop for art, gifts and colourful local discoveries.', tags: ['Art', 'Gifts', 'Independent'], demo: PartnerDemoKind.generic),
    'river-fitness': LocalPartnerProfile(slug: 'river-fitness', name: 'River Fitness', category: 'Fitness Studio', distanceText: '1.1 km', description: 'A local fitness studio focused on practical training, movement and wellbeing.', rating: '4.8 ★', hours: '06:30–22:00', offer: 'Trial session available', about: 'A local fitness space for accessible training, classes and an active community.', tags: ['Fitness', 'Classes', 'Community'], demo: PartnerDemoKind.generic),
  };
}

class DemoPartner {
  final String slug, name, category, distanceText;
  const DemoPartner({required this.slug, required this.name, required this.category, required this.distanceText});

  static const all = [
    DemoPartner(slug: 'urban-bistro', name: 'Urban Bistro', category: 'food', distanceText: '0.3 km'),
    DemoPartner(slug: 'bloom-boutique', name: 'Bloom Boutique', category: 'shopping', distanceText: '0.4 km'),
    DemoPartner(slug: 'glam-studio', name: 'Glam Studio', category: 'beauty', distanceText: '0.2 km'),
    DemoPartner(slug: 'cafe-bellissimo', name: 'Café Bellissimo', category: 'food', distanceText: '0.3 km'),
    DemoPartner(slug: 'grill-house', name: 'Grill House', category: 'food', distanceText: '0.5 km'),
    DemoPartner(slug: 'velvet-boutique', name: 'Velvet Boutique', category: 'shopping', distanceText: '0.6 km'),
    DemoPartner(slug: 'bulko-toys', name: 'Bulko Toys', category: 'shopping', distanceText: '0.4 km'),
    DemoPartner(slug: 'vata-originals', name: 'VATA Originals', category: 'shopping', distanceText: '0.5 km'),
    DemoPartner(slug: 'studio-noord', name: 'Studio Noord', category: 'services', distanceText: '0.7 km'),
    DemoPartner(slug: 'atelier-flora', name: 'Atelier Flora', category: 'shopping', distanceText: '0.5 km'),
    DemoPartner(slug: 'morning-bakehouse', name: 'Morning Bakehouse', category: 'food', distanceText: '0.4 km'),
    DemoPartner(slug: 'harbor-sushi', name: 'Harbor Sushi', category: 'food', distanceText: '0.8 km'),
    DemoPartner(slug: 'luna-nails', name: 'Luna Nails', category: 'beauty', distanceText: '0.5 km'),
    DemoPartner(slug: 'north-cycle', name: 'North Cycle', category: 'services', distanceText: '0.7 km'),
    DemoPartner(slug: 'canal-books', name: 'Canal Books', category: 'shopping', distanceText: '0.6 km'),
    DemoPartner(slug: 'green-table', name: 'Green Table', category: 'food', distanceText: '0.6 km'),
    DemoPartner(slug: 'amber-cuts', name: 'Amber Cuts', category: 'beauty', distanceText: '0.7 km'),
    DemoPartner(slug: 'pixel-repair', name: 'Pixel Repair', category: 'services', distanceText: '0.4 km'),
    DemoPartner(slug: 'little-canvas', name: 'Little Canvas', category: 'shopping', distanceText: '0.9 km'),
    DemoPartner(slug: 'river-fitness', name: 'River Fitness', category: 'services', distanceText: '0.8 km'),
  ];
}
