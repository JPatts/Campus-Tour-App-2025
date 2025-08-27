import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'package:campus_tour/models/hotspot.dart';
import 'package:campus_tour/services/hotspot_service.dart';
import 'package:flutter/material.dart';
import 'utils/emoji_helper.dart';
import 'map.dart'; // reuse PhotoViewerScreen, VideoPlayerScreen, AudioPlayerWidget
import 'services/visited_service.dart';

var path = "";

class LocationList extends StatefulWidget {
  final bool adminModeEnabled;
  const LocationList({Key? key, this.adminModeEnabled = false}) : super(key: key);

  @override
  State<LocationList> createState() => _LocationListState();
}

class _LocationListState extends State<LocationList> {
  int _tabIndex = 0; // 0 = Visited, 1 = Unvisited
  bool _autoSwitchedOnce = false;

  @override
  Widget build(BuildContext context) {
    final service = HotspotService();
    if (service.isLoaded) {
      final List<Hotspot> children = service.getHostpots();
      return _buildList(children);
    }
    return FutureBuilder<List<Hotspot>>(
      future: service.loadHotspots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Hotspot> children = service.getHostpots();
        return _buildList(children);
      },
    );
  }

  Widget _buildList(List<Hotspot> children) {
    // Filter out test hotspots from the home page
    final filteredHotspots = children
        .where((hotspot) => !hotspot.hotspotId.startsWith('test'))
        .toList();

    return Scaffold(
      body: filteredHotspots.isEmpty
          ? const Center(child: Text('No hotspots available'))
          : FutureBuilder<Map<String, List<Hotspot>>>(
              future: _groupByVisited(filteredHotspots, widget.adminModeEnabled),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final visited = snapshot.data?['visited'] ?? const <Hotspot>[];
                final unvisited = snapshot.data?['unvisited'] ?? const <Hotspot>[];

                // Switch to Unvisited only once when opening Home and Visited is empty
                if (!_autoSwitchedOnce && _tabIndex == 0 && visited.isEmpty && unvisited.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _tabIndex = 1;
                      _autoSwitchedOnce = true;
                    });
                  });
                }

                final currentList = _tabIndex == 0 ? visited : unvisited;

                return Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildSegmentedControl(context),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: currentList.isEmpty
                              ? _buildEmptyState(_tabIndex == 0)
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemCount: currentList.length,
                                  itemBuilder: (ctx, i) => _buildHotspotCard(ctx, currentList[i]),
                                ),
                        ),
                      ],
                    ),
                    // Clear Cache button moved to Map screen per request
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    final Color selectedColor = const Color(psuGreen);
    final Color unselectedColor = Colors.grey.shade300;
    final TextStyle selectedText = const TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    final TextStyle unselectedText = const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600);

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _tabIndex = 0),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tabIndex == 0 ? selectedColor : unselectedColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('Visited', style: _tabIndex == 0 ? selectedText : unselectedText),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _tabIndex = 1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tabIndex == 1 ? selectedColor : unselectedColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('Unvisited', style: _tabIndex == 1 ? selectedText : unselectedText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isVisitedTab) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            
            // Title
            Text(
              isVisitedTab ? 'No Visited Hotspots Yet' : 'All Hotspots Visited!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Description
            Text(
              isVisitedTab 
                ? 'Start exploring PSU campus by visiting hotspots on the map. Each visit unlocks content for 72 hours!'
                : 'Congratulations! You\'ve visited all the hotspots. Check back later for new content or revisit to refresh your access.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Action button
            if (isVisitedTab) ...[
              ElevatedButton.icon(
                onPressed: () {
                  // Switch to map page
                  final nav = HomeWithNav.navKey.currentState;
                  nav?.goToMap();
                },
                icon: const Icon(Icons.map_outlined, size: 20),
                label: const Text('Explore Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6d8d24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ] else ...[
              // Show some stats or tips for completed state
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: Colors.green[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You\'re a PSU expert! Consider sharing your campus knowledge with others.',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Additional tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Tips:',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(isVisitedTab ? [
                    _buildTip('Visit hotspots on the map to unlock content'),
                    _buildTip('Content stays available for 72 hours after visiting'),
                    _buildTip('Use the camera to capture memories at each location'),
                  ] : [
                    _buildTip('Revisit hotspots to refresh your 72-hour access'),
                    _buildTip('Check back regularly for new content updates'),
                    _buildTip('Share your campus discoveries with friends'),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showGreenSnack(BuildContext context, String message) {
  final Color base = const Color(psuGreen);
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              base.withOpacity(0.95),
              base.withOpacity(0.80),
            ],
          ),
          boxShadow: [
            BoxShadow(color: base.withOpacity(0.35), blurRadius: 18, spreadRadius: 2, offset: const Offset(0, 6)),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<void> _promptAndClearVisits(BuildContext context) async {
  final TextEditingController controller = TextEditingController();
  String? errorText;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Clear Cache'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter admin code',
                  errorText: errorText,
                ),
                maxLength: 4,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim() == '4231') {
                  Navigator.of(ctx).pop(true);
                } else {
                  setStateDialog(() => errorText = 'Incorrect code');
                }
              },
              child: const Text('Clear'),
            ),
          ],
        ),
      );
    },
  );

  if (confirmed == true) {
    await VisitedService().clearAllVisits();
    if (context.mounted) _showGreenSnack(context, 'Visit history cleared');
  }
}

class _ClearVisitsFab extends StatelessWidget {
  final Future<void> Function() onClear;
  const _ClearVisitsFab({Key? key, required this.onClear}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onClear,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Icon(Icons.cleaning_services_outlined, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

void _showHotspotContent(BuildContext context, Hotspot hotspot) {
  showDialog(
    context: context,
    builder: (BuildContext ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).primaryColor,
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
                      tooltip: 'Show on map',
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        // Switch to map page
                        final nav = HomeWithNav.navKey.currentState;
                        nav?.goToMap();
                        // Focus on the hotspot
                        final mapState = MapScreen.navKey.currentState;
                        mapState?.focusOnHotspot(hotspot);
                      },
                      icon: const Icon(Icons.map_outlined, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Open in Maps',
                      onPressed: () => _showOpenInMapsSheet(ctx, hotspot),
                      icon: const Icon(Icons.directions_outlined, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...hotspot.features.map((f) => _buildFeatureWidget(context, hotspot, f)),
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

void _showLockedDialog(BuildContext context, Hotspot hotspot) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Content locked'),
      content: const Text('Visit this hotspot on the map to unlock its content for 72 hours.'),
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(ctx).pop();
            // Switch to map page
            final nav = HomeWithNav.navKey.currentState;
            nav?.goToMap();
            // Focus on the hotspot
            final mapState = MapScreen.navKey.currentState;
            mapState?.focusOnHotspot(hotspot);
          },
          icon: const Icon(Icons.location_on, size: 18),
          label: const Text('See Hotspot'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6d8d24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

Future<Map<String, List<Hotspot>>> _groupByVisited(List<Hotspot> hotspots, bool adminModeEnabled) async {
  final service = VisitedService();
  final List<bool> flags = await Future.wait(
    hotspots.map((h) => service.isVisitedEffective(h.hotspotId, adminModeEnabled: false)),
  );
  final List<Hotspot> visited = [];
  final List<Hotspot> unvisited = [];
  for (int i = 0; i < hotspots.length; i++) {
    if (flags[i]) {
      visited.add(hotspots[i]);
    } else {
      unvisited.add(hotspots[i]);
    }
  }
  return {'visited': visited, 'unvisited': unvisited};
}

Widget _buildHotspotCard(BuildContext context, Hotspot hotspot) {
  final bool isAdmin = context.findAncestorWidgetOfExactType<LocationList>()?.adminModeEnabled ?? false;
  return InkWell(
    onTap: () async {
      final bool visitedRecently = await VisitedService().isVisitedEffective(hotspot.hotspotId, adminModeEnabled: isAdmin);
      if (isAdmin || visitedRecently) {
        _showHotspotContent(context, hotspot);
      } else {
        _showLockedDialog(context, hotspot);
      }
    },
    borderRadius: BorderRadius.circular(16),
    child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6d8d24).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              EmojiHelper.emojiForName(hotspot.name),
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hotspot.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hotspot.description,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
            const SizedBox(width: 8),
            _ExpiryTimerChip(hotspotId: hotspot.hotspotId, adminModeEnabled: isAdmin),
          ],
        ),
      ),
    ),
  );
}

class _ExpiryTimerChip extends StatefulWidget {
  final String hotspotId;
  final bool adminModeEnabled;
  const _ExpiryTimerChip({Key? key, required this.hotspotId, required this.adminModeEnabled}) : super(key: key);

  @override
  State<_ExpiryTimerChip> createState() => _ExpiryTimerChipState();
}

class _ExpiryTimerChipState extends State<_ExpiryTimerChip> {
  DateTime? _lastVisitedReal;
  DateTime? _lastVisitedFake;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  Future<void> _load() async {
    final real = await VisitedService().getLastVisitedReal(widget.hotspotId);
    final fake = await VisitedService().getLastVisitedFake(widget.hotspotId);
    if (mounted) setState(() { _lastVisitedReal = real; _lastVisitedFake = fake; });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.adminModeEnabled) {
      return _buildChip('Admin', const Color(psuGreen), Colors.white);
    }
    final remaining = _remainingDuration();
    if (remaining == null || remaining.isNegative) {
      return _buildChip('Locked', Colors.grey.shade300, Colors.black87);
    }
    final label = _formatDurationShort(remaining);
    return _buildChip(label, const Color(psuGreen), Colors.white);
  }

  Duration? _remainingDuration() {
    if (_lastVisitedReal != null) {
      return _lastVisitedReal!.add(const Duration(hours: 72)).difference(DateTime.now());
    }
    if (_lastVisitedFake != null) {
      return _lastVisitedFake!.add(const Duration(seconds: 10)).difference(DateTime.now());
    }
    return null;
  }

  String _formatDurationShort(Duration d) {
    final int days = d.inDays;
    final int hours = d.inHours % 24;
    final int minutes = d.inMinutes % 60;
    final int seconds = d.inSeconds % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  Widget _buildChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}



Widget _buildFeatureWidget(BuildContext context, Hotspot hotspot, HotspotFeature feature) {
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
          _buildMediaContent(context, hotspot, feature),
          if (feature.postedDate != null || feature.author != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (feature.postedDate != null)
                  Text(
                    feature.postedDate!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                if (feature.postedDate != null && feature.author != null)
                  Text(
                    ' • ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                if (feature.author != null)
                  Text(
                    feature.author!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildMediaContent(BuildContext context, Hotspot hotspot, HotspotFeature feature) {
  final String assetPath = 'assets/hotspots/${hotspot.hotspotId}/Assets/${feature.fileLocation}';
  switch (feature.type.toLowerCase()) {
    case 'photo':
    case 'image':
      return _buildPhotoContent(context, assetPath);
    case 'video':
      return _buildVideoContent(context, assetPath, feature.content);
    case 'audio':
      return AudioPlayerWidget(
        assetPath: assetPath,
        description: feature.content,
      );
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

Widget _buildPhotoContent(BuildContext context, String assetPath) {
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

Widget _buildVideoContent(BuildContext context, String assetPath, String title) {
  return GestureDetector(
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(assetPath: assetPath, title: title),
        ),
      );
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
                  Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
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
              return Stack(
                children: [
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
                  Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
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

Future<VideoPlayerController> _createVideoThumbnail(String assetPath) async {
  final controller = VideoPlayerController.asset(assetPath);
  try {
    await controller.initialize();
    await controller.seekTo(const Duration(seconds: 1));
    return controller;
  } catch (e) {
    return controller;
  }
}

void _showOpenInMapsSheet(BuildContext context, Hotspot hotspot) {
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
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }
}

IconData _getIconForFeatureType(String type) {
  switch (type.toLowerCase()) {
    case 'photo':
    case 'image':
      return Icons.photo;
    case 'video':
      return Icons.video_library;
    case 'audio':
      return Icons.audiotrack;
    default:
      return Icons.info;
  }
}

class VideoPlayerApp extends StatefulWidget {
  const VideoPlayerApp({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _VideoPlayerAppState createState() => _VideoPlayerAppState();
}

class _VideoPlayerAppState extends State<VideoPlayerApp> {
  late VideoPlayerController _controller;
  // late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();

    // Create and store the VideoPlayerController. The VideoPlayerController
    // offers several different constructors to play videos from assets, files,
    // or the internet.
    _controller = VideoPlayerController.asset(path);

    // Initialize the controller and store the Future for later use.
    // _initializeVideoPlayerFuture = _controller.initialize();
    _controller.initialize();

    // Use the controller to loop the video.
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    // Ensure disposing of the VideoPlayerController to free up resources.
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Scaffold(
      body: Center(child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Wrap the play or pause in a call to `setState`. This ensures the
          // correct icon is shown.
          setState(() {
            // If the video is playing, pause it.
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              // If the video is paused, play it.
              _controller.play();
            }
          });
        },
        // Display the correct icon depending on the state of the player.
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    )
    );
  }
}
