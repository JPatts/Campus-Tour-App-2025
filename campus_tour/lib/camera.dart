import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ar_location_view/ar_location_view.dart';
import 'models/hotspot.dart';
import 'models/hotspot_annotation.dart';
import 'services/hotspot_service.dart';
import 'services/location_service.dart';
import 'helpers/hotspot_helpers.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final HotspotService _hotspotService = HotspotService();
  final bool _testingMode = false;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  List<HotspotAnnotation> _annotations = [];

  List<Hotspot> _hotspots = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  static Future<void> requestCameraPermission() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (!status.isGranted) {
        throw Exception('Camera permission denied');
      }
    }
  }

  Future<void> _initialize() async {
    try {
      await LocationService.requestLocationPermission();
      await requestCameraPermission();
      _currentPosition = await LocationService.getCurrentLocation();
      _hotspots = await _hotspotService.loadHotspots();
      _annotations = _getHotspotAnnotations(Position(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: _currentPosition!.altitude,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ));
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing camera: $e';
      });
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
            Text('Loading Camera...'),
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
                _initialize();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: ArLocationWidget(
        annotations: _annotations,
        annotationViewBuilder: (context, annotation) {
          if (annotation is HotspotAnnotation) {
            return HotspotAnnotationView(annotation: annotation);
          }
          return const SizedBox();
        },
        onLocationChange: _onLocationChange,
      ),
    );
  }

  List<HotspotAnnotation> _getHotspotAnnotations(Position position) {
    return _hotspots
      .where((hotspot) => isHotspotUnlocked(
        hotspot: hotspot,
        userPosition: position,
        testingMode: _testingMode,
      ))
      .map((hotspot) => HotspotAnnotation(hotspot: hotspot))
      .toList();
  }

  void _onLocationChange(Position position) {
    final updated = _getHotspotAnnotations(position);

    setState(() {
      _annotations = updated;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}
