import 'package:flutter/material.dart';

/// A real, colorful weather emoji (Twemoji, CC-BY 4.0) bundled as an
/// image asset — used instead of the system emoji font glyph, which
/// rendered too pale (a near-invisible light-gray cloud) on some
/// devices and can't be recolored, and instead of a hand-drawn icon,
/// per request for something that just looks nice out of the box.
class WeatherIcon extends StatelessWidget {
  final String conditionKey;
  final double size;

  const WeatherIcon({super.key, required this.conditionKey, this.size = 36});

  static const _assetByKey = {
    'clear': 'assets/images/weather/clear.png',
    'partly': 'assets/images/weather/partly.png',
    'cloudy': 'assets/images/weather/cloudy.png',
    'fog': 'assets/images/weather/fog.png',
    'rain': 'assets/images/weather/rain.png',
    'snow': 'assets/images/weather/snow.png',
    'storm': 'assets/images/weather/storm.png',
    'clear_night': 'assets/images/weather/clear_night.png',
    'partly_night': 'assets/images/weather/partly_night.png',
    'cloudy_night': 'assets/images/weather/cloudy_night.png',
    'fog_night': 'assets/images/weather/fog_night.png',
    'rain_night': 'assets/images/weather/rain_night.png',
    'snow_night': 'assets/images/weather/snow_night.png',
    'storm_night': 'assets/images/weather/storm_night.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assetByKey[conditionKey] ?? _assetByKey['cloudy']!;
    return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }
}
