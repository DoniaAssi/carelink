class FavoriteProvidersService {
  /// Returns a set of provider ids favorited by the user.
  static Future<Set<String>> getIds(String? userId) async {
    if (userId == null) return <String>{};
    // Placeholder implementation: return empty set. Replace with real storage lookup.
    return <String>{};
  }

  static Future<bool> isFavorite(String? userId, String providerId) async {
    return false;
  }

  static Future<bool> toggle(String? userId, String providerId) async {
    return false;
  }
}
