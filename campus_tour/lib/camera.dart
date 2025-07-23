import 'package:flutter/material.dart';
import 'dart:math';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Vector4;
import 'package:geolocator/geolocator.dart';
import 'models/hotspot.dart';
import 'services/hotspot_service.dart';
import 'services/location_service.dart';
import 'helpers/hotspot_helpers.dart';
import 'helpers/geo_helpers.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late ARSessionManager _arSessionManager;
  late ARObjectManager _arObjectManager;
  final HotspotService _hotspotService = HotspotService();
  final bool _testingMode = false;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';

  List<Hotspot> _hotspots = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await LocationService.requestLocationPermission();
      _currentPosition = await LocationService.getCurrentLocation();
      _hotspots = await _hotspotService.loadHotspots();
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
      body: ARView(
        onARViewCreated: _onARViewCreated,
      ),
    );
  }

  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager _,
    ARLocationManager _,
  ) async {
    _arSessionManager = sessionManager;
    _arObjectManager = objectManager;

    await _arSessionManager.onInitialize();
    await _arObjectManager.onInitialize();

    await _addHotspotModels(_hotspots);
  }

  Future<void> _addHotspotModels(List<Hotspot> hotspots) async {
    if (_hotspots.isEmpty) {
      debugPrint('No unlocked hotspots to show in AR.');
      return;
    }

    for (final hotspot in _hotspots) {
      if (!isHotspotUnlocked(hotspot: hotspot, userPosition: _currentPosition, testingMode: _testingMode)) continue;

      final feature = hotspot.getARModelFeature();
      if (feature == null) continue;
      final assetPath = getAssetPath(hotspot, feature);

      // Compute bearing and rotation
      final bearing = computeBearing(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        hotspot.location.latitude,
        hotspot.location.longitude,
      );

      final direction = bearingToDirection(bearing);
      final rotationAngle = atan2(direction.x, direction.z); // Rotation around Y-axis
      final rotation = Vector4(0, 1, 0, rotationAngle);

      // Place model 5 meters in front of user
      final position = Vector3(0, 0, -5); // Forward in AR space

      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: assetPath,
        scale: Vector3.all(0.2),
        position: position,
        rotation: rotation,
      );

      final didAdd = await _arObjectManager.addNode(node);
      if (didAdd == null || !didAdd) {
        debugPrint('Failed to add AR node for hotspot ${hotspot.hotspotId}');
      }
    }
  }

  @override
  void dispose() {
    _arSessionManager.dispose();
    super.dispose();
  }
}
