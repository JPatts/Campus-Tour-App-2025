import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/hotspot.dart';

class HotspotService {
  static final HotspotService _instance = HotspotService._internal();
  factory HotspotService() => _instance;
  HotspotService._internal();

  List<Hotspot> _hotspots = [];
  bool _isLoaded = false;

  List<Hotspot> get hotspots => _hotspots;
  bool get isLoaded => _isLoaded;

  List<Hotspot> getHostpots(){
    return _hotspots;
  }

  Future<List<Hotspot>> loadHotspots() async {
    if (_isLoaded) {
      return _hotspots;
    }

    try {
      _hotspots = await _loadHotspotsFromAssets();
      _isLoaded = true;
      return _hotspots;
    } catch (e) {
      debugPrint('Error loading hotspots: $e');
      return [];
    }
  }

  Future<List<Hotspot>> _loadHotspotsFromAssets() async {
    List<Hotspot> hotspots = [];
    
    // List of hotspot directories to load
    final List<String> hotspotDirectories = [
      'parkingStructureOne',
      'psuLibrary',
      'psuRecCenter',
      'se117thAve',
      'testHotspotSmall',
      'testHotspotBig',
    ];
    
    for (final directory in hotspotDirectories) {
      try {
        final String jsonString = await rootBundle.loadString('assets/hotspots/$directory/hotspot.json');
        final Map<String, dynamic> jsonData = json.decode(jsonString);
        
        final hotspot = Hotspot.fromJson(jsonData);
        if (hotspot.status == 'active') {
          hotspots.add(hotspot);
        }
      } catch (e) {
        debugPrint('Error loading hotspot from $directory: $e');
      }
    }
    
    return hotspots;
  }

  // Get hotspots within a certain distance of a location
  List<Hotspot> getHotspotsNearLocation(double latitude, double longitude, {double maxDistance = 5000}) {
    return _hotspots.where((hotspot) {
      double distance = calculateDistance(
        latitude, 
        longitude, 
        hotspot.location.latitude, 
        hotspot.location.longitude
      );
      return distance <= maxDistance;
    }).toList();
  }

  // Check if user is within a hotspot's radius
  bool isUserInHotspot(Hotspot hotspot, double userLatitude, double userLongitude) {
    double distance = calculateDistance(
      userLatitude, 
      userLongitude, 
      hotspot.location.latitude, 
      hotspot.location.longitude
    );
    return distance <= hotspot.location.radius;
  }

  // Calculate distance between two points using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = 
      (sin(dLat / 2) * sin(dLat / 2)) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      (sin(dLon / 2) * sin(dLon / 2));
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }
} 


final myService = HotspotService();