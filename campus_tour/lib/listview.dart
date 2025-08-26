import 'main.dart';
import 'package:campus_tour/models/hotspot.dart';
import 'package:campus_tour/services/hotspot_service.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'utils/emoji_helper.dart';


var myImage = File(
  '../assets/hotspots/exampleHotspot/Assets/photoOfBali.jpg',
);

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: filteredHotspots.length,
              itemBuilder: (context, index) {
                final hotspot = filteredHotspots[index];
                return Card(
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
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
