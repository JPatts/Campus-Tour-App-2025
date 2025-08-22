# Campus Tour App - Technical Documentation
## Portland State University Capstone Project 2025

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture & Design](#architecture--design)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Core Components](#core-components)
6. [Hotspot System](#hotspot-system)
7. [Setup & Installation](#setup--installation)
8. [Development Guidelines](#development-guidelines)
9. [Testing](#testing)
10. [Deployment](#deployment)
11. [Troubleshooting](#troubleshooting)
12. [Future Enhancements](#future-enhancements)
13. [Team Information](#team-information)

---

## Project Overview

### Purpose
The Campus Tour App is a self-guided tour application for Portland State University that allows users to explore campus locations through an interactive mobile experience. The app combines GPS location tracking, augmented reality (AR), and multimedia content to provide an engaging campus tour experience.

### Key Features
- **Interactive Map**: Real-time GPS tracking with hotspot markers
- **AR Camera View**: Augmented reality content overlay through device camera
- **Location List**: Browseable list of all available hotspots
- **Multimedia Content**: Photos, videos, and text content for each location
- **Admin Mode**: Hidden administrative features for content management
- **Cross-Platform**: Works on both iOS and Android devices

### Target Users
- **Tourists**: Visitors exploring PSU campus
- **Prospective Students**: Individuals considering PSU
- **Campus Visitors**: Anyone wanting to learn about PSU locations
- **Curators**: Content managers who update tour information

---

## Architecture & Design

### High-Level Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Tourist User  │    │   Curator       │    │   Git Repository│
│   (Mobile App)  │◄──►│   (Content Mgmt)│◄──►│   (Asset Store) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Hotspot JSON  │    │   Assets Folder │
│   (Frontend)    │    │   Files         │    │   Structure     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### App Structure
The app follows a three-tab navigation pattern:
1. **Map Tab** (Left): Interactive Google Maps with GPS tracking
2. **Home Tab** (Center): List of discovered locations
3. **AR Tab** (Right): Camera view with AR overlays

### Data Flow
1. App loads hotspot data from JSON files in assets
2. GPS service tracks user location in real-time
3. Location service determines proximity to hotspots
4. Content is displayed based on user location and interaction
5. Curator updates content by modifying JSON files and assets

---

## Technology Stack

### Core Framework
- **Flutter**: Cross-platform mobile development framework
- **Dart**: Programming language for Flutter development

### Key Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  cupertino_icons: ^1.0.8
  geolocator: ^9.0.2                    # GPS location tracking
  permission_handler: ^10.4.5           # Device permissions
  google_maps_flutter: ^2.8.0           # Interactive maps
  camera: ^0.10.5+9                     # Device camera access
  flutter_compass: ^0.8.0               # Compass/heading data
  sensors_plus: ^6.1.1                  # Device sensors
  vector_math: ^2.1.4                   # Mathematical operations
  url_launcher: ^6.3.0                  # External link handling
  video_player: ^2.8.2                  # Video playback
  audioplayers: ^6.0.0                  # Audio playback
```

### Development Tools
- **Android Studio**: Android development and testing
- **Xcode**: iOS development and testing
- **VS Code**: Code editing (optional)
- **Git/GitHub**: Version control and collaboration

---

## Project Structure

```
campus_tour/
├── lib/                          # Main application code
│   ├── main.dart                 # App entry point and navigation
│   ├── map.dart                  # Map screen implementation
│   ├── camera.dart               # AR camera screen
│   ├── listview.dart             # Location list screen
│   ├── models/
│   │   └── hotspot.dart          # Data models
│   └── services/
│       └── hotspot_service.dart  # Business logic
├── assets/                       # Static assets
│   ├── hotspots/                 # Hotspot content
│   │   ├── parkingStructureOne/
│   │   ├── psuLibrary/
│   │   ├── psuScottCenter/
│   │   └── [other hotspots]/
│   └── app_logo/                 # App branding
├── android/                      # Android-specific configuration
├── ios/                          # iOS-specific configuration
├── pubspec.yaml                  # Dependencies and configuration
└── README.md                     # Project documentation
```

---

## Core Components

### 1. Main Application (`main.dart`)
**Purpose**: Application entry point and navigation controller

**Key Features**:
- App initialization and theme configuration
- PageView navigation between Map, Home, and AR screens
- Admin mode activation (triple-tap on Map tab)
- Portrait orientation lock

**Important Classes**:
- `MyApp`: Main app widget with theme configuration
- `HomeWithNav`: Navigation controller with PageView
- Admin mode code: `4231`

### 2. Map Screen (`map.dart`)
**Purpose**: Interactive map with GPS tracking and hotspot markers

**Key Features**:
- Google Maps integration with custom markers
- Real-time GPS location tracking
- Hotspot proximity detection
- Photo/video viewer with zoom capabilities
- Admin mode features for content management

**Important Functions**:
- `_updateUserLocation()`: Updates user position on map
- `_checkHotspotProximity()`: Detects when user enters hotspot radius
- `_showHotspotContent()`: Displays hotspot multimedia content

### 3. AR Camera Screen (`camera.dart`)
**Purpose**: Augmented reality view with camera overlay

**Key Features**:
- Live camera feed with AR content overlay
- Compass-based orientation tracking
- Hotspot detection in camera view
- Permission handling for camera and location

**Important Functions**:
- `_setupCamera()`: Initializes device camera
- `_startLocationStream()`: Continuous GPS tracking
- `_startHeadingStream()`: Compass heading updates

### 4. Location List (`listview.dart`)
**Purpose**: Browseable list of all available hotspots

**Key Features**:
- Expandable list of hotspots
- Filtered view (excludes test hotspots)
- Hotspot information display
- Integration with HotspotService

### 5. Hotspot Service (`services/hotspot_service.dart`)
**Purpose**: Business logic for hotspot management

**Key Features**:
- Singleton pattern for data management
- JSON file loading from assets
- Distance calculation using Haversine formula
- Proximity detection algorithms

**Important Methods**:
- `loadHotspots()`: Loads hotspot data from JSON files
- `getHotspotsNearLocation()`: Finds hotspots within specified radius
- `isUserInHotspot()`: Checks if user is within hotspot boundaries

---

## Hotspot System

### Hotspot Data Structure
Each hotspot is defined by a JSON file with the following structure:

```json
{
    "hotspotId": "unique_identifier",
    "name": "Human-readable name",
    "description": "Brief description",
    "location": {
        "latitude": 45.510866,
        "longitude": -122.683645,
        "radius": 33.10
    },
    "createdAt": "2025-08-14T12:00:00Z",
    "updatedAt": "2025-08-14T12:00:00Z",
    "status": "active",
    "features": [
        {
            "featureId": "1",
            "type": "photo|video|audio|text",
            "content": "Description of content",
            "fileLocation": "filename.ext",
            "postedDate": "Aug 10, 2025",
            "author": "Campus Tour Team"
        }
    ]
}
```

### Hotspot Directory Structure
```
assets/hotspots/[hotspotName]/
├── hotspot.json              # Hotspot configuration
└── Assets/                   # Multimedia content
    ├── photo.jpg
    ├── video.mov
    ├── audio.mp3
    └── text.txt
```

### Adding New Hotspots
1. Create new directory in `assets/hotspots/`
2. Add `hotspot.json` with proper configuration
3. Add multimedia assets to `Assets/` subdirectory
4. Update `hotspot_service.dart` to include new directory
5. Test hotspot functionality

---

## Setup & Installation

### Prerequisites
- Flutter SDK (version 3.8.1 or higher)
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)
- Git for version control

### Installation Steps

1. **Clone Repository**
   ```bash
   git clone https://github.com/JPatts/Campus-Tour-App-2025
   cd Campus-Tour-App-2025/campus_tour
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Platform Setup**
   
   **Android**:
   - Open `android/app/build.gradle.kts`
   - Ensure Google Maps API key is configured
   - Set minimum SDK version to 21

   **iOS**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Configure Google Maps API key in `AppDelegate.swift`
   - Set deployment target to iOS 12.0+

4. **API Keys Configuration**
   
   **Google Maps API Key**:
   - Obtain API key from Google Cloud Console
   - Enable Maps SDK for Android/iOS
   - Add key to platform-specific configuration files

5. **Run Application**
   ```bash
   flutter run
   ```

### Environment Configuration
- **Portrait Mode**: App is locked to portrait orientation
- **Permissions**: Camera and location permissions required
- **GPS**: High-accuracy GPS recommended for best experience

---

## Development Guidelines

### Code Style
- Follow Dart/Flutter conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent indentation (2 spaces)

### File Organization
- Keep related functionality in same directory
- Use descriptive file names
- Separate models, services, and UI components

### State Management
- Use StatefulWidget for local state
- Implement singleton pattern for global services
- Minimize widget rebuilds with proper state management

### Error Handling
- Implement try-catch blocks for async operations
- Provide user-friendly error messages
- Log errors for debugging purposes

### Performance Considerations
- Optimize image and video loading
- Implement lazy loading for large lists
- Cache frequently accessed data
- Minimize GPS polling frequency

---

## Testing

### Unit Testing
```bash
flutter test
```

### Widget Testing
- Test individual UI components
- Verify navigation functionality
- Test user interactions

### Integration Testing
- Test complete user workflows
- Verify GPS functionality
- Test AR features on physical devices

### Manual Testing Checklist
- [ ] App launches without errors
- [ ] GPS location tracking works
- [ ] Map displays correctly
- [ ] Hotspots appear on map
- [ ] AR camera view functions
- [ ] Content displays properly
- [ ] Admin mode activation works
- [ ] Cross-platform compatibility

---

## Deployment

### Android Deployment
1. **Build APK**
   ```bash
   flutter build apk --release
   ```

2. **Build App Bundle**
   ```bash
   flutter build appbundle --release
   ```

3. **Google Play Store**
   - Upload app bundle to Google Play Console
   - Configure store listing
   - Submit for review

### iOS Deployment
1. **Build iOS App**
   ```bash
   flutter build ios --release
   ```

2. **App Store Connect**
   - Archive app in Xcode
   - Upload to App Store Connect
   - Configure app metadata
   - Submit for review

### Distribution Options
- **Internal Testing**: Use TestFlight (iOS) or internal testing (Android)
- **Beta Testing**: Distribute to limited user group
- **Production**: Public release on app stores

---

## Troubleshooting

### Common Issues

**GPS Not Working**
- Check location permissions
- Verify GPS is enabled on device
- Test in outdoor environment
- Check API key configuration

**AR Content Not Displaying**
- Verify camera permissions
- Check asset file paths
- Test on physical device (not simulator)
- Ensure proper file formats

**Map Not Loading**
- Verify Google Maps API key
- Check internet connection
- Ensure API key has proper permissions
- Verify billing is enabled

**App Crashes**
- Check Flutter version compatibility
- Verify all dependencies are installed
- Review error logs
- Test on different devices

### Debug Mode
```bash
flutter run --debug
```

### Performance Profiling
```bash
flutter run --profile
```

---

## Future Enhancements

### Planned Features
1. **Offline Mode**: Cache content for offline use
2. **Social Features**: Share tour progress
3. **Accessibility**: Screen reader support
4. **Analytics**: User engagement tracking
5. **Push Notifications**: Tour reminders

### Technical Improvements
1. **State Management**: Implement Provider or Riverpod
2. **Database**: Add local SQLite database
3. **Caching**: Implement content caching system
4. **Performance**: Optimize asset loading
5. **Testing**: Increase test coverage

### Content Management
1. **Web Interface**: Curator web dashboard
2. **Content Editor**: Visual content management
3. **Version Control**: Content versioning system
4. **Backup System**: Automated content backups

---

## Team Information

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
- **Mid-Project Meeting**: July 8, 2025
- **Final Delivery**: August 29, 2025

### Repository Information
- **GitHub**: https://github.com/JPatts/Campus-Tour-App-2025
- **Status**: Public (will be made private upon request)
- **License**: Open source

---

## Contact Information

For questions about this project or technical support:
- **Repository Issues**: Use GitHub Issues
- **Team Lead**: Jonah Pattison
- **Sponsor**: Bruce Irvin

---

## Appendix

### Glossary
- **AR**: Augmented Reality - Computer-generated content overlaid on real-world view
- **Hotspot**: Physical location with associated digital content
- **GPS**: Global Positioning System - Satellite-based location tracking
- **Flutter**: Google's cross-platform mobile development framework
- **Dart**: Programming language used by Flutter

### Useful Resources
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [Geolocator Package](https://pub.dev/packages/geolocator)

---

*This documentation was created for the Campus Tour App capstone project at Portland State University, Summer 2025.*
