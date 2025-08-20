import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'models/hotspot.dart';
import 'services/hotspot_service.dart';

class MapBoxMapScreen extends StatefulWidget {
  const MapBoxMapScreen({super.key});

  @override
  State<MapBoxMapScreen> createState() => _MapBoxMapScreenState();
}

class _MapBoxMapScreenState extends State<MapBoxMapScreen> {
  MapboxMap? _mapboxMap;
  final HotspotService _hotspotService = HotspotService();
  List<Hotspot> _hotspots = [];
  Position? _currentPosition;
  bool _isLoading = true;

  // PSU Campus Center Coordinates
  static const Point _psuCenter = Point(coordinates: Position(-122.686242, 45.51154));

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _loadHotspots();
    await _getCurrentLocation();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadHotspots() async {
    if (!_hotspotService.isLoaded) {
      await _hotspotService.loadHotspots();
    }
    setState(() {
      _hotspots = _hotspotService.hotspots;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _addHotspotMarkers();
  }

  void _addHotspotMarkers() async {
    if (_mapboxMap == null) return;

    for (final hotspot in _hotspots) {
      final point = Point(
        coordinates: Position(
          hotspot.location.longitude,
          hotspot.location.latitude,
        ),
      );

      await _mapboxMap!.style.addSource(
        GeoJsonSource(
          id: 'hotspot-${hotspot.hotspotId}',
          data: point.toJson(),
        ),
      );

      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: 'hotspot-symbol-${hotspot.hotspotId}',
          sourceId: 'hotspot-${hotspot.hotspotId}',
          iconImage: 'marker-15',
          iconSize: 1.5,
          textField: hotspot.name,
          textOffset: [0, 1.5],
          textAnchor: 'top',
          textSize: 12,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PSU Campus Map'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        resourceOptions: ResourceOptions(
          accessToken: 'pk.eyJ1IjoiY2hldmRhciIsImEiOiJjbWVobG9md2UwMjRlMm9vZWs0YTA0OHp2In0.58Zl7_5u_q1J6rXXgZVsXw',
        ),
        styleUri: MapboxStyles.MAPBOX_STREETS,
        cameraOptions: CameraOptions(
          center: _currentPosition != null 
            ? Point(coordinates: Position(_currentPosition!.longitude, _currentPosition!.latitude))
            : _psuCenter,
          zoom: 16.0,
        ),
        onMapLoaded: _onMapLoaded,
        onMapCreated: _onMapCreated,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnUser,
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _onMapLoaded() {
    _addHotspotMarkers();
  }

  void _centerOnUser() async {
    if (_mapboxMap != null && _currentPosition != null) {
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  @override
  void dispose() {
    _mapboxMap?.dispose();
    super.dispose();
  }
}
