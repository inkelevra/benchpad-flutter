/// Global app configuration.
///
/// Mirrors the constants that were hardcoded across the PWA's HTML files
/// (e.g. advertise.html used relative fetch() calls like
/// "/api/publish-queue-status" which only worked because the PWA was
/// served from the same origin as the API).
///
/// In the native app there is no "same origin" — every request needs an
/// absolute URL, so it all points here.
class AppConfig {
  AppConfig._();

  /// Base URL of the BenchPad Cloudflare Pages/Workers deployment.
  static const String apiBaseUrl = 'https://benchpad.pages.dev';

  /// Default device id used across the PWA screens (Advertise, publish
  /// status polling, etc). Hardcoded there as "BP-AMS-001" — kept as the
  /// default here too. Move to user-selectable device list later if
  /// BenchPad ever supports multiple physical displays per account.
  static const String defaultDeviceId = 'BP-AMS-001';
}
