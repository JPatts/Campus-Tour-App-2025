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
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

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

class PhotoViewerScreen extends StatefulWidget {
  final String assetPath;
  const PhotoViewerScreen({Key? key, required this.assetPath}) : super(key: key);

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails!.localPosition;
    const double zoomScale = 2.5;
    final value = _transformationController.value.isIdentity()
        ? (Matrix4.identity()
            ..translate(
              -position.dx * (zoomScale - 1),
              -position.dy * (zoomScale - 1),
            )
            ..scale(zoomScale))
        : Matrix4.identity();
    _transformationController.value = value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 600) {
            Navigator.of(context).pop();
          }
        },
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: Stack(
          children: [
            // Image layer (fills the entire screen and centers the image)
            Positioned.fill(
              child: Hero(
                tag: widget.assetPath,
                child: SizedBox.expand(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1,
                    maxScale: 5,
                    clipBehavior: Clip.none,
                    child: Image.asset(
                      widget.assetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            // Optional subtle top gradient for readability
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Close button overlay in safe area (doesn't affect image layout)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        return _buildVideoContent(assetPath, feature.content);
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
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: true,
            barrierColor: Colors.black,
            pageBuilder: (context, animation, secondaryAnimation) =>
                FadeTransition(
              opacity: animation,
              child: PhotoViewerScreen(assetPath: assetPath),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Hero(
              tag: assetPath,
              child: Image.asset(
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

  Widget _buildVideoContent(String assetPath, String title) {
    return GestureDetector(
      onTap: () {
        _showVideoPlayer(assetPath, title);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 180,
          width: double.infinity,
          child: FutureBuilder<VideoPlayerController>(
            future: _createVideoThumbnail(assetPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && 
                  snapshot.hasData && 
                  snapshot.data!.value.isInitialized) {
                return Stack(
                  children: [
                    // Video thumbnail
                    SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: snapshot.data!.value.size.width,
                          height: snapshot.data!.value.size.height,
                          child: VideoPlayer(snapshot.data!),
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
                );
              } else {
                // Loading or fallback state
                return Stack(
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
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAudioContent(HotspotFeature feature) {
    return AudioPlayerWidget(
      assetPath: 'assets/hotspots/${_getHotspotIdFromFeature(feature)}/Assets/${feature.fileLocation}',
      description: feature.content,
    );
  }

  String _getHotspotIdFromFeature(HotspotFeature feature) {
    // This is a helper to get the hotspot ID - we'll use 'se117thAve' for now
    // In a more complex app, you'd pass this information differently
    return 'se117thAve';
  }

  Future<VideoPlayerController> _createVideoThumbnail(String assetPath) async {
    final controller = VideoPlayerController.asset(assetPath);
    try {
      await controller.initialize();
      // Seek to a frame a few seconds in to get a better thumbnail
      await controller.seekTo(const Duration(seconds: 1));
      return controller;
    } catch (e) {
      // If initialization fails, return the controller anyway for error handling
      return controller;
    }
  }

  void _showVideoPlayer(String assetPath, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(assetPath: assetPath, title: title),
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
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: const Color(0xFF213921)),
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
                color: const Color(0xFF213921),
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

class AudioPlayerWidget extends StatefulWidget {
  final String assetPath;
  final String description;

  const AudioPlayerWidget({
    Key? key,
    required this.assetPath,
    required this.description,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasStartedPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
        _isLoading = false; // Audio is loaded when we get duration
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        // Only show loading when we're trying to play but haven't started yet
        _isLoading = (state == PlayerState.playing || state == PlayerState.stopped) && 
                     !_hasStartedPlaying && _duration == Duration.zero;
      });
    });
  }

  Future<void> _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // If we haven't started playing yet, load the audio
        if (!_hasStartedPlaying) {
          setState(() {
            _isLoading = true;
          });
          await _audioPlayer.play(AssetSource(widget.assetPath.replaceFirst('assets/', '')));
          _hasStartedPlaying = true;
        } else {
          // If we've already loaded the audio, just resume
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: ${e.toString()}')),
      );
    }
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    setState(() {
      _hasStartedPlaying = false;
      _isLoading = false;
      _position = Duration.zero;
    });
  }

  Future<void> _seekBackward() async {
    if (_hasStartedPlaying && _duration > Duration.zero) {
      final currentPosition = _position;
      final newPosition = currentPosition - const Duration(seconds: 10);
      await _audioPlayer.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
    }
  }

  Future<void> _seekForward() async {
    if (_hasStartedPlaying && _duration > Duration.zero) {
      final currentPosition = _position;
      final newPosition = currentPosition + const Duration(seconds: 10);
      await _audioPlayer.seek(newPosition > _duration ? _duration : newPosition);
    }
  }

  Future<void> _restart() async {
    if (_hasStartedPlaying) {
      await _audioPlayer.seek(Duration.zero);
      if (!_isPlaying) {
        await _audioPlayer.resume();
      }
    } else {
      // If we haven't started playing yet, just start from beginning
      await _playPause();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF213921).withOpacity(0.1),
            const Color(0xFF213921).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF213921).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          // Progress bar and time display
          if (_duration > Duration.zero) ...[
            // Time display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(
                    color: Color(0xFF213921),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Enhanced progress bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF213921),
                thumbColor: const Color(0xFF213921),
                inactiveTrackColor: Colors.grey[300],
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
              ),
              child: Slider(
                value: _duration.inSeconds > 0 
                    ? _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble())
                    : 0.0,
                max: _duration.inSeconds.toDouble(),
                onChanged: (value) async {
                  await _audioPlayer.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 16),
          ],
          
          // Enhanced control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Seek backward button
              IconButton(
                onPressed: _hasStartedPlaying && _duration > Duration.zero ? _seekBackward : null,
                icon: Icon(
                  Icons.replay_10,
                  color: _hasStartedPlaying && _duration > Duration.zero 
                      ? const Color(0xFF213921) 
                      : Colors.grey[400],
                  size: 28,
                ),
                tooltip: 'Rewind 10 seconds',
              ),
              
              // Stop button
              IconButton(
                onPressed: _hasStartedPlaying ? _stop : null,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _hasStartedPlaying ? Colors.grey[200] : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.stop,
                    color: _hasStartedPlaying ? const Color(0xFF213921) : Colors.grey[400],
                    size: 20,
                  ),
                ),
                tooltip: 'Stop',
              ),
              
              // Main play/pause button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF213921),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF213921).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _isLoading ? null : _playPause,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                  tooltip: _isLoading ? 'Loading...' : (_isPlaying ? 'Pause' : 'Play'),
                ),
              ),
              
              // Restart button
              IconButton(
                onPressed: _hasStartedPlaying ? _restart : null,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _hasStartedPlaying ? Colors.grey[200] : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.replay,
                    color: _hasStartedPlaying ? const Color(0xFF213921) : Colors.grey[400],
                    size: 20,
                  ),
                ),
                tooltip: 'Restart',
              ),
              
              // Seek forward button
              IconButton(
                onPressed: _hasStartedPlaying && _duration > Duration.zero ? _seekForward : null,
                icon: Icon(
                  Icons.forward_10,
                  color: _hasStartedPlaying && _duration > Duration.zero 
                      ? const Color(0xFF213921) 
                      : Colors.grey[400],
                  size: 28,
                ),
                tooltip: 'Forward 10 seconds',
              ),
            ],
          ),
          
          // Additional info or status
          if (_isLoading && _duration == Duration.zero) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: const Color(0xFF213921),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading audio...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String assetPath;
  final String title;

  const VideoPlayerScreen({Key? key, required this.assetPath, required this.title}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    // Allow all orientations while in the video player
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeVideoPlayer();
    _startHideControlsTimer();
  }

  void _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.asset(widget.assetPath);
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.play();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading video: ${e.toString()}';
      });
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _seekBackward() {
    final currentPosition = _controller.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  void _seekForward() {
    final currentPosition = _controller.value.position;
    final duration = _controller.value.duration;
    final newPosition = currentPosition + const Duration(seconds: 10);
    _controller.seekTo(newPosition > duration ? duration : newPosition);
  }

  @override
  void dispose() {
    // Restore to portrait when leaving the video player
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    _hideControlsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: isLargeScreen
            ? null
            : AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : _isInitialized
              ? Stack(
                  children: [
                    // Capture taps anywhere on the screen (behind overlays and video)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _toggleControlsVisibility,
                      ),
                    ),
                    // Video player that takes up the full available space (also toggles controls on tap)
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleControlsVisibility,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                    // Overlay controls
                    if (_showControls) ...[
                      // Top gradient overlay for better text visibility
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.black.withOpacity(0.4),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom controls overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          height: 120,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.8),
                                    Colors.black.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom controls overlay (kept tappable)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress bar
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: VideoProgressIndicator(
                                  _controller,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                    playedColor: Color(0xFF213921),
                                    bufferedColor: Colors.grey,
                                    backgroundColor: Colors.white24,
                                  ),
                                ),
                              ),
                              // Time display
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(_controller.value.position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(_controller.value.duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Control buttons
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      onPressed: _seekBackward,
                                      icon: const Icon(
                                        Icons.replay_10,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _controller.value.isPlaying
                                              ? _controller.pause()
                                              : _controller.play();
                                        });
                                        _startHideControlsTimer();
                                      },
                                      icon: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF213921),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _controller.value.isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _seekForward,
                                      icon: const Icon(
                                        Icons.forward_10,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Center play/pause button for large tap area
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                            _startHideControlsTimer();
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF213921),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading video...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
