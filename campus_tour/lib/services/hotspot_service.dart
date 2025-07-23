import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/hotspot.dart';
import '../helpers/geo_helpers.dart';

class HotspotService {
  static final HotspotService _instance = HotspotService._internal();
  factory HotspotService() => _instance;
  HotspotService._internal();

  List<Hotspot> _hotspots = [];
  bool _isLoaded = false;

  List<Hotspot> get hotspots => _hotspots;
  bool get isLoaded => _isLoaded;

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
      'exampleHotspot',
      'psuLibrary',
      'psuRecCenter',
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
}
