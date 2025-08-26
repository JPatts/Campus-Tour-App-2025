import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/hotspot.dart';
import 'services/hotspot_service.dart';
import 'package:vector_math/vector_math.dart' as vmath;
import 'utils/emoji_helper.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final HotspotService _hotspotService = HotspotService();
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _headingSub;
  Timer? _uiTick;

  Position? _currentPosition;
  double _headingDegrees = 0; // 0..360, 0 = North
  List<Hotspot> _hotspots = [];

  bool _initializing = true;
  String _error = '';
  bool _retrying = false; // keep error screen visible during retry

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _headingSub?.cancel();
    _cameraController?.dispose();
    _uiTick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cam = _cameraController;
    
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Dispose camera when app goes to background
      if (cam != null && cam.value.isInitialized) {
        cam.dispose();
        _cameraController = null;
        _cameraInitFuture = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize camera when app comes back to foreground
      if (cam == null || !cam.value.isInitialized) {
        _setupCamera();
      }
    }
  }

  Future<void> _init() async {
    try {
      await _ensurePermissions();
      await _loadHotspots();
      await _getInitialLocation();
      _startLocationStream();
      _startHeadingStream();
      await _setupCamera();
      _startUiTicker();
      setState(() => _initializing = false);
    } catch (e) {
      setState(() {
        _error = 'AR init error: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _ensurePermissions() async {
    final statuses = await [Permission.camera, Permission.locationWhenInUse].request();
    if (statuses[Permission.camera] != PermissionStatus.granted) {
      throw Exception('camera_permission_denied');
    }
    if (statuses[Permission.locationWhenInUse] != PermissionStatus.granted) {
      throw Exception('location_permission_denied');
    }
  }

  Future<void> _loadHotspots() async {
    final loaded = await _hotspotService.loadHotspots();
    setState(() => _hotspots = loaded.where((h) => h.status == 'active').toList());
  }

  Future<void> _getInitialLocation() async {
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    setState(() => _currentPosition = pos);
  }

  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((pos) => setState(() => _currentPosition = pos));
  }

  void _startHeadingStream() {
    _headingSub?.cancel();
    _headingSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading; // in degrees, may be null
      if (heading != null) {
        setState(() => _headingDegrees = heading);
      }
    });
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraController = controller;
    _cameraInitFuture = controller.initialize();
    await _cameraInitFuture;
    if (mounted) setState(() {});
  }

  void _startUiTicker() {
    _uiTick?.cancel();
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  // Compute bearing from user location to hotspot
  double _bearingTo(Hotspot hs) {
    if (_currentPosition == null) return 0;
    final lat1 = vmath.radians(_currentPosition!.latitude);
    final lon1 = vmath.radians(_currentPosition!.longitude);
    final lat2 = vmath.radians(hs.location.latitude);
    final lon2 = vmath.radians(hs.location.longitude);
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    double brng = vmath.degrees(math.atan2(y, x)); // -180..180
    if (brng < 0) brng += 360;
    return brng; // 0..360 (0=N)
  }

  // Screen position mapping: angle difference to horizontal offset
  Offset _projectHotspotToScreen(Size size, double targetBearing) {
    // Camera horizontal field of view estimate (in degrees). Phones ~60–70.
    const double horizontalFov = 65;
    // Normalize diff to [-180, 180]
    double diff = targetBearing - _headingDegrees;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;

    // If outside FOV, place off-screen X for fade decisions
    final double halfFov = horizontalFov / 2.0;
    final double normalized = (diff / halfFov).clamp(-1.5, 1.5);
    final double x = size.width * (0.5 + 0.5 * normalized);

    // Vertical placement can encode relative distance later; for now center
    final double y = size.height * 0.5;
    return Offset(x, y);
  }

  // Build initials from a hotspot name (e.g., "Central Plaza" -> "CP")
  String _getInitials(String name) {
    return EmojiHelper.labelForName(name);
  }

  // Choose an emoji based on the full hotspot name so icon selection remains accurate
  String _emojiForName(String name) {
    return EmojiHelper.emojiForName(name);
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) {
      return _buildErrorScreen();
    }
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: const Color(0xFF6d8d24)),
      child: Stack(
        fit: StackFit.expand,
        children: [
        // Camera preview
        if (_cameraController != null && _cameraController!.value.isInitialized)
          FutureBuilder<void>(
            future: _cameraInitFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ColoredBox(color: Colors.black);
              }
              // Check if controller is still valid before building preview
              if (_cameraController != null && _cameraController!.value.isInitialized) {
                return CameraPreview(_cameraController!);
              } else {
                return const ColoredBox(color: Colors.black);
              }
            },
          )
        else
          const ColoredBox(color: Colors.black),

        // Green status bar background to match brand color
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: MediaQuery.of(context).padding.top,
            color: const Color(0xFF6d8d24),
          ),
        ),

        // AR overlay
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final position = _currentPosition;
              if (position == null) return const SizedBox.shrink();

              final widgets = <Widget>[];
              bool hasVisibleHotspots = false;
              bool hasNearbyHotspots = false;
              
              for (final hs in _hotspots) {
                final double distanceM = _hotspotService.calculateDistance(
                  position.latitude,
                  position.longitude,
                  hs.location.latitude,
                  hs.location.longitude,
                );
                // Only render if within 1000 feet (305 meters)
                if (distanceM > 305) continue;
                
                hasNearbyHotspots = true;

                // Hide marker when the user is inside the hotspot radius ("0 ft left")
                if (distanceM <= hs.location.radius) {
                  continue;
                }
                final targetBearing = _bearingTo(hs);
                final screenPos = _projectHotspotToScreen(size, targetBearing);

                // Opacity fades out as hotspot leaves FOV
                final double angleDiff = (targetBearing - _headingDegrees + 540) % 360 - 180; // [-180,180]
                final double fovHalf = 32.5; // half of 65
                final double visibility = (1 - (angleDiff.abs() / (fovHalf * 1.2))).clamp(0.0, 1.0);

                // Marker footprint and size (keep marker size; we'll scale label content separately)
                final double baseSize = 140;
                final double scale = (1.0 - (distanceM / 305)).clamp(0.25, 1.0);
                final double diameter = baseSize * scale;
                final double markerHeight = diameter * 1.7; // extra space for ring + label

                if (visibility > 0.1) { // Only count as visible if opacity is significant
                  hasVisibleHotspots = true;
                }

                widgets.add(
                  Positioned(
                    left: screenPos.dx - diameter / 2,
                    top: screenPos.dy - markerHeight / 2,
                    width: diameter,
                    height: markerHeight,
                    child: IgnorePointer(
                      ignoring: false,
                      child: Opacity(
                        opacity: visibility,
                          child: GestureDetector(
                             behavior: HitTestBehavior.opaque,
                            onTap: () => _showHotspotSheet(hs, distanceM),
                                child: _PulsingMapPin(
                                  color: Theme.of(context).colorScheme.primary,
                                  title: _getInitials(hs.name),
                                  subtitle: _formatRemainingFeet(
                                    distanceM,
                                    hs.location.radius * 3.28084, // threshold in feet, per-hotspot
                                  ),
                                  customEmoji: _emojiForName(hs.name),
                                  labelScale: scale,
                                ),
                          ),
                      ),
                    ),
                  ),
                );
              }
              
              // Show helpful messages when no hotspots are visible
              if (!hasVisibleHotspots) {
                if (!hasNearbyHotspots) {
                  // No nearby hotspots - show centered pulsing indicator with explore icon (tappable)
                  widgets.add(
                    Positioned.fill(
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _showNoHotspotsSheet,
                          child: const _PulsingArrow(icon: Icons.explore_outlined),
                        ),
                      ),
                    ),
                  );
                } else {
                  // Has nearby hotspots but not in view - show only animated directional arrow (no text)
                  // Find the nearest hotspot to determine direction
                  Hotspot? nearestHotspot;
                  double nearestDistance = double.infinity;
                  
                  for (final hs in _hotspots) {
                    final double distanceM = _hotspotService.calculateDistance(
                      position.latitude,
                      position.longitude,
                      hs.location.latitude,
                      hs.location.longitude,
                    );
                    if (distanceM < nearestDistance) {
                      nearestDistance = distanceM;
                      nearestHotspot = hs;
                    }
                  }
                  
                  if (nearestHotspot != null) {
                    final double targetBearing = _bearingTo(nearestHotspot);
                    final double angleDiff = (targetBearing - _headingDegrees + 540) % 360 - 180; // [-180,180]

                    // Determine which arrow to show based on angle difference
                    IconData arrowIcon;
                    if (angleDiff.abs() < 45) {
                      arrowIcon = Icons.keyboard_arrow_up; // forward
                    } else if (angleDiff > 45 && angleDiff < 135) {
                      arrowIcon = Icons.keyboard_arrow_right; // right
                    } else if (angleDiff < -45 && angleDiff > -135) {
                      arrowIcon = Icons.keyboard_arrow_left; // left
                    } else {
                      arrowIcon = Icons.keyboard_arrow_down; // behind
                    }

                    // Animated pulsing arrow indicator without any text
                    widgets.add(
                      Positioned.fill(
                        child: Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showHotspotSheet(nearestHotspot!, nearestDistance),
                            child: _PulsingArrow(icon: arrowIcon),
                          ),
                        ),
                      ),
                    );
                  }
                }
              }

              // Remove degrees HUD per design request

              return Stack(children: widgets);
            },
          ),
        ),

        ],
      ),
    );
  }

  void _showHotspotSheet(Hotspot hs, double distanceM) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
                     padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hs.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(hs.description, style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final double thresholdFeet = hs.location.radius * 3.28084;
                final double feet = distanceM * 3.28084;
                final bool isWithin = feet <= thresholdFeet;
                if (isWithin) {
                  return const Text('You are inside this hotspot zone.', style: TextStyle(color: Colors.black54));
                }
                return Text(
                  _formatRemainingFeet(distanceM, thresholdFeet),
                  style: const TextStyle(color: Colors.black54),
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _launchAppleMaps(hs);
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Apple Maps'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _launchGoogleMaps(hs);
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Google Maps'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDistance(double meters) {
    // Convert meters to feet; display in feet or miles like the map view
    final double feet = meters * 3.28084;
    if (feet < 1000) return '${feet.toStringAsFixed(0)} ft away';
    final double miles = feet / 5280.0;
    return '${miles.toStringAsFixed(1)} miles away';
  }

  String _formatRemainingFeet(double meters, double thresholdFeet) {
    final double feet = meters * 3.28084;
    final double remaining = (feet - thresholdFeet).clamp(0, double.infinity);
    if (remaining >= 5280) {
      final double miles = remaining / 5280.0;
      return '${miles.toStringAsFixed(1)} miles away';
    }
    return '${remaining.toStringAsFixed(0)} ft away';
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
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  Widget _buildErrorScreen() {
    String title;
    String message;
    IconData icon;
    Color iconColor;
    List<String> steps;

    if (_error.contains('camera_permission_denied')) {
      title = 'Camera Access Required';
      message = 'The AR experience needs camera access to show you nearby locations.';
      icon = Icons.camera_alt_outlined;
      iconColor = Colors.orange;
      steps = [
        'Open your device Settings',
        'Find "Campus Tour App"',
        'Tap "Camera"',
        'Select "Allow"'
      ];
    } else if (_error.contains('location_permission_denied')) {
      title = 'Location Access Required';
      message = 'The AR experience needs location access to show you nearby locations.';
      icon = Icons.location_on_outlined;
      iconColor = Colors.blue;
      steps = [
        'Open your device Settings',
        'Find "Campus Tour App"',
        'Tap "Location"',
        'Select "While Using App"'
      ];
    } else {
      title = 'Something Went Wrong';
      message = 'We encountered an issue while setting up the AR experience.';
      icon = Icons.error_outline;
      iconColor = Colors.red;
      steps = [
        'Check your internet connection',
        'Restart the app',
        'If the problem persists, contact support'
      ];
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top,
              color: const Color(0xFF6d8d24),
            ),
          ),
          SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 64,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Message
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Steps
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How to fix:',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...steps.asMap().entries.map((entry) {
                        final index = entry.key;
                        final step = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  step,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Retry button with smooth transition (keeps error screen visible)
                ElevatedButton.icon(
                  onPressed: _retrying ? null : () async {
                    // Keep error UI visible during retry
                    setState(() {
                      _retrying = true;
                    });

                    try {
                      await _ensurePermissions();
                      await _loadHotspots();
                      await _getInitialLocation();
                      _startLocationStream();
                      _startHeadingStream();
                      await _setupCamera();
                      _startUiTicker();

                      if (mounted) {
                        // Clear error only when fully ready
                        setState(() {
                          _error = '';
                          _initializing = false;
                          _retrying = false;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        // Keep showing error; just stop the spinner
                        setState(() {
                          _error = 'AR init error: $e';
                          _retrying = false;
                        });
                      }
                    }
                  },
                  icon: _retrying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6d8d24)),
                        ),
                      )
                    : const Icon(Icons.refresh),
                  label: Text(_retrying ? 'Initializing...' : 'Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    foregroundColor: const Color(0xFF6d8d24),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
        ],
      ),
    );
  }

  void _showNoHotspotsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF6d8d24).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.explore_outlined, color: Color(0xFF6d8d24), size: 40),
              ),
              const SizedBox(height: 12),
              const Text(
                'No locations nearby',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Walk around campus to discover AR hotspots',
                style: TextStyle(color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6d8d24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapPinPainter extends CustomPainter {
  final Color color;
  final String title;
  final String subtitle;
  final String? customEmoji;
  final double labelScale;
  _MapPinPainter({required this.color, required this.title, required this.subtitle, this.customEmoji, required this.labelScale});
  
  // Scale factor for label text (ties to distance-based marker scale)
  

  // Get default emoji for hotspot type
  String _getDefaultEmoji() {
    final lowerTitle = title.toLowerCase();
    // Use same fallbacks as _emojiForName for consistency
    if (lowerTitle.contains('library')) return '📚';
    if (lowerTitle.contains('parking')) return '🚗';
    if (lowerTitle.contains('fountain')) return '⛲️';
    if (lowerTitle.contains('hall')) return '🏫';
    if (lowerTitle.contains('center') || lowerTitle.contains('pavilion') || lowerTitle.contains('arena')) return '🏟️';
    if (lowerTitle.contains('park')) return '🌳';
    if (lowerTitle.contains('test')) return '🧪';
    return '📍'; // default emoji
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double base = math.min(size.width, size.height);
    final double markerSize = base * 0.3;

    // AR-style floating marker with content icon
    final Offset markerCenter = Offset(center.dx, center.dy - markerSize * 0.2);

    // Outer glow ring
    final Paint outerGlow = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(markerCenter, markerSize + 8, outerGlow);

    // Inner glow ring
    final Paint innerGlow = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(markerCenter, markerSize + 4, innerGlow);

    // Main marker background with gradient
    final Paint markerFill = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.7),
          color.withValues(alpha: 0.4),
        ],
      ).createShader(Rect.fromCircle(center: markerCenter, radius: markerSize));
    canvas.drawCircle(markerCenter, markerSize, markerFill);

    // White border (removed for cleaner look)
    // final Paint border = Paint()
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 2.0
    //   ..color = Colors.white.withValues(alpha: 0.9);
    // canvas.drawCircle(markerCenter, markerSize, border);

    // Inner white circle for icon background (removed for cleaner look)
    // final Paint innerCircle = Paint()
    //   ..color = Colors.white.withValues(alpha: 0.9);
    // canvas.drawCircle(markerCenter, markerSize * 0.7, innerCircle);

    // Draw emoji
    final String emoji = customEmoji ?? _getDefaultEmoji();
    final TextPainter emojiPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: markerSize * 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    emojiPainter.paint(
      canvas,
      Offset(
        markerCenter.dx - emojiPainter.width / 2,
        markerCenter.dy - emojiPainter.height / 2,
      ),
    );

    // Removed static ring to avoid double-border with animated halo

    // AR-style floating label
    final double maxLabelWidth = size.width * 0.9;
    // Scale label fonts with the visual marker diameter (~84% of original)
    final double titleFontSize = ((size.width * 0.12).clamp(8.0, 18.0)) * 0.84;
    final double subtitleFontSize = ((size.width * 0.095).clamp(7.0, 14.0)) * 0.84;
    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: titleFontSize,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxLabelWidth);

    final TextPainter subtitlePainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
          fontSize: subtitleFontSize,
          letterSpacing: 0.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxLabelWidth);

    final double labelHPad = 12.0 * 0.84;
    final double labelVPad = 8.0 * 0.84;
    final double lineSpacing = 3.0 * 0.84;

    final double contentWidth = math.max(titlePainter.width, subtitlePainter.width);
    final double contentHeight = titlePainter.height + lineSpacing + subtitlePainter.height;

    // Label background with AR-style design
    final RRect labelBg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, markerCenter.dy + markerSize + 18),
        width: contentWidth + 2 * labelHPad,
        height: contentHeight + 2 * labelVPad,
      ),
      Radius.circular(12),
    );

    // Label glow effect
    final Paint labelGlow = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawRRect(labelBg, labelGlow);
    canvas.restore();

    // Label background with gradient
    final Paint labelBgFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.8),
          Colors.black.withValues(alpha: 0.6),
        ],
      ).createShader(labelBg.outerRect);
    canvas.drawRRect(labelBg, labelBgFill);

    // Label border
    final Paint labelBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withValues(alpha: 0.6);
    canvas.drawRRect(labelBg, labelBorder);

    // Draw text
    final double titleLeft = labelBg.center.dx - (titlePainter.width / 2);
    final double subtitleLeft = labelBg.center.dx - (subtitlePainter.width / 2);
    titlePainter.paint(canvas, Offset(titleLeft, labelBg.top + labelVPad));
    subtitlePainter.paint(
      canvas,
      Offset(
        subtitleLeft,
        labelBg.top + labelVPad + titlePainter.height + lineSpacing,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle ||
        oldDelegate.customEmoji != customEmoji ||
        oldDelegate.labelScale != labelScale;
  }
}

class _PulsingMapPin extends StatefulWidget {
  final Color color;
  final String title;
  final String subtitle;
  final String? customEmoji;
  final double labelScale;
  const _PulsingMapPin({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.customEmoji,
    required this.labelScale,
  });

  @override
  State<_PulsingMapPin> createState() => _PulsingMapPinState();
}

class _PulsingMapPinState extends State<_PulsingMapPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double base = math.min(constraints.maxWidth, constraints.maxHeight);
        // Match painter's marker geometry
        final double markerSize = base * 0.3; // radius used by painter
        final double markerCenterOffsetY = -markerSize * 0.2; // painter shifts circle up by 0.2R
        // Halo sized tight around marker circle (slightly larger than diameter)
        final double haloDiameter = markerSize * 2 * 1.06;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double t = Curves.easeOut.transform(_controller.value);
            final double haloScale = 1.0 + 0.28 * t; // slightly reduced spread
            final double haloOpacity = (1.0 - t) * 0.28; // slightly dimmer

            return Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing halo behind pin (relative size)
                Transform.translate(
                  offset: Offset(0, markerCenterOffsetY),
                  child: Transform.scale(
                    scale: haloScale,
                    child: Container(
                      width: haloDiameter,
                      height: haloDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Stronger halo: thicker border + outer glow shadow
                        border: Border.all(
                          color: widget.color.withValues(alpha: (haloOpacity * 1.6).clamp(0.0, 1.0)),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: (haloOpacity * 1.2).clamp(0.0, 1.0)),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Marker painter fills available space
                const SizedBox.shrink(),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapPinPainter(
                      color: widget.color,
                      title: widget.title,
                      subtitle: widget.subtitle,
                      customEmoji: widget.customEmoji,
                      labelScale: widget.labelScale,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PulsingArrow extends StatefulWidget {
  final IconData icon;
  const _PulsingArrow({required this.icon});

  @override
  State<_PulsingArrow> createState() => _PulsingArrowState();
}

class _PulsingArrowState extends State<_PulsingArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        final double scale = 0.92 + 0.16 * t; // 0.92..1.08
        final double ringScale = 1.0 + 0.35 * t; // subtle outward ripple
        final double ringOpacity = 0.35 * (1.0 - t);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ripple ring
            Transform.scale(
              scale: ringScale,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: base.withValues(alpha: ringOpacity),
                    width: 2,
                  ),
                ),
              ),
            ),

            // Glowing base circle
            Transform.scale(
              scale: scale,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      base.withValues(alpha: 0.85),
                      base.withValues(alpha: 0.35),
                      base.withValues(alpha: 0.12),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: base.withValues(alpha: 0.35),
                      blurRadius: 22,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 54,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
