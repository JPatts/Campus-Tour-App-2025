// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map.dart'; // left-hand page
import 'camera.dart'; // right-hand page
import 'listview.dart'; // list of discovered locations
import 'services/hotspot_service.dart';


final myService = HotspotService();

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('App starting...');
    runApp(const MyApp());
    myService.loadHotspots();
    debugPrint("Hotspots loaded");
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

/// Top-level app wrapper
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MyApp...');
    return MaterialApp(
      title: 'Campus Tour App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF213921)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF213921),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      // The widget below owns the PageView + bottom arrows
      home: const HomeWithNav(),
    );
  }
}

/// Stateful wrapper that handles
///  • the PageView (Map ← Home → Camera)
///  • the “← / →” arrow bar
///  • showing the AppBar **only** on the center page
class HomeWithNav extends StatefulWidget {
  const HomeWithNav({Key? key}) : super(key: key);

  @override
  State<HomeWithNav> createState() => _HomeWithNavState();
}

class _HomeWithNavState extends State<HomeWithNav> {
  // Page index: 0 = Map, 1 = Home, 2 = Camera
  final PageController _pageCtrl = PageController(initialPage: 1);
  int _currentPage = 1; // start on Home (center)
  bool _adminMode = false; // Hidden admin mode state
  int _mapIconTapCount = 0; // triple-tap detection
  DateTime? _lastMapIconTap;

  List<Widget> _buildPages() => [
        MapScreen(adminModeEnabled: _adminMode), // ← left
        LocationList(), //   center (banner shows here)
        const CameraScreen(), // → right
      ];

  /// Animate safely to a new page & update state
  void _goToPage(int index) {
    if (index < 0 || index >= 3) return;
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = index);
  }

  Future<void> _promptForAdminCode() async {
    final TextEditingController controller = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('Enter Admin Code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '4-digit code',
                    errorText: errorText,
                  ),
                  maxLength: 4,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim() == '4231') {
                    Navigator.of(ctx).pop();
                    setState(() => _adminMode = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Admin mode enabled')),
                    );
                  } else {
                    setStateDialog(() {
                      errorText = 'Incorrect code';
                    });
                  }
                },
                child: const Text('Activate'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building HomeWithNav, current page: $_currentPage');
    return Scaffold(
      // Banner appears ONLY on the center page (index 1)
      appBar: _currentPage == 1
          ? AppBar(
              centerTitle: true,
              toolbarHeight: 70,
              title: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Campus Tour App',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Locations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            )
          : null,

      // PageView holds Map ← Home → Camera
      body: PageView(
        controller: _pageCtrl,
        physics:
            const NeverScrollableScrollPhysics(), // disable swipe; arrows only
        onPageChanged: (idx) => setState(() => _currentPage = idx),
        children: _buildPages(),
      ),

      // Bottom navigation bar with 3 icons
      bottomNavigationBar: ColoredBox(
        color: const Color(0xFF213921),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
        currentIndex: _currentPage,
        onTap: (index) {
          final DateTime now = DateTime.now();
          if (index == 0) {
            // Taps on Map tab
            if (_currentPage != 0) {
              // First tap switches to Map, start counting
              _mapIconTapCount = 1;
              _lastMapIconTap = now;
              _goToPage(0);
            } else {
              // Already on Map: count rapid taps
              if (_lastMapIconTap != null &&
                  now.difference(_lastMapIconTap!).inMilliseconds <= 900) {
                _mapIconTapCount += 1;
              } else {
                _mapIconTapCount = 1;
              }
              _lastMapIconTap = now;

              if (_mapIconTapCount >= 3) {
                // Triple tap detected
                _mapIconTapCount = 0;
                _lastMapIconTap = null;
                if (_adminMode) {
                  setState(() => _adminMode = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Admin mode disabled')),
                  );
                } else {
                  _promptForAdminCode();
                }
              }
            }
          } else {
            // Any other tab tap resets the counter and navigates
            _mapIconTapCount = 0;
            _lastMapIconTap = null;
            _goToPage(index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
        ],
          ),
        ),
      ),
    );
  }
}
