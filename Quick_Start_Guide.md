# Campus Tour App - Quick Start Guide
## For the Next Capstone Team

### Prerequisites Checklist
- [ ] Flutter SDK installed (version 3.8.1+)
- [ ] Android Studio or VS Code
- [ ] Git installed
- [ ] Google Maps API key (optional for initial setup)

---

## Step 1: Clone and Setup (5 minutes)

```bash
# Clone the repository
git clone https://github.com/JPatts/Campus-Tour-App-2025
cd Campus-Tour-App-2025/campus_tour

# Install dependencies
flutter pub get
```

---

## Step 2: Run the App (5 minutes)

```bash
# Check if everything is set up correctly
flutter doctor

# Run the app (choose your platform)
flutter run -d android    # For Android
flutter run -d ios        # For iOS (macOS only)
flutter run -d chrome     # For web testing
```

**Expected Result**: The app should launch with three tabs:
- **Map Tab** (left): Google Maps view
- **Home Tab** (center): List of locations
- **AR Tab** (right): Camera view

---

## Step 3: Test Basic Functionality (10 minutes)

### Test Navigation
1. **Swipe between tabs** using the bottom navigation
2. **Verify each screen loads** without errors
3. **Check the home screen** shows a list of locations

### Test Admin Mode (Hidden Feature)
1. **Triple-tap the Map tab** quickly
2. **Enter code**: `4231`
3. **Verify admin mode activates** (you'll see a snackbar message)

### Test Hotspot Loading
1. **Check the home screen** shows hotspots
2. **Expand hotspot items** to see details
3. **Verify content displays** properly

---

## Step 4: Understand the Codebase (10 minutes)

### Key Files to Review
```
lib/
├── main.dart              # App entry point & navigation
├── map.dart               # Map screen (largest file)
├── camera.dart            # AR camera functionality
├── listview.dart          # Location list
├── models/hotspot.dart    # Data models
└── services/hotspot_service.dart  # Business logic
```

### Quick Code Tour
1. **Open `main.dart`** - See how the app is structured
2. **Check `hotspot_service.dart`** - Understand how hotspots are loaded
3. **Look at `models/hotspot.dart`** - See the data structure
4. **Review `assets/hotspots/`** - See example hotspot content

---

## What You Should See

### Working Features
- App launches without errors
- Three-tab navigation works
- Hotspots load and display
- Admin mode activation works
- Basic UI is functional

### Known Limitations (Don't Panic!)
- GPS won't work in simulator
- Camera won't work in simulator
- Google Maps may show errors without API key
- AR features need physical device

---

## Common Issues & Solutions

### "Flutter not found"
```bash
# Add Flutter to your PATH
export PATH="$PATH:/path/to/flutter/bin"
```

### "Dependencies not found"
```bash
flutter clean
flutter pub get
```

### "Google Maps not loading"
- This is expected without an API key
- Maps will still work for basic functionality
- Add API key later for full features

### "Camera permission denied"
- This is normal in simulator
- Test on physical device for camera features

---

## Testing on Physical Device

### Android
1. **Enable Developer Options** on your phone
2. **Enable USB Debugging**
3. **Connect via USB**
4. **Run**: `flutter run -d android`

### iOS (macOS only)
1. **Open Xcode**
2. **Sign in with Apple ID**
3. **Trust your developer certificate**
4. **Run**: `flutter run -d ios`

---

## Next Steps

### Immediate Actions
1. **Read the full documentation** in `Campus_Tour_App_Documentation.md`
2. **Review the curator guide** in `Curator_Guide.md`
3. **Set up your development environment** properly
4. **Get familiar with the codebase**

### Development Priorities
1. **Fix any issues** you encounter
2. **Add Google Maps API key** for full functionality
3. **Test on physical devices** for GPS and camera
4. **Understand the hotspot system** for content management

### Team Setup
1. **Assign roles** (frontend, backend, testing, etc.)
2. **Set up communication** (Slack, Discord, etc.)
3. **Create development workflow** (Git branches, code review, etc.)
4. **Plan your sprint** based on project requirements

---

## Essential Resources

### Documentation
- **Full Documentation**: `Campus_Tour_App_Documentation.md`
- **Curator Guide**: `Curator_Guide.md`
- **Project Spec**: `project_specification.txt`

### External Resources
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)

### Team Resources
- **Repository**: https://github.com/JPatts/Campus-Tour-App-2025
- **Google Drive**: https://drive.google.com/drive/folders/1Wi-DBqIKGkhZO8AZ6vFMYC2CQDhTulc7

---

## Getting Help

### When You're Stuck
1. **Check the documentation** first
2. **Search existing issues** on GitHub
3. **Ask your team members**
4. **Contact the previous team** if needed

### Emergency Contacts
- **Previous Team Lead**: Jonah Pattison
- **Sponsor**: Bruce Irvin
- **Repository Issues**: Create GitHub issue

---

## Success Checklist

After completing this guide, you should have:
- [ ] App running on your machine
- [ ] Basic understanding of the codebase
- [ ] Ability to navigate between screens
- [ ] Knowledge of where to find documentation
- [ ] Understanding of next steps

---

## Congratulations!

You've successfully set up the Campus Tour App! You're now ready to:
- **Develop new features**
- **Fix bugs and issues**
- **Add new hotspots**
- **Improve the user experience**

**Good luck with your capstone project!**

---

*This quick start guide was created for the Campus Tour App capstone project at Portland State University, Summer 2025.*
