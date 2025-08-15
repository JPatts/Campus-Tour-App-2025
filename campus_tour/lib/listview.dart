import 'package:campus_tour/main.dart';
import 'package:campus_tour/models/hotspot.dart';
import 'package:flutter/material.dart';

class LocationList extends MyApp{
  const LocationList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Hotspot> children = myService.getHostpots();
    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: children.length,
        itemBuilder: (context, index) {
          final hotspot = children[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                color: const Color(0xFF213921).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.place, color: Color(0xFF213921)),
            ),
          );
        },
      ),
    );
  }
}