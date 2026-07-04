import 'package:flutter/foundation.dart';

/// CareLink Node/Express API root (`backend/server.js`, default port **3000**).
///
/// Use [origin] for `/auth/...`, `/patient/...`, etc. For Laravel-only routes
/// use [laravelApiRoot] when you run `php artisan serve` on :8000.
///
/// **Web:** ensure `node backend/server.js` (or `npm start`) so Chrome can reach
/// `localhost:3000` (CORS is enabled in Express).
class CarelinkApiConfig {
  CarelinkApiConfig._();

  static const String _machineIp = '192.168.1.15';
  static const bool _useAndroidEmulator = false;

  static const String _envOrigin = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Express API, e.g. `http://localhost:3000`.
  static String get origin {
    try {
      if (_envOrigin.isNotEmpty) {
        return _normalizeRoot(_envOrigin);
      }
      if (kIsWeb) {
        return 'http://localhost:3000';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return _useAndroidEmulator
              ? 'http://10.0.2.2:3000'
              : 'http://$_machineIp:3000';
        case TargetPlatform.iOS:
          return 'http://$_machineIp:3000';
        default:
          return 'http://localhost:3000';
      }
    } catch (_) {
      return 'http://localhost:3000';
    }
  }

  /// Optional Laravel `routes/api.php` base (same host, port 8000).
  static String get laravelApiRoot {
    try {
      if (kIsWeb) {
        return 'http://localhost:8000/api';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return _useAndroidEmulator
              ? 'http://10.0.2.2:8000/api'
              : 'http://$_machineIp:8000/api';
        case TargetPlatform.iOS:
          return 'http://$_machineIp:8000/api';
        default:
          return 'http://localhost:8000/api';
      }
    } catch (_) {
      return 'http://localhost:8000/api';
    }
  }

  static String _normalizeRoot(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
