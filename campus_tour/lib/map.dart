import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'models/hotspot.dart';
import 'services/hotspot_service.dart';
import 'services/location_service.dart';
import 'helpers/hotspot_helpers.dart';
import 'helpers/geo_helpers.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  List<Hotspot> _hotspots = [];
  final HotspotService _hotspotService = HotspotService();
  bool _testingMode = false; // For simulating location

  // Portland State University coordinates
  static const CameraPosition _psuLocation = CameraPosition(
    target: LatLng(45.5152, -122.6784), // PSU Park Blocks area
    zoom: 16.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      await LocationService.requestLocationPermission();
      _currentPosition = await LocationService.getCurrentLocation();
      _hotspots = await _hotspotService.loadHotspots();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing map: $e';
        _isLoading = false;
      });
    }
  }

  Set<Marker> _createMarkers() {
    Set<Marker> markers = {};

    // Add user location marker if available
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(
            title: 'Your Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Note: Hotspots are displayed as circles only, no markers

    return markers;
  }

  void _onHotspotTapped(Hotspot hotspot) {
    // Check if user is within hotspot radius or testing mode is enabled
    if (isHotspotUnlocked(
      hotspot: hotspot,
      userPosition: _currentPosition,
      testingMode: _testingMode
    )) {
      _showHotspotContent(hotspot);
    } else {
      _showHotspotInfo(hotspot);
    }
  }

  void _showHotspotContent(Hotspot hotspot) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          hotspot.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Content - Make this properly scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...hotspot.features.map((feature) => _buildFeatureWidget(hotspot, feature)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureWidget(Hotspot hotspot, HotspotFeature feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIconForFeatureType(feature.type), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature.content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMediaContent(hotspot, feature),
        ],
      ),
    );
  }

  Widget _buildMediaContent(Hotspot hotspot, HotspotFeature feature) {
    final String assetPath = getAssetPath(hotspot, feature);
    
    switch (feature.type.toLowerCase()) {
      case 'photo':
        return _buildPhotoContent(assetPath);
      case 'video':
        return _buildVideoContent(assetPath);
      case 'audio':
        return _buildAudioContent(feature);
      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Content type: ${feature.type}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildPhotoContent(String assetPath) {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 200,
        minHeight: 150,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Image not available', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoContent(String assetPath) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Video content', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('(Tap to play)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          Positioned(
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video playback not yet implemented')),
                );
              },
              icon: const Icon(
                Icons.play_circle_filled,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioContent(HotspotFeature feature) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.audiotrack, color: Colors.blue[600], size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audio Content',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.content,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audio playback not yet implemented')),
              );
            },
            icon: Icon(Icons.play_arrow, color: Colors.blue[600]),
          ),
        ],
      ),
    );
  }

  void _showHotspotInfo(Hotspot hotspot) {
    double? distance;
    if (_currentPosition != null) {
      distance = calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        hotspot.location.latitude,
        hotspot.location.longitude,
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(hotspot.name),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hotspot.description),
              const SizedBox(height: 16),
              if (distance != null) ...[
                Text('Distance: ${_formatDistance(distance)} away'),
                const SizedBox(height: 8),
                Text('Get within ${_formatDistance(hotspot.location.radius)} to unlock content'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconForFeatureType(String type) {
    switch (type.toLowerCase()) {
      case 'photo':
        return Icons.photo;
      case 'video':
        return Icons.video_library;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.info;
    }
  }

  String _formatDistance(double meters) {
    // Convert meters to feet
    double feet = meters * 3.28084;
    
    // If less than 1000 feet, show in feet
    if (feet < 1000) {
      return '${feet.toStringAsFixed(0)} ft';
    }
    
    // If 1000 feet or more, show in miles
    double miles = feet / 5280;
    if (miles < 0.1) {
      return '${(miles * 10).round() / 10} miles'; // Round to 0.1 miles
    } else {
      return '${miles.toStringAsFixed(1)} miles';
    }
  }

  Set<Polygon> _createPolygons() {
    Set<Polygon> polygons = {};

    // Outer ring: a huge circle around the world
    final List<LatLng> outer = [];
    const int points = 360;
    const double radius = 90.0; // degrees, covers the globe
    const double centerLat = 45.5152;
    const double centerLng = -122.6784;
    for (int i = 0; i < points; i++) {
      final double angle = 2 * math.pi * i / points;
      final double lat = centerLat + radius * math.cos(angle);
      final double lng = centerLng + radius * math.sin(angle);
      outer.add(LatLng(lat, lng));
    }

    // Inner hole: small circle around PSU
    final List<LatLng> hole = [];
    const double holeRadius = 0.003; // ~300m
    for (int i = 0; i < points; i++) {
      final double angle = 2 * math.pi * i / points;
      final double lat = centerLat + holeRadius * math.cos(angle);
      final double lng = centerLng + holeRadius * math.sin(angle);
      hole.add(LatLng(lat, lng));
    }

    polygons.add(
      Polygon(
        polygonId: const PolygonId('psu_spotlight'),
        points: outer,
        holes: [hole],
        fillColor: Colors.grey.withValues(alpha: 0.6),
        strokeColor: Colors.transparent,
        strokeWidth: 0,
      ),
    );

    return polygons;
  }

  Set<Circle> _createCircles() {
    Set<Circle> circles = {};

    // Add circles for hotspot radius
    for (final hotspot in _hotspots) {
      if (hotspot.status == 'active') {
        // Check if user is within hotspot radius or testing mode is enabled
        bool isWithinRadius = _testingMode;
        if (!_testingMode && _currentPosition != null) {
          isWithinRadius = _hotspotService.isUserInHotspot(
            hotspot,
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
        }

        circles.add(
          Circle(
            circleId: CircleId('${hotspot.hotspotId}_radius'),
            center: LatLng(hotspot.location.latitude, hotspot.location.longitude),
            radius: hotspot.location.radius,
            strokeColor: isWithinRadius ? Colors.green : Colors.orange,
            strokeWidth: 2,
            fillColor: (isWithinRadius ? Colors.green : Colors.orange).withValues(alpha: 0.1),
          ),
        );
      }
    }

    return circles;
  }

  void _handleMapTap(LatLng tappedLocation) {
    // Check if the tap is within any hotspot radius
    for (final hotspot in _hotspots) {
      if (hotspot.status == 'active') {
        double distanceToHotspot = calculateDistance(
          tappedLocation.latitude,
          tappedLocation.longitude,
          hotspot.location.latitude,
          hotspot.location.longitude,
        );

        // If tap is within hotspot radius, show the hotspot info
        if (distanceToHotspot <= hotspot.location.radius) {
          _onHotspotTapped(hotspot);
          break; // Only show the first hotspot found (in case of overlapping)
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading map...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                  _isLoading = true;
                });
                _initializeMap();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
        initialCameraPosition: _psuLocation,
        mapType: MapType.hybrid,
        markers: _createMarkers(),
        polygons: _createPolygons(),
        circles: _createCircles(),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
        zoomControlsEnabled: true,
        onTap: (LatLng location) {
          debugPrint('Tapped at: ${location.latitude}, ${location.longitude}');
          _handleMapTap(location);
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Testing Mode Toggle Button
          FloatingActionButton.extended(
            heroTag: "testingMode",
            onPressed: () {
              setState(() {
                _testingMode = !_testingMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _testingMode 
                      ? 'Testing Mode ON - All hotspots unlocked' 
                      : 'Testing Mode OFF - Location-based access'
                  ),
                  backgroundColor: _testingMode ? Colors.green : Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            backgroundColor: _testingMode ? Colors.green : Colors.grey,
            foregroundColor: Colors.white,
            icon: Icon(_testingMode ? Icons.lock_open : Icons.lock),
            label: Text(_testingMode ? 'Testing ON' : 'Testing OFF'),
          ),
          const SizedBox(height: 16),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
