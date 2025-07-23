import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class LocationService {
  static Future<void> requestLocationPermission() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
      }
      if (!status.isGranted) {
        throw Exception('Location permission denied');
      }
    }
  }

  static Future<Position> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static bool isNearPSU(Position position, {double radiusMeters = 2000}) {
    const double psuLat = 45.5152;
    const double psuLng = -122.6784;

    double distance = Geolocator.distanceBetween(
      psuLat, psuLng,
      position.latitude,
      position.longitude,
    );
    return distance <= radiusMeters;
  }
}
