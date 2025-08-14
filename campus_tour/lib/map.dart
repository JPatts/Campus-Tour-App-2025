import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'models/hotspot.dart';
import 'services/hotspot_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  final bool adminModeEnabled;
  const MapScreen({Key? key, this.adminModeEnabled = false}) : super(key: key);

  // Remember the last selected map type across rebuilds/switches
  static MapType? lastMapType;
  // Remember the last camera position (center + zoom) across page switches
  static CameraPosition? lastCameraPosition;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  List<Hotspot> _hotspots = [];
  final HotspotService _hotspotService = HotspotService();
  StreamSubscription<Position>? _positionSubscription;
  final Map<String, bool> _wasInsideHotspot = {}; // Track enter/exit transitions
  final Map<String, DateTime> _lastHotspotNotifyAt = {}; // Debounce notifications
  String? _currentlyShownSnackForHotspotId;
  MapType _mapType = MapType.normal;
  CameraPosition? _lastCameraMove;

  // Portland State University coordinates
  static const CameraPosition _psuLocation = CameraPosition(
    target: LatLng(45.5115, -122.6835), // PSU campus center
    zoom: 15.5, // Slightly zoomed out to show more campus context
  );

  @override
  void initState() {
    super.initState();
    // Restore last selected map type if available
    _mapType = MapScreen.lastMapType ?? MapType.normal;
    _initializeMap();
  }

  @override
  bool get wantKeepAlive => true;

  // No local testing toggle—admin mode controls access globally

  Future<void> _initializeMap() async {
    try {
      debugPrint('Starting map initialization...');
      await _requestLocationPermission();
      debugPrint('Location permission granted');
      await _getCurrentLocation();
      debugPrint('Current location obtained');
      _startPositionStream();
      await _loadHotspots();
      debugPrint('Hotspots loaded successfully');
      
      setState(() {
        _isLoading = false;
      });

      _evaluateProximityAndNotify();
    } catch (e, stackTrace) {
      debugPrint('Error initializing map: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Error initializing map: $e\n\nThis might be due to:\n• Google Maps API key issues\n• Location permission problems\n• Network connectivity\n\nCheck the console for detailed errors.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHotspots() async {
    try {
      final hotspots = await _hotspotService.loadHotspots();
      setState(() {
        _hotspots = hotspots;
      });
      // Initialize state for new hotspots
      for (final hs in hotspots) {
        _wasInsideHotspot.putIfAbsent(hs.hotspotId, () => false);
      }
    } catch (e) {
      debugPrint('Error loading hotspots: $e');
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

      // Move camera to user's location if it's near PSU, but only
      // if we don't already have a saved camera position
      if (_mapController != null && _isNearPSU(position) && MapScreen.lastCameraPosition == null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 17.0,
            ),
          ),
        );
        MapScreen.lastCameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 17.0,
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
    // Check if user is within ~8km of PSU (about 5 miles)
    double distance = Geolocator.distanceBetween(
      45.5115, -122.6835, // PSU campus center
      position.latitude, position.longitude,
    );
    return distance <= 8000; // ~5 miles radius
  }

  Set<Marker> _createMarkers() {
    // Remove custom user marker to avoid confusion with built-in blue dot
    // Hotspots are displayed as circles only
    return <Marker>{};
  }

  void _onHotspotTapped(Hotspot hotspot) {
    // Check if user is within hotspot radius or testing mode is enabled
    if (widget.adminModeEnabled) {
      _showHotspotContent(hotspot);
    } else if (_currentPosition != null) {
      bool isWithinRadius = _hotspotService.isUserInHotspot(
        hotspot,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (isWithinRadius) {
        _showHotspotContent(hotspot);
      } else {
        _showHotspotInfo(hotspot);
      }
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
                        tooltip: 'Open in Maps',
                        onPressed: () => _showOpenInMapsSheet(hotspot),
                        icon: const Icon(Icons.directions_outlined, color: Colors.white),
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForFeatureType(feature.type),
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature.content,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMediaContent(hotspot, feature),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(Hotspot hotspot, HotspotFeature feature) {
    final String assetPath = 'assets/hotspots/${hotspot.hotspotId}/Assets/${feature.fileLocation}';
    
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
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.black,
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
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
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(String assetPath) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video playback not yet implemented')),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Background gradient placeholder
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[800]!, Colors.grey[600]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Semi-transparent overlay
            Container(
              height: 180,
              width: double.infinity,
              color: Colors.black.withOpacity(0.3),
            ),
            // Play icon
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            // Label
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Video',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioContent(HotspotFeature feature) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
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
    bool isWithinRadius = false;
    if (_currentPosition != null) {
      distance = _hotspotService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        hotspot.location.latitude,
        hotspot.location.longitude,
      );
      isWithinRadius = _hotspotService.isUserInHotspot(
        hotspot,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
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
              if (_currentPosition == null)
                const Text('Current location unavailable'),
               if (_currentPosition != null && isWithinRadius) ...[
                const Text('You are inside this hotspot zone.'),
                const SizedBox(height: 8),
                Text('Zone radius: ${_formatDistance(hotspot.location.radius)}'),
               ] else if (_currentPosition != null && distance != null) ...[
                Text('Remaining: ${_formatRemainingFeet(distance, hotspot.location.radius * 3.28084)}'),
                const SizedBox(height: 8),
                const Text('Enter the zone to unlock the content'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => _showOpenInMapsSheet(hotspot),
              child: const Text('Open in Maps'),
            ),
            if (_currentPosition != null && isWithinRadius)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showHotspotContent(hotspot);
                },
                child: const Text('Open Content'),
              ),
          ],
        );
      },
    );
  }

  void _showOpenInMapsSheet(Hotspot hotspot) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Open in Apple Maps'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _launchAppleMaps(hotspot);
                },
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Open in Google Maps'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _launchGoogleMaps(hotspot);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchAppleMaps(Hotspot hotspot) async {
    final double lat = hotspot.location.latitude;
    final double lng = hotspot.location.longitude;
    final String label = hotspot.name;
    final Uri uri = Uri.https('maps.apple.com', '/', {
      'q': label,
      'll': '$lat,$lng',
    });
    await _launchUri(uri);
  }

  Future<void> _launchGoogleMaps(Hotspot hotspot) async {
    final double lat = hotspot.location.latitude;
    final double lng = hotspot.location.longitude;
    final Uri uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$lat,$lng',
    });
    await _launchUri(uri);
  }

  Future<void> _launchUri(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Fallback to in-app browser if external app not available
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
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
    // kept for any other usages
    final double feet = meters * 3.28084;
    if (feet < 1000) return '${feet.toStringAsFixed(0)} ft';
    final double miles = feet / 5280;
    if (miles < 0.1) return '${(miles * 10).round() / 10} miles';
    return '${miles.toStringAsFixed(1)} miles';
  }

  String _formatRemainingFeet(double meters, double thresholdFeet) {
    final double feet = meters * 3.28084;
    final double remaining = (feet - thresholdFeet).clamp(0, double.infinity);
    if (remaining >= 5280) {
      final double miles = remaining / 5280.0;
      return '${miles.toStringAsFixed(1)} miles left';
    }
    return '${remaining.toStringAsFixed(0)} ft left';
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
        bool isWithinRadius = widget.adminModeEnabled;
        if (!widget.adminModeEnabled && _currentPosition != null) {
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
        double distanceToHotspot = _hotspotService.calculateDistance(
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

  void _startPositionStream() {
    // Continuously update user location so proximity reflects being anywhere within the circle
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3, // meters
    );
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      _evaluateProximityAndNotify();
    }, onError: (e) {
      debugPrint('Position stream error: $e');
    });
  }

  void _evaluateProximityAndNotify() {
    if (_currentPosition == null || _hotspots.isEmpty) return;

    for (final hotspot in _hotspots) {
      if (hotspot.status != 'active') continue;

      final bool isInside = _hotspotService.isUserInHotspot(
        hotspot,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      final bool wasInside = _wasInsideHotspot[hotspot.hotspotId] ?? false;
      _wasInsideHotspot[hotspot.hotspotId] = isInside;

      // Notify on enter with debounce (8s per hotspot)
      if (isInside && !wasInside) {
        final DateTime now = DateTime.now();
        final DateTime last = _lastHotspotNotifyAt[hotspot.hotspotId] ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (now.difference(last).inSeconds >= 8) {
          _lastHotspotNotifyAt[hotspot.hotspotId] = now;
          _showEnteredHotspotSnack(hotspot);
        }
      }
    }
  }

  void _showEnteredHotspotSnack(Hotspot hotspot) {
    if (!mounted) return;
    // Avoid showing multiple at once; replace any current
    _currentlyShownSnackForHotspotId = hotspot.hotspotId;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You have entered "${hotspot.name}"'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            _showHotspotContent(hotspot);
          },
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            SizedBox(height: 8),
            Text('If this takes too long, check your internet connection\nand Google Maps API key configuration.', 
                 style: TextStyle(fontSize: 12, color: Colors.grey),
                 textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Show detailed troubleshooting info
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Troubleshooting'),
                      content: const SingleChildScrollView(
                        child: Text(
                          'Common issues:\n\n'
                          '1. Google Maps API Key:\n'
                          '   • Check if API key is valid\n'
                          '   • Ensure iOS restrictions are set correctly\n'
                          '   • Verify Maps SDK for iOS is enabled\n\n'
                          '2. Location Permissions:\n'
                          '   • Allow location access in Settings\n'
                          '   • Enable Location Services\n\n'
                          '3. Network Connection:\n'
                          '   • Check internet connectivity\n'
                          '   • Try switching between WiFi/Cellular\n\n'
                          '4. Device Issues:\n'
                          '   • Restart the app\n'
                          '   • Restart the device\n'
                          '   • Clear app data if needed',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Troubleshooting'),
              ),
            ],
          ),
        ),
      );
    }

    super.build(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: const Color(0xFF6D8D24)),
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                debugPrint('Google Map created successfully');
                _mapController = controller;
              },
              initialCameraPosition: MapScreen.lastCameraPosition ?? _psuLocation,
              mapType: _mapType,
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
              onCameraMove: (CameraPosition position) {
                _lastCameraMove = position;
              },
              onCameraIdle: () {
                if (_lastCameraMove != null) {
                  MapScreen.lastCameraPosition = _lastCameraMove;
                }
              },
            ),
            // Map type toggle button (Standard / Satellite / Hybrid / Terrain)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 12,
              child: Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: PopupMenuButton<MapType>(
                  onSelected: (t) => setState(() {
                    _mapType = t;
                    MapScreen.lastMapType = t;
                  }),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: MapType.normal, child: Text('Standard')),
                    PopupMenuItem(value: MapType.satellite, child: Text('Satellite')),
                    PopupMenuItem(value: MapType.hybrid, child: Text('Hybrid')),
                    PopupMenuItem(value: MapType.terrain, child: Text('Terrain')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers, size: 18, color: Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          _mapType == MapType.normal
                              ? 'Standard'
                              : _mapType == MapType.satellite
                                  ? 'Satellite'
                                  : _mapType == MapType.hybrid
                                      ? 'Hybrid'
                                      : 'Terrain',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Status bar background to match brand color
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).padding.top,
                color: const Color(0xFF6D8D24),
              ),
            ),
          ],
        ),
        floatingActionButton: null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
