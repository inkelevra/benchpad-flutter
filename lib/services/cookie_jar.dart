import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal persistent cookie jar. Wraps an inner [http.Client] and
/// transparently:
/// - attaches previously-saved cookies to every outgoing request's
///   Cookie header, and
/// - captures Set-Cookie from every response and merges it into the
///   saved set (last value wins per cookie name), persisting to
///   SharedPreferences so sessions survive app restarts.
///
/// This is intentionally simple — one flat name->value map shared
/// across all hosts the app talks to (just the one BenchPad API host
/// in practice), not a full per-domain/per-path RFC 6265 jar. Good
/// enough for session cookies like the owner-access one; not meant
/// for anything that needs strict cookie scoping.
class PersistentCookieClient extends http.BaseClient {
  PersistentCookieClient(this._inner);

  final http.Client _inner;
  Map<String, String> _cookies = {};
  bool _loaded = false;
  static const _prefsKey = 'benchpad_cookies_v1';

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _cookies = Map<String, String>.from(
          Uri.splitQueryString(raw),
        );
      }
    } catch (_) {
      // best-effort — a fresh/empty jar is a safe fallback
    }
    _loaded = true;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _cookies.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {
      // best-effort — losing a persisted cookie just means re-login next launch
    }
  }

  void _absorbSetCookie(String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.isEmpty) return;
    // A response can set multiple cookies; http's header map joins
    // them with ', ' if the server sends multiple Set-Cookie lines,
    // but each individual cookie's attributes are also comma/semicolon
    // separated, so split conservatively on ", " followed by a
    // token=value pattern rather than every comma.
    final parts = setCookieHeader.split(RegExp(r',(?=\s*[\w-]+=)'));
    for (final part in parts) {
      final firstSegment = part.split(';').first.trim();
      final eq = firstSegment.indexOf('=');
      if (eq <= 0) continue;
      final name = firstSegment.substring(0, eq).trim();
      final value = firstSegment.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      // An empty value (or Max-Age=0 in the full segment) means the
      // server is clearing this cookie — drop it instead of storing "".
      if (value.isEmpty || part.contains('Max-Age=0')) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _ensureLoaded();
    if (_cookies.isNotEmpty) {
      final cookieHeader = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      request.headers['cookie'] = cookieHeader;
    }
    final response = await _inner.send(request);
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      _absorbSetCookie(setCookie);
      unawaited(_save());
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
