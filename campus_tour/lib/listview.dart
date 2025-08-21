import 'main.dart';
import 'package:campus_tour/models/hotspot.dart';
import 'package:campus_tour/services/hotspot_service.dart';
import 'package:flutter/material.dart';
import 'dart:io';


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
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              separatorBuilder: (context, index) => const Divider(height: 0),
              itemCount: filteredHotspots.length,
              itemBuilder: (context, index) {
                final hotspot = filteredHotspots[index];
                return ExpansionTile(
                  // contentPadding: const EdgeInsets.symmetric(
                  // horizontal: 16,
                  // vertical: 5,
                  // ),
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
                      color: const Color(0xFF6d8d24).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.place, color: Color(0xFF6d8d24)),
                  ),
                  children: [
                    ListTile(
                      // info goes here \/
                      title: Text(hotspot.updatedAt),
                      //leading: Image.file(myImage,),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
