import 'package:flutter/foundation.dart';

class AppConfig {
  // Physical device: flutter run --dart-define=API_BASE_URL=http://<your-LAN-IP>:8080
  // Emulator:        no flag needed (auto-uses 10.0.2.2)
  // Web/desktop:     no flag needed (auto-uses localhost)
  static const _envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    // Android emulator reaches the host machine via the special alias 10.0.2.2.
    // Physical devices need API_BASE_URL set to the host machine's LAN IP.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');

  static const defaultCity = 'Kampala';

  // Location
  static const locationAccuracyThresholdMeters = 500.0;
  static const citySwitchPingsRequired = 3;
  static const locationUpdateIntervalSecs = 300; // 5 min background

  // Feed
  static const defaultFeedRadiusMeters = 2000;
  static const feedCacheTtlMinutes = 5;

  // Pagination
  static const pageSize = 20;
}
