class Hotspot {
  final String hotspotId;
  final String name;
  final String description;
  final HotspotLocation location;
  final String createdAt;
  final String updatedAt;
  final String status;
  final List<HotspotFeature> features;

  Hotspot({
    required this.hotspotId,
    required this.name,
    required this.description,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.features,
  });

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    return Hotspot(
      hotspotId: json['hotspotId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      location: HotspotLocation.fromJson(json['location'] ?? {}),
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      status: json['status'] ?? 'inactive',
      features: (json['features'] as List<dynamic>?)
          ?.map((feature) => HotspotFeature.fromJson(feature))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hotspotId': hotspotId,
      'name': name,
      'description': description,
      'location': location.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'status': status,
      'features': features.map((feature) => feature.toJson()).toList(),
    };
  }
}

class HotspotLocation {
  final double latitude;
  final double longitude;
  final double radius;

  HotspotLocation({
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory HotspotLocation.fromJson(Map<String, dynamic> json) {
    return HotspotLocation(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      radius: (json['radius'] ?? 50.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }
}

class HotspotFeature {
  final String featureId;
  final String type;
  final String content;
  final String fileLocation;
  final String? postedDate;
  final String? author;

  HotspotFeature({
    required this.featureId,
    required this.type,
    required this.content,
    required this.fileLocation,
    this.postedDate,
    this.author,
  });

  factory HotspotFeature.fromJson(Map<String, dynamic> json) {
    return HotspotFeature(
      featureId: json['featureId'] ?? '',
      type: json['type'] ?? '',
      content: json['content'] ?? '',
      fileLocation: json['fileLocation'] ?? '',
      postedDate: json['postedDate'],
      author: json['author'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'featureId': featureId,
      'type': type,
      'content': content,
      'fileLocation': fileLocation,
      if (postedDate != null) 'postedDate': postedDate,
      if (author != null) 'author': author,
    };
  }
} 