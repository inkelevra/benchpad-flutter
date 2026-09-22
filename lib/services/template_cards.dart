import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

/// Thrown when a template can't be produced (mirrors the status text
/// shown next to the quick-template buttons in advertise.html).
class TemplateCardException implements Exception {
  final String message;
  TemplateCardException(this.message);
  @override
  String toString() => message;
}

/// One "Follow us" platform for the Social template — label, emoji icon,
/// and the canonical profile URL built from a sanitized handle. The URL
/// is always code-built, never typed by the user, matching the PWA's
/// social-card safety property.
class SocialPlatform {
  final String label;
  final String icon;
  final String Function(String handle) urlBuilder;
  const SocialPlatform(this.label, this.icon, this.urlBuilder);
}

class _CultureCandidate {
  final String url, title, artist, date;
  _CultureCandidate(this.url, this.title, this.artist, this.date);
}

class _WeatherIcon {
  final String key, label;
  _WeatherIcon(this.key, this.label);
}

/// Ported from advertise.html's Weather / Culture / Quote / Social quick
/// templates. Each render method produces a 1600x1200 PNG (matching the
/// physical e-ink panel's resolution) as bytes ready to base64-encode
/// into a "data:image/png;base64,..." data URL for BenchpadApi.publish.
/// No CORS proxy is needed here (unlike the PWA's /api/image-proxy)
/// since native HTTP requests aren't subject to browser CORS rules.
class TemplateCards {
  TemplateCards._();

  static const int _w = 1600, _h = 1200;

  // ---------------------------------------------------------------------
  // Weather — live conditions from Open-Meteo (no key needed), rendered
  // as a hand-drawn icon card so it never depends on an external image.
  // ---------------------------------------------------------------------

  static Future<Uint8List> weather() async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=52.3676&longitude=4.9041&current=temperature_2m,weathercode&timezone=Europe%2FAmsterdam'));
    } catch (_) {
      throw TemplateCardException('Could not load live weather right now — try again in a moment.');
    }
    if (res.statusCode != 200) {
      throw TemplateCardException('Could not load live weather right now — try again in a moment.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;
    final temp = (current['temperature_2m'] as num).round();
    final code = (current['weathercode'] as num).toInt();
    final icon = _weathercodeToIcon(code);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    await _drawWeatherCard(canvas, temp, icon.label, icon.key);
    return _finish(recorder);
  }

  static _WeatherIcon _weathercodeToIcon(int code) {
    if (code == 0) return _WeatherIcon('clear', 'Clear sky');
    if (code == 1 || code == 2) return _WeatherIcon('partly', 'Partly cloudy');
    if (code == 3) return _WeatherIcon('cloudy', 'Cloudy');
    if (code == 45 || code == 48) return _WeatherIcon('fog', 'Fog');
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) {
      return _WeatherIcon('rain', 'Rain');
    }
    if ([71, 73, 75, 77, 85, 86].contains(code)) return _WeatherIcon('snow', 'Snow');
    if ([95, 96, 99].contains(code)) return _WeatherIcon('storm', 'Thunderstorm');
    return _WeatherIcon('cloudy', 'Cloudy');
  }

  static Future<void> _drawWeatherCard(Canvas canvas, int temp, String label, String iconKey) async {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEEF5F8), Color(0xFFDBE6EA)],
      ).createShader(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()));
    canvas.drawRect(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()), bg);

    // Same real icon set as the Home weather widget (Magnific.com,
    // licensed — see Credits), instead of the earlier hand-drawn one.
    final iconImage = await _loadIconAsset('assets/images/weather/$iconKey.png');
    if (iconImage != null) {
      const targetSize = 340.0;
      final iconScale = targetSize / max(iconImage.width, iconImage.height);
      final dw = iconImage.width * iconScale, dh = iconImage.height * iconScale;
      final dst = Rect.fromCenter(center: const Offset(800, 400), width: dw, height: dh);
      canvas.drawImageRect(iconImage, Rect.fromLTWH(0, 0, iconImage.width.toDouble(), iconImage.height.toDouble()), dst, Paint());
    } else {
      _drawWeatherIcon(canvas, iconKey, const Offset(800, 400), 300);
    }

    _text(canvas, '$temp°C', 800, 830, fontSize: 260, weight: FontWeight.w900, color: const Color(0xFF12222A));
    _text(canvas, label, 800, 1010, fontSize: 92, weight: FontWeight.w800, color: const Color(0xFF3C5560));
    _text(canvas, 'Amsterdam', 800, 1100, fontSize: 56, weight: FontWeight.w700, color: const Color(0xFF6C848D));
  }

  static Future<ui.Image?> _loadIconAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// Simplified equivalent of drawWeatherIcon() in advertise.html — the
  /// cloud is built from overlapping circles + a base pill instead of
  /// exactly replicating Canvas2D's connected-arc path (Flutter's
  /// Path.addArc doesn't auto-connect subpaths the way repeated
  /// ctx.arc() calls do). Same silhouette, same palette.
  static void _drawWeatherIcon(Canvas canvas, String key, Offset center, double r) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    const sunColor = Color(0xFFE8A33D);
    const cloudFill = Color(0xFFEEF3F6);
    const cloudStroke = Color(0xFF2C3E46);
    const rainColor = Color(0xFF3F7FC0);
    const snowColor = Color(0xFFC7D6DD);

    void sun(double scale) {
      final fill = Paint()..color = sunColor;
      canvas.drawCircle(Offset.zero, r * 0.42 * scale, fill);
      final ray = Paint()
        ..color = sunColor
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4;
        canvas.drawLine(
          Offset(cos(a) * r * 0.6 * scale, sin(a) * r * 0.6 * scale),
          Offset(cos(a) * r * 0.85 * scale, sin(a) * r * 0.85 * scale),
          ray,
        );
      }
    }

    void cloud(Offset offset, double scale) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.scale(scale, scale);
      final path = Path()
        ..addOval(Rect.fromCircle(center: Offset(-r * 0.32, r * 0.06), radius: r * 0.32))
        ..addOval(Rect.fromCircle(center: Offset(-r * 0.02, -r * 0.18), radius: r * 0.28))
        ..addOval(Rect.fromCircle(center: Offset(r * 0.32, r * 0.02), radius: r * 0.34))
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(-r * 0.5, -r * 0.02, r, r * 0.42),
          Radius.circular(r * 0.2),
        ));
      final fill = Paint()..color = cloudFill;
      final stroke = Paint()
        ..color = cloudStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
      canvas.restore();
    }

    void raindrops() {
      final p = Paint()
        ..color = rainColor
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final x = -r * 0.34 + i * r * 0.34;
        canvas.drawLine(Offset(x, r * 0.42), Offset(x - r * 0.08, r * 0.62), p);
      }
    }

    void snowflakes() {
      final p = Paint()..color = snowColor;
      for (var i = 0; i < 3; i++) {
        final x = -r * 0.34 + i * r * 0.34;
        canvas.drawCircle(Offset(x, r * 0.5), r * 0.06, p);
      }
    }

    void bolt() {
      final p = Paint()..color = const Color(0xFFE8B93D);
      final path = Path()
        ..moveTo(r * 0.08, r * 0.28)
        ..lineTo(-r * 0.12, r * 0.62)
        ..lineTo(r * 0.02, r * 0.62)
        ..lineTo(-r * 0.1, r * 0.92)
        ..lineTo(r * 0.24, r * 0.5)
        ..lineTo(r * 0.06, r * 0.5)
        ..close();
      canvas.drawPath(path, p);
    }

    void fogLines() {
      final p = Paint()
        ..color = cloudStroke.withOpacity(0.55)
        ..strokeWidth = r * 0.06;
      for (final dy in [-0.15, 0.05, 0.25]) {
        canvas.drawLine(Offset(-r * 0.5, r * dy), Offset(r * 0.5, r * dy), p);
      }
    }

    switch (key) {
      case 'clear':
        sun(1);
        break;
      case 'partly':
        sun(0.7);
        cloud(Offset(r * 0.08, r * 0.14), 1);
        break;
      case 'cloudy':
        cloud(Offset.zero, 1.15);
        break;
      case 'rain':
        cloud(Offset(0, -r * 0.12), 1);
        raindrops();
        break;
      case 'snow':
        cloud(Offset(0, -r * 0.12), 1);
        snowflakes();
        break;
      case 'storm':
        cloud(Offset(0, -r * 0.12), 1);
        bolt();
        break;
      case 'fog':
        cloud(Offset(0, -r * 0.18), 0.9);
        fogLines();
        break;
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------------
  // Culture — a real public-domain / open-access artwork from three
  // keyless museum APIs (Met — Modern Art; Art Institute of Chicago —
  // Modern/Contemporary; Cleveland Museum of Art — Open Access CC0),
  // biased toward Picsum photography since the museum sources fail
  // often (modern/contemporary work is rarely truly public-domain).
  // ---------------------------------------------------------------------

  static const _metDepartments = [21]; // Modern Art

  static Future<_CultureCandidate?> _fetchFromMet() async {
    try {
      final dept = _metDepartments[Random().nextInt(_metDepartments.length)];
      final searchRes = await http.get(Uri.parse(
          'https://collectionapi.metmuseum.org/public/collection/v1/search?hasImages=true&departmentId=$dept&q=*'));
      if (searchRes.statusCode != 200) return null;
      final searchData = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final ids = (searchData['objectIDs'] as List?)?.cast<dynamic>() ?? [];
      if (ids.isEmpty) return null;
      final id = ids[Random().nextInt(ids.length)];
      final objRes = await http
          .get(Uri.parse('https://collectionapi.metmuseum.org/public/collection/v1/objects/$id'));
      if (objRes.statusCode != 200) return null;
      final obj = jsonDecode(objRes.body) as Map<String, dynamic>;
      final image = obj['primaryImage'] as String?;
      if (obj['isPublicDomain'] != true || image == null || image.isEmpty) return null;
      return _CultureCandidate(
        image,
        (obj['title'] as String?)?.isNotEmpty == true ? obj['title'] : 'Untitled',
        (obj['artistDisplayName'] as String?) ?? '',
        (obj['objectDate'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static const _aicDepartments = ['Modern Art', 'Contemporary Art'];

  static Future<_CultureCandidate?> _fetchFromArtInstitute() async {
    try {
      final dept = _aicDepartments[Random().nextInt(_aicDepartments.length)];
      final uri = Uri.parse(
          'https://api.artic.edu/api/v1/artworks/search?query[term][department_title]=${Uri.encodeComponent(dept)}&fields=id,title,artist_display,date_display,image_id,is_public_domain&limit=100');
      final searchRes = await http.get(uri);
      if (searchRes.statusCode != 200) return null;
      final searchData = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final list = (searchData['data'] as List?) ?? [];
      final candidates = list
          .cast<Map<String, dynamic>>()
          .where((d) => d['image_id'] != null && d['is_public_domain'] == true)
          .toList();
      if (candidates.isEmpty) return null;
      final obj = candidates[Random().nextInt(candidates.length)];
      final imageId = obj['image_id'];
      return _CultureCandidate(
        'https://www.artic.edu/iiif/2/$imageId/full/1200,/0/default.jpg',
        (obj['title'] as String?)?.isNotEmpty == true ? obj['title'] : 'Untitled',
        (obj['artist_display'] as String?) ?? '',
        (obj['date_display'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static const _cmaDepartments = ['Contemporary Art', 'Modern European Painting and Sculpture'];

  static Future<_CultureCandidate?> _fetchFromCleveland() async {
    try {
      final dept = _cmaDepartments[Random().nextInt(_cmaDepartments.length)];
      final uri = Uri.parse(
          'https://openaccess-api.clevelandart.org/api/artworks/?department=${Uri.encodeComponent(dept)}&has_image=1&limit=100');
      final searchRes = await http.get(uri);
      if (searchRes.statusCode != 200) return null;
      final searchData = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final list = (searchData['data'] as List?) ?? [];
      final candidates = list.cast<Map<String, dynamic>>().where((d) {
        final images = d['images'] as Map<String, dynamic>?;
        final hasImg = (images?['web']?['url'] ?? images?['print']?['url']) != null;
        return d['share_license_status'] == 'CC0' && hasImg;
      }).toList();
      if (candidates.isEmpty) return null;
      final obj = candidates[Random().nextInt(candidates.length)];
      final images = obj['images'] as Map<String, dynamic>?;
      final url = (images?['web']?['url'] ?? images?['print']?['url']) as String;
      final creators = (obj['creators'] as List?) ?? [];
      final artist = creators
          .cast<Map<String, dynamic>>()
          .map((c) => c['description'] as String?)
          .where((d) => d != null && d.isNotEmpty)
          .join(', ');
      return _CultureCandidate(
        url,
        (obj['title'] as String?)?.isNotEmpty == true ? obj['title'] : 'Untitled',
        artist,
        (obj['creation_date'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<_CultureCandidate?> _fetchFromPicsum() async {
    try {
      final page = Random().nextInt(10) + 1; // ~1000-photo pool across 10 pages
      final res = await http.get(Uri.parse('https://picsum.photos/v2/list?page=$page&limit=100'));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List?;
      if (list == null || list.isEmpty) return null;
      final item = list[Random().nextInt(list.length)] as Map<String, dynamic>;
      final id = item['id'];
      if (id == null) return null;
      return _CultureCandidate('https://picsum.photos/id/$id/1600/1200', '', (item['author'] as String?) ?? '', '');
    } catch (_) {
      return null;
    }
  }

  static final List<Future<_CultureCandidate?> Function()> _cultureSources = [
    _fetchFromPicsum,
    _fetchFromPicsum,
    _fetchFromPicsum,
    _fetchFromMet,
    _fetchFromArtInstitute,
    _fetchFromCleveland,
  ];

  static Future<Uint8List> culture() async {
    ui.Image? img;
    _CultureCandidate? found;
    // Up to 6 attempts, each with a fresh candidate — covers both "no
    // usable candidate" and "candidate found but its image failed to
    // load" without surfacing an error unless every attempt is spent.
    for (var attempt = 0; attempt < 6 && img == null; attempt++) {
      final source = _cultureSources[Random().nextInt(_cultureSources.length)];
      _CultureCandidate? candidate;
      try {
        candidate = await source();
      } catch (_) {
        candidate = null;
      }
      if (candidate == null) continue;
      try {
        img = await _loadNetworkImage(candidate.url);
        found = candidate;
      } catch (_) {
        img = null;
      }
    }
    if (img == null || found == null) {
      throw TemplateCardException('Could not find an artwork right now — try again in a moment.');
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawCultureCard(canvas, img, found.title, found.artist, found.date);
    return _finish(recorder);
  }

  static void _drawCultureCard(Canvas canvas, ui.Image img, String title, String artist, String date) {
    const capH = 92.0;
    final artH = _h - capH;
    canvas.drawRect(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()), Paint()..color = const Color(0xFF0D1A22));
    final scale = max(_w / img.width, artH / img.height);
    final dw = img.width * scale, dh = img.height * scale;
    final dx = (_w - dw) / 2, dy = (artH - dh) / 2;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(dx, dy, dw, dh),
      Paint(),
    );
    canvas.drawRect(Rect.fromLTWH(0, artH, _w.toDouble(), capH), Paint()..color = const Color(0xFFF4F1E9));

    var caption = title;
    if (artist.isNotEmpty) caption += title.isNotEmpty ? ' — $artist' : 'Photo by $artist';
    if (date.isNotEmpty) caption += ', $date';
    if (caption.isEmpty) caption = 'Photograph';

    double fontSize = 30;
    TextPainter tp;
    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: caption,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: const Color(0xFF2A2016)),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 1520);
      if (tp.width <= 1520 || fontSize <= 16) break;
      fontSize -= 1;
    }
    tp.paint(canvas, Offset((_w - tp.width) / 2, artH + capH / 2 - tp.height / 2));
  }

  // ---------------------------------------------------------------------
  // Quote — a real quote (ZenQuotes, with a small built-in fallback list)
  // over a random photo (Picsum), composed the same way as Culture.
  // ---------------------------------------------------------------------

  static const List<Map<String, String>> _quoteFallbacks = [
    {
      'q':
          'A city is not gauged by its length and width, but by the broadness of its vision and the height of its dreams.',
      'a': 'Herb Caen'
    },
    {'q': "Public space is the mirror of a city's soul.", 'a': 'Jan Gehl'},
    {'q': 'We shape our buildings; thereafter they shape us.', 'a': 'Winston Churchill'},
    {'q': 'The best way to find yourself is to lose yourself in the service of others.', 'a': 'Mahatma Gandhi'},
    {'q': 'Small acts, when multiplied by millions of people, can transform the world.', 'a': 'Howard Zinn'},
    {'q': 'A bench is a small act of hospitality a city offers to a stranger.', 'a': 'Unknown'},
    {'q': 'Simplicity is the ultimate sophistication.', 'a': 'Leonardo da Vinci'},
    {'q': 'Life is what happens on the way between destinations.', 'a': 'Unknown'},
    {
      'q':
          'Community is much more than belonging to something; it is about doing something together that makes belonging matter.',
      'a': 'Brian Solis'
    },
    {'q': 'The city is not a concrete jungle, it is a human zoo.', 'a': 'Desmond Morris'},
  ];

  static Future<Map<String, String>> _fetchQuote() async {
    try {
      final res = await http.get(Uri.parse('https://zenquotes.io/api/random'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty && (data[0]['q'] as String?)?.isNotEmpty == true) {
          return {'q': data[0]['q'] as String, 'a': (data[0]['a'] as String?) ?? 'Unknown'};
        }
      }
    } catch (_) {
      // fall through to the built-in list
    }
    return _quoteFallbacks[Random().nextInt(_quoteFallbacks.length)];
  }

  static Future<Uint8List> quote() async {
    final quote = await _fetchQuote();
    ui.Image img;
    try {
      img = await _loadNetworkImage('https://picsum.photos/1600/1200?random=${DateTime.now().millisecondsSinceEpoch}');
    } catch (_) {
      throw TemplateCardException('Could not load a background photo — try again.');
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawQuoteCard(canvas, img, quote['q']!, quote['a']!);
    return _finish(recorder);
  }

  static void _drawQuoteCard(Canvas canvas, ui.Image img, String quoteText, String author) {
    final scale = max(_w / img.width, _h / img.height);
    final dw = img.width * scale, dh = img.height * scale;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH((_w - dw) / 2, (_h - dh) / 2, dw, dh),
      Paint(),
    );

    final gradPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x26040A10), Color(0x8C040A10), Color(0xD1040A10)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()));
    canvas.drawRect(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()), gradPaint);

    double fontSize = 64;
    TextPainter tp;
    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: '"$quoteText"',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 1280);
      final lineCount = tp.computeLineMetrics().length;
      if (lineCount <= 5 || fontSize <= 34) break;
      fontSize -= 4;
    }
    final ty = _h - 160 - tp.height;
    tp.paint(canvas, Offset(800 - tp.width / 2, ty));

    final authorTp = TextPainter(
      text: TextSpan(
        text: '— $author',
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: Color(0xFFD8E4EA)),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 1280);
    authorTp.paint(canvas, Offset(800 - authorTp.width / 2, _h - 90 - authorTp.height * 0.7));
  }

  // ---------------------------------------------------------------------
  // Social — "Follow us" card with a QR to a canonical, code-built
  // profile URL (never a URL the person typed).
  // ---------------------------------------------------------------------

  static String _instagramUrl(String h) => 'https://instagram.com/$h';
  static String _tiktokUrl(String h) => 'https://tiktok.com/@$h';
  static String _xUrl(String h) => 'https://x.com/$h';
  static String _facebookUrl(String h) => 'https://facebook.com/$h';
  static String _pinterestUrl(String h) => 'https://pinterest.com/$h';
  static String _youtubeUrl(String h) => 'https://youtube.com/@$h';
  static String _threadsUrl(String h) => 'https://threads.net/@$h';
  static String _snapchatUrl(String h) => 'https://snapchat.com/add/$h';

  static final Map<String, SocialPlatform> socialPlatforms = {
    'instagram': SocialPlatform('Instagram', '📷', _instagramUrl),
    'tiktok': SocialPlatform('TikTok', '🎵', _tiktokUrl),
    'x': SocialPlatform('X', '✕', _xUrl),
    'facebook': SocialPlatform('Facebook', '📘', _facebookUrl),
    'pinterest': SocialPlatform('Pinterest', '📌', _pinterestUrl),
    'youtube': SocialPlatform('YouTube', '▶️', _youtubeUrl),
    'threads': SocialPlatform('Threads', '@', _threadsUrl),
    'snapchat': SocialPlatform('Snapchat', '👻', _snapchatUrl),
  };

  /// Handle can only contain letters, numbers, dots, underscores and
  /// dashes — same rule as socialCardHandle in advertise.html.
  static final RegExp handlePattern = RegExp(r'^[a-zA-Z0-9._-]{1,30}$');

  static Future<Uint8List> social({required String platformKey, required String handle}) async {
    final platform = socialPlatforms[platformKey]!;
    final profileUrl = platform.urlBuilder(handle);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF7F3EA), Color(0xFFECE4D2)],
      ).createShader(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()));
    canvas.drawRect(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()), bg);

    _text(canvas, platform.icon, 800, 270, fontSize: 140, weight: FontWeight.normal, color: Colors.black, fontFamily: null);
    _text(canvas, 'Follow us on ${platform.label}', 800, 380,
        fontSize: 68, weight: FontWeight.w900, color: const Color(0xFF2A2016));
    _text(canvas, '@$handle', 800, 450, fontSize: 56, weight: FontWeight.w700, color: const Color(0xFF5C4F3A));

    canvas.save();
    canvas.translate(520, 500);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 560, 560), Paint()..color = Colors.white);
    final qrPainter = QrPainter(
      data: profileUrl,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF111111),
      emptyColor: const Color(0xFFFFFFFF),
    );
    qrPainter.paint(canvas, const Size(560, 560));
    canvas.restore();

    _text(canvas, 'Scan to follow', 800, 1110, fontSize: 34, weight: FontWeight.w600, color: const Color(0xFF8A7A5C));

    return _finish(recorder);
  }

  // ---------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------

  static Future<ui.Image> _loadNetworkImage(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('image_load_failed');
    final codec = await ui.instantiateImageCodec(res.bodyBytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Draws single-line centered text with a canvas-fillText-style
  /// baseline Y (approximated by shifting up ~0.8*fontSize).
  static void _text(
    Canvas canvas,
    String text,
    double cx,
    double baselineY, {
    required double fontSize,
    required FontWeight weight,
    required Color color,
    String? fontFamily = 'Inter',
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: weight, color: color, fontFamily: fontFamily)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = baselineY - fontSize * 0.8;
    tp.paint(canvas, Offset(cx - tp.width / 2, dy));
  }

  static Future<Uint8List> _finish(ui.PictureRecorder recorder) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(_w, _h);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
