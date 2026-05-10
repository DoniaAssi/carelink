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

  /// Express API, e.g. `http://localhost:3000`.
  static String get origin {
    try {
      if (kIsWeb) {
        return 'http://localhost:3000';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return 'http://10.0.2.2:3000';
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
          return 'http://10.0.2.2:8000/api';
        default:
          return 'http://localhost:8000/api';
      }
    } catch (_) {
      return 'http://localhost:8000/api';
    }
  }
}
