import 'package:flutter/material.dart';
import 'package:ar_location_view/ar_location_view.dart';
import 'hotspot.dart';
import 'package:geolocator/geolocator.dart';
import '../helpers/hotspot_helpers.dart';

/// Wraps a Hotspot as an ArAnnotation for use in ARLocationWidget
class HotspotAnnotation extends ArAnnotation {
  final Hotspot hotspot;

  HotspotAnnotation({required this.hotspot})
      : super(
          uid: hotspot.hotspotId,
          position: Position(
            latitude: hotspot.location.latitude,
            longitude: hotspot.location.longitude,
            altitude: 0,
            altitudeAccuracy: 0,
            accuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
            timestamp: DateTime.now(),
          ),
        );
}

/// Widget to render a HotspotAnnotation in AR
class HotspotAnnotationView extends StatelessWidget {
  final HotspotAnnotation annotation;

  const HotspotAnnotationView({super.key, required this.annotation});

  @override
  Widget build(BuildContext context) {
    final hotspot = annotation.hotspot;
    final distance = annotation.distanceFromUser.toInt();
    final feature = hotspot.getARIconFeature();
    final assetPath = feature?.fileLocation;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetPath != null)
          Image.asset(
            assetPath,
            width: 50,
            height: 50,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported),
          )
        else
          const Icon(Icons.place, size: 50, color: Colors.blue),
        Card(
          color: Colors.white.withOpacity(0.9),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              children: [
                Text(
                  hotspot.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('$distance m'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
