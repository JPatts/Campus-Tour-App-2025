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
      throw Exception('Camera permission denied');
    }
    if (statuses[Permission.locationWhenInUse] != PermissionStatus.granted) {
      throw Exception('Location permission denied');
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

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: const TextStyle(color: Colors.red)));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: const Color(0xFF213921)),
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
            color: const Color(0xFF213921),
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
                // Only render if within some max range (e.g., 500m)
                if (distanceM > 800) continue;
                
                hasNearbyHotspots = true;
                final targetBearing = _bearingTo(hs);
                final screenPos = _projectHotspotToScreen(size, targetBearing);

                // Opacity fades out as hotspot leaves FOV
                final double angleDiff = (targetBearing - _headingDegrees + 540) % 360 - 180; // [-180,180]
                final double fovHalf = 32.5; // half of 65
                final double visibility = (1 - (angleDiff.abs() / (fovHalf * 1.2))).clamp(0.0, 1.0);

                // Marker footprint and size
                final double baseSize = 140;
                final double scale = (1.0 - (distanceM / 800)).clamp(0.25, 1.0);
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
                                child: CustomPaint(
                                  painter: _MapPinPainter(
                                    color: Theme.of(context).colorScheme.primary,
                                    title: hs.name,
                                    subtitle: _formatRemainingFeet(
                                      distanceM,
                                      hs.location.radius * 3.28084, // threshold in feet, per-hotspot
                                    ),
                                  ),
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
                  // No nearby hotspots at all
                  widgets.add(
                    Positioned(
                      top: size.height * 0.35,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.9),
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Animated icon container
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.location_off_rounded,
                                  color: Colors.red.shade300,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No nearby hotspots',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Move to a different location\nto find AR hotspots',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              // Directional arrow hint
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_walk,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Try walking around',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  // Has nearby hotspots but not in view - need to turn phone
                  widgets.add(
                    Positioned(
                      top: size.height * 0.35,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.9),
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Animated icon container
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.rotate_right_rounded,
                                  color: Colors.orange.shade300,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Turn your phone',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Point your camera in different\ndirections to find hotspots',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              // Directional arrows hint
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.swap_horiz,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Sweep left and right',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }

              // Heading HUD
              widgets.add(
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_headingDegrees.toStringAsFixed(0)}°',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              );

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
      return '${miles.toStringAsFixed(1)} miles left';
    }
    return '${remaining.toStringAsFixed(0)} ft left';
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
}

class _MapPinPainter extends CustomPainter {
  final Color color;
  final String title;
  final String subtitle;
  _MapPinPainter({required this.color, required this.title, required this.subtitle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double base = math.min(size.width, size.height);
    final double headRadius = base * 0.26;

    // Compute pin geometry
    final Offset headCenter = Offset(center.dx, center.dy - headRadius * 0.2);
    final Offset tip = Offset(center.dx, center.dy + headRadius * 2.15);

    // Build a classic drop-pin path: circle head + curved tail to tip
    final Path pinPath = Path();
    // Head circle path (approximate by arc)
    pinPath.addOval(Rect.fromCircle(center: headCenter, radius: headRadius));
    // Tail path (rounded triangular using beziers)
    final double tailWidth = headRadius * 0.9;
    final Offset leftAttach = Offset(headCenter.dx - tailWidth * 0.55, headCenter.dy + headRadius * 0.3);
    final Offset rightAttach = Offset(headCenter.dx + tailWidth * 0.55, headCenter.dy + headRadius * 0.3);
    final Path tail = Path()
      ..moveTo(leftAttach.dx, leftAttach.dy)
      ..quadraticBezierTo(
        headCenter.dx - tailWidth * 0.25,
        headCenter.dy + headRadius * 1.1,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        headCenter.dx + tailWidth * 0.25,
        headCenter.dy + headRadius * 1.1,
        rightAttach.dx,
        rightAttach.dy,
      )
      ..close();

    // Combine head + tail by drawing tail then overlay head to keep perfect circle
    // Shadow for the tail
    canvas.drawShadow(tail, Colors.black.withValues(alpha: 0.35), 6, true);

    // Gradient fill for head
    final HSLColor hsl = HSLColor.fromColor(color);
    final Color light = hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
    final Color dark = hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor();
    final Paint tailFill = Paint()..color = dark.withValues(alpha: 0.95);
    final Paint headFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, dark],
      ).createShader(Rect.fromCircle(center: headCenter, radius: headRadius));

    // Stroke/border
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: 0.95);

    // Draw tail and head
    canvas.drawPath(tail, tailFill);
    canvas.drawCircle(headCenter, headRadius, headFill);
    canvas.drawCircle(headCenter, headRadius, border);

    // Inner white dot for precision
    canvas.drawCircle(headCenter, headRadius * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Ground ellipse (subtle contact shadow)
    final double ellipseW = headRadius * 2.0;
    final double ellipseH = headRadius * 0.55;
    final Rect ellipseRect = Rect.fromCenter(
      center: Offset(center.dx, tip.dy + headRadius * 0.18),
      width: ellipseW,
      height: ellipseH,
    );
    final Paint ground = Paint()..color = Colors.black.withValues(alpha: 0.12);
    canvas.drawOval(ellipseRect, ground);

    // Label (two-line chip)
    final double maxLabelWidth = size.width * 0.92;
    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 13,
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
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: 0.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxLabelWidth);

    const double labelHPad = 10.0;
    const double labelVPad = 7.0;
    const double lineSpacing = 2.0;

    final double contentWidth = math.max(titlePainter.width, subtitlePainter.width);
    final double contentHeight = titlePainter.height + lineSpacing + subtitlePainter.height;

    final RRect chip = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, ellipseRect.center.dy + ellipseRect.height / 2 + 16),
        width: contentWidth + 2 * labelHPad,
        height: contentHeight + 2 * labelVPad,
      ),
      const Radius.circular(12),
    );

    // Drop shadow for the chip
    final Paint chipShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.save();
    canvas.translate(0, 1);
    canvas.drawRRect(chip, chipShadow);
    canvas.restore();

    // Chip background
    final Paint chipBg = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawRRect(chip, chipBg);

    final double titleLeft = chip.center.dx - (titlePainter.width / 2);
    final double subtitleLeft = chip.center.dx - (subtitlePainter.width / 2);
    titlePainter.paint(canvas, Offset(titleLeft, chip.top + labelVPad));
    subtitlePainter.paint(
      canvas,
      Offset(
        subtitleLeft,
        chip.top + labelVPad + titlePainter.height + lineSpacing,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.title != title || oldDelegate.subtitle != subtitle;
  }
}
