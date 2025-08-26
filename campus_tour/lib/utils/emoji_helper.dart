class EmojiHelper {
  static String emojiForName(String name) {
    final lower = name.toLowerCase().trim();
    const Map<String, String> explicit = {
      'central plaza': '🏬',
      'engineering building': '🛠️',
      'fariborz maseeh hall': '🏫',
      'karl miller center': '🏢',
      'lovejoy fountain': '⛲️',
      'montgomery & broadway': '🚦',
      'park': '🌳',
      'psu scott center': '🏟️',
      'shattuck hall annex': '🎨',
      'test hotspot small': '🧪',
      'test hotspot big': '🧫',
    };
    final custom = explicit[lower];
    if (custom != null) return custom;

    if (lower.contains('library')) return '📚';
    if (lower.contains('parking')) return '🚗';
    if (lower.contains('fountain')) return '⛲️';
    if (lower.contains('hall')) return '🏫';
    if (lower.contains('center') || lower.contains('pavilion') || lower.contains('arena')) return '🏟️';
    if (lower.contains('park')) return '🌳';
    if (lower.contains('test')) return '🧪';
    return '📍';
  }

  static String labelForName(String name) {
    final lower = name.trim().toLowerCase();
    const Map<String, String> overrides = {
      'park': 'Park',
      'central plaza': 'Plaza',
    };
    final custom = overrides[lower];
    if (custom != null) return custom;

    final parts = name.trim().split(RegExp(r"\s+"));
    final letters = parts
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .join();
    return letters.toUpperCase();
  }
}


