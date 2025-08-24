import 'package:video_player/video_player.dart';

import 'main.dart';
import 'package:campus_tour/models/hotspot.dart';
import 'package:campus_tour/services/hotspot_service.dart';
import 'package:flutter/material.dart';

var path = "";

class LocationList extends MyApp {
  const LocationList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = HotspotService();
    // If already loaded, show immediately; otherwise load and then render
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
          : ListView.separated(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              separatorBuilder: (context, index) => const Divider(height: 0),
              itemCount: filteredHotspots.length,
              itemBuilder: (context, index) {
                final hotspot = filteredHotspots[index];

                debugPrint(hotspot.features[0].content);
                return ExpansionTile(
                  maintainState: true,
                  shape: LinearBorder(),
                  collapsedShape: LinearBorder(),
                  tilePadding: EdgeInsets.symmetric(horizontal: 16),

                  title: Text(
                    hotspot.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    hotspot.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(psuGreen).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.place, color: Color(psuGreen)),
                  ),
                  children: <Widget>[
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: hotspot.features.length,
                      itemBuilder: (context, index) {
                        final feature = hotspot.features[index];
                        path = "";

                        // check if the file location is a path or just a file name
                        if (!path.contains(RegExp("/"))) {
                          path =
                              "assets/hotspots/${hotspot.hotspotId}/Assets/${feature.fileLocation}";
                        } else {
                          path = feature.fileLocation;
                        }

                        // build tile for each feature type
                        if (feature.type == "photo") {
                          return ListTile(
                            title: Text(feature.content),
                            subtitle: Image.asset(path),
                          );
                        } else if (feature.type == "video") {
                          return ListTile(
                            title: Text(feature.content),
                            subtitle: VideoPlayerApp(),
                          );
                        } else {
                          return ListTile(
                            title: Text(feature.content[index]),
                            subtitle: Center(
                              child: Text("Error: invalid media type"),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                );
              },
            ),
    );
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
