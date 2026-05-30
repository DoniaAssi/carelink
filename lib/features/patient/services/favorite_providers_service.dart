import 'package:shared_preferences/shared_preferences.dart';

// TODO(Backend): When a favorites API exists (e.g. GET/POST /api/patients/:id/favorites),
// sync [toggle] and [getIds] with the server; keep local cache as offline fallback.
/// Persists favorite provider `userId`s per patient (or guest).
class FavoriteProvidersService {
  FavoriteProvidersService._();

  static String _key(String? patientUserId) {
    final id = (patientUserId ?? '').trim();
    return 'favorite_provider_ids_${id.isEmpty ? 'guest' : id}';
  }

  static Future<Set<String>> getIds(String? patientUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(patientUserId)) ?? <String>[];
    return raw.toSet();
  }

  static Future<bool> isFavorite(
    String? patientUserId,
    String providerUserId,
  ) async {
    final ids = await getIds(patientUserId);
    return ids.contains(providerUserId);
  }

  /// Returns the new favorite state (true = now favorited).
  static Future<bool> toggle(
    String? patientUserId,
    String providerUserId,
  ) async {
    final id = providerUserId.trim();
    if (id.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final key = _key(patientUserId);
    final set = (prefs.getStringList(key) ?? <String>[]).toSet();
    final wasFavorite = set.contains(id);
    if (wasFavorite) {
      set.remove(id);
    } else {
      set.add(id);
    }
    await prefs.setStringList(key, set.toList());
    return !wasFavorite;
  }
}
