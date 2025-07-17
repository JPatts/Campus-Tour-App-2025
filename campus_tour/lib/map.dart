import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:math' as math;

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
      await _requestLocationPermission();
      await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing map: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
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

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Move camera to user's location if it's near PSU
      if (_mapController != null && _isNearPSU(position)) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 17.0,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  bool _isNearPSU(Position position) {
    // Check if user is within ~2km of PSU
    double distance = Geolocator.distanceBetween(
      45.5152, -122.6784, // PSU coordinates
      position.latitude, position.longitude,
    );
    return distance <= 2000; // 2km radius
  }

  Set<Marker> _createMarkers() {
    Set<Marker> markers = {};

    // Add PSU marker
    markers.add(
      const Marker(
        markerId: MarkerId('psu'),
        position: LatLng(45.5152, -122.6784),
        infoWindow: InfoWindow(
          title: 'Portland State University',
          snippet: 'Campus Tour Start',
        ),
      ),
    );

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

    return markers;
  }

  Set<Polygon> _createPolygons() {
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

    return {
      Polygon(
        polygonId: const PolygonId('psu_spotlight'),
        points: outer,
        holes: [hole],
        fillColor: Colors.grey.withOpacity(0.6),
        strokeColor: Colors.transparent,
        strokeWidth: 0,
      ),
    };
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

    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      initialCameraPosition: _psuLocation,
      markers: _createMarkers(),
      polygons: _createPolygons(),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      mapToolbarEnabled: true,
      zoomControlsEnabled: true,
      onTap: (LatLng location) {
        debugPrint('Tapped at: ${location.latitude}, ${location.longitude}');
      },
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
