import 'package:shared_preferences/shared_preferences.dart';

class VisitedService {
  static const String _keyRealPrefix = 'visited_hotspot_real_';
  static const String _keyFakePrefix = 'visited_hotspot_fake_';

  Future<void> markVisitedReal(String hotspotId, DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyRealPrefix$hotspotId', when.millisecondsSinceEpoch);
  }

  Future<void> markVisitedFake(String hotspotId, DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyFakePrefix$hotspotId', when.millisecondsSinceEpoch);
  }

  Future<DateTime?> getLastVisitedReal(String hotspotId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('$_keyRealPrefix$hotspotId');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<DateTime?> getLastVisitedFake(String hotspotId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('$_keyFakePrefix$hotspotId');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> isVisitedEffective(String hotspotId, {required bool adminModeEnabled}) async {
    final now = DateTime.now();
    // Real visit window: 72h always
    final real = await getLastVisitedReal(hotspotId);
    if (real != null && now.difference(real) < const Duration(hours: 72)) {
      return true;
    }
    // Fake visit window: 10s when not admin; when admin enabled, we already bypass checks
    final fake = await getLastVisitedFake(hotspotId);
    if (fake != null && now.difference(fake) < const Duration(seconds: 10)) {
      return true;
    }
    return false;
  }

  Future<void> clearAllVisits() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final k in keys) {
      if (k.startsWith(_keyRealPrefix) || k.startsWith(_keyFakePrefix)) {
        await prefs.remove(k);
      }
    }
  }
}


