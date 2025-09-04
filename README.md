# Campus Tour App
## Portland State University Capstone Project 2025

A self-guided tour application for Portland State University that combines GPS location tracking, augmented reality, and multimedia content to provide an engaging campus exploration experience.

---

## App Overview

The Campus Tour App allows users to explore PSU campus through:
- **Interactive Map**: Real-time GPS tracking with hotspot markers
- **AR Camera View**: Augmented reality content overlay
- **Location List**: Browseable list of all available hotspots
- **Multimedia Content**: Photos, videos, and text for each location

---

## Quick Start

### For New Teams
1. **Read the [Quick Start Guide](Quick_Start_Guide.md)** - Get running in 30 minutes
2. **Review the [Full Documentation](Campus_Tour_App_Documentation.md)** - Complete technical details
3. **Check the [Curator Guide](Curator_Guide.md)** - Content management instructions

### For Developers
```bash
# Clone the repository
git clone https://github.com/JPatts/Campus-Tour-App-2025
cd Campus-Tour-App-2025/campus_tour

# Install dependencies
flutter pub get

# Run the app
flutter run
```

---

## Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| [Quick Start Guide](Quick_Start_Guide.md) | Get up and running quickly | New team members |
| [Technical Documentation](Campus_Tour_App_Documentation.md) | Complete technical details | Developers |
| [Curator Guide](Curator_Guide.md) | Content management | Content curators |
| [Project Specification](project_specification.txt) | Original project requirements | All stakeholders |

---

## Architecture

### Technology Stack
- **Framework**: Flutter (Dart)
- **Maps**: Google Maps Flutter
- **Location**: Geolocator
- **Camera**: Camera plugin
- **AR**: Custom implementation
- **Storage**: Local assets (JSON + media files)

### App Structure
```
campus_tour/
├── lib/                    # Main application code
├── assets/hotspots/        # Hotspot content
├── android/               # Android configuration
├── ios/                   # iOS configuration
└── pubspec.yaml          # Dependencies
```

---

## Key Features

### User Features
- Real-time GPS location tracking
- Interactive Google Maps integration
- Augmented reality camera view
- Multimedia content (photos, videos, audio)
- Location-based content triggering
- Offline content access

### Admin Features
- Hidden admin mode (triple-tap Map tab, code: 4231)
- Content management through Git
- Hotspot creation and editing
- Remote content updates

---

## 👥 Team Information

### 2025 Capstone Team
- **Team Lead**: Jonah Pattison
- **Team Members**:
  - Corlin Fardal
  - Jonah Wright
  - Qawi Ntsasa
  - Ryan Mayers
  - Vlad Chevdar

### Sponsor
- **Bruce Irvin**: Portland State University

### Project Timeline
- **Start Date**: June 10, 2025
- **Final Delivery**: August 29, 2025

---

## Development

### Prerequisites
- Flutter SDK (version 3.8.1+)
- Android Studio or VS Code
- Git
- Google Maps API key (for full functionality)

### Setup Instructions
1. Follow the [Quick Start Guide](Quick_Start_Guide.md)
2. Configure Google Maps API key
3. Test on physical devices for GPS/camera features

---

## Security and API Keys

- Previous Google Maps API keys are revoked.
- To enable maps, create your own key and add it here:
  - Android: `campus_tour/android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
  - iOS: `campus_tour/ios/Runner/Info.plist`
- Restrict keys (Android package + SHA-1; iOS bundle ID) and never commit them.
- Note: Xcode Simulator can run without keys; real devices/builds require valid keys.

### Testing
- Unit tests: `flutter test`
- Manual testing checklist in documentation
- Physical device testing required for GPS/AR features

---

## Platform Support

- **Android**: API level 21+
- **iOS**: iOS 12.0+
- **Web**: Chrome, Firefox, Safari (limited functionality)

---

## Hotspot System

Hotspots are physical locations with associated digital content:

```json
{
    "hotspotId": "example",
    "name": "Example Location",
    "description": "Description here",
    "location": {
        "latitude": 45.510866,
        "longitude": -122.683645,
        "radius": 30.0
    },
    "status": "active",
    "features": [...]
}
```

### Content Types
- **Photos**: JPG, PNG, WebP
- **Videos**: MP4, MOV
- **Audio**: MP3, WAV
- **Text**: Plain text or embedded

---

## Deployment

### Android
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Distribution
- Google Play Store (Android)
- App Store (iOS)
- Internal testing available

---

## Support

### Getting Help
1. **Check documentation** first
2. **Search GitHub issues**
3. **Contact team members**
4. **Create new issue** if needed

### Resources
- **Repository**: https://github.com/JPatts/Campus-Tour-App-2025
- **Google Drive**: https://drive.google.com/drive/folders/1Wi-DBqIKGkhZO8AZ6vFMYC2CQDhTulc7
- **Flutter Docs**: https://flutter.dev/docs

---

## License

This project is open source and available under the MIT License.

---

## Contributing

For the next capstone team:
1. **Fork the repository**
2. **Create feature branch**
3. **Make your changes**
4. **Test thoroughly**
5. **Submit pull request**

---

## Contact

- **Repository Issues**: [GitHub Issues](https://github.com/JPatts/Campus-Tour-App-2025/issues)
- **Previous Team Lead**: Jonah Pattison
- **Sponsor**: Bruce Irvin

---

*This project was created for the Campus Tour App capstone project at Portland State University, Summer 2025.*
