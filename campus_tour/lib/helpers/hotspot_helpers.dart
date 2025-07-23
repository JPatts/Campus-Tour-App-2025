import '../models/hotspot.dart';
import 'package:geolocator/geolocator.dart';
import '../services/hotspot_service.dart';

/// Checks if a hotspot is unlocked for this user
bool isHotspotUnlocked({
  required Hotspot hotspot,
  required Position? userPosition,
  required bool testingMode,
}) {
  if (testingMode) return true;
  if (userPosition == null) return false;

  return HotspotService().isUserInHotspot(
    hotspot,
    userPosition.latitude,
    userPosition.longitude,
  );
}

/// Builds the expected asset path for a feature
String getAssetPath(Hotspot hotspot, HotspotFeature feature) {
  return 'assets/hotspots/${hotspot.hotspotId}/Assets/${feature.fileLocation}';
}

/// Extension to get the first AR model feature from a hotspot
extension HotspotExtensions on Hotspot {
  HotspotFeature? getARModelFeature() {
    try {
      return features.firstWhere(
        (f) =>
            f.type.toLowerCase() == 'model',
      );
    } catch (e) {
      return null;
    }
  }
}
