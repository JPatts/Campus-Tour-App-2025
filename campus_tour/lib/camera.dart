import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
    if (cam == null || !cam.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        if (_cameraController != null)
          FutureBuilder<void>(
            future: _cameraInitFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ColoredBox(color: Colors.black);
              }
              return CameraPreview(_cameraController!);
            },
          )
        else
          const ColoredBox(color: Colors.black),

        // AR overlay
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final position = _currentPosition;
              if (position == null) return const SizedBox.shrink();

              final widgets = <Widget>[];
              for (final hs in _hotspots) {
                final double distanceM = _hotspotService.calculateDistance(
                  position.latitude,
                  position.longitude,
                  hs.location.latitude,
                  hs.location.longitude,
                );
                // Only render if within some max range (e.g., 500m)
                if (distanceM > 800) continue;
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
                                    color: Colors.red,
                                    title: hs.name,
                                    subtitle: _formatRemainingFeet(distanceM, 200),
                                  ),
                                ),
                          ),
                      ),
                    ),
                  ),
                );
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hs.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(hs.description, style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 8),
              Text(_formatDistance(distanceM), style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m away';
    return '${(meters / 1000).toStringAsFixed(2)} km away';
  }

  String _formatRemainingFeet(double meters, double thresholdFeet) {
    final double feet = meters * 3.28084;
    final double remaining = (feet - thresholdFeet).clamp(0, double.infinity);
    return '${remaining.toStringAsFixed(0)} ft left';
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
    final double r = base * 0.28; // head radius

    // Taller triangle, no circular head
    final Offset tip = Offset(center.dx, center.dy + r * 2.2);
    final Offset leftBase = Offset(center.dx - r * 0.9, center.dy - r * 0.2);
    final Offset rightBase = Offset(center.dx + r * 0.9, center.dy - r * 0.2);

    final Paint fill = Paint()..color = color.withOpacity(0.95);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0
      ..color = Colors.transparent
      ..strokeJoin = StrokeJoin.round;

    // Pointer body (triangle only)
    final Path body = Path()
      ..moveTo(leftBase.dx, leftBase.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..close();
    canvas.drawPath(body, fill);
    // No stroke and no head circle

    // Base ground ring
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withOpacity(0.95);
    final double ringR = r * 0.9;
    final Offset ringCenter = Offset(center.dx, tip.dy + r * 0.2);
    canvas.drawCircle(ringCenter, ringR, ringPaint);

    // Label background (two lines: title + distance)
    final double maxLabelWidth = size.width * 0.9;
    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxLabelWidth);

    final TextPainter subtitlePainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxLabelWidth);

    const double labelPadding = 6.0;
    const double lineSpacing = 2.0;

    final double contentWidth = math.max(titlePainter.width, subtitlePainter.width);
    final double contentHeight = titlePainter.height + lineSpacing + subtitlePainter.height;

    final RRect rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, ringCenter.dy + ringR + 14),
        width: contentWidth + 2 * labelPadding,
        height: contentHeight + 2 * labelPadding,
      ),
      const Radius.circular(8),
    );

    final Paint bg = Paint()..color = Colors.black54;
    canvas.drawRRect(rect, bg);
    final double titleLeft = rect.center.dx - (titlePainter.width / 2);
    final double subtitleLeft = rect.center.dx - (subtitlePainter.width / 2);
    titlePainter.paint(canvas, Offset(titleLeft, rect.top + labelPadding));
    subtitlePainter.paint(
      canvas,
      Offset(
        subtitleLeft,
        rect.top + labelPadding + titlePainter.height + lineSpacing,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.title != title || oldDelegate.subtitle != subtitle;
  }
}
