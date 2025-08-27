// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map.dart'; // left-hand page
import 'camera.dart'; // right-hand page
import 'listview.dart'; // list of discovered locations
import 'services/hotspot_service.dart';
import 'services/visited_service.dart';

// PSU Color Pallet
const psuGreen = 0xFF6d8d24;
const electricGreen = 0xFFCFD82D;
const forestGreen = 0xFF213921;

final myService = HotspotService();

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    // Lock the app to portrait orientation only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
      title: 'PSU Campus Tour',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(psuGreen)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(psuGreen),
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
      home: HomeWithNav(key: HomeWithNav.navKey),
    );
  }
}

/// Stateful wrapper that handles
///  • the PageView (Map ← Home → Camera)
///  • the “← / →” arrow bar
///  • showing the AppBar **only** on the center page
class HomeWithNav extends StatefulWidget {
  static final GlobalKey<_HomeWithNavState> navKey = GlobalKey<_HomeWithNavState>();
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
  final VisitedService _visitedService = VisitedService();

  List<Widget> _buildPages() => [
        MapScreen(key: ValueKey('map-$_adminMode'), adminModeEnabled: _adminMode), // ← left
        LocationList(key: ValueKey('list-$_adminMode'), adminModeEnabled: _adminMode), //   center (banner shows here)
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

  void goToMap() => _goToPage(0);

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
                    _markAllHotspotsVisited();
                    _showAdminSnack('Admin mode enabled', enabled: true);
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

  Future<void> _markAllHotspotsVisited() async {
    try {
      // Ensure hotspots are loaded
      if (!myService.isLoaded) {
        await myService.loadHotspots();
      }
      final hotspots = myService.getHostpots();
      final now = DateTime.now();
      for (final hs in hotspots) {
        await _visitedService.markVisitedFake(hs.hotspotId, now);
      }
      // Suppressed snackbar per requirements
    } catch (_) {
      // No-op on errors; testing helper
    }
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
              title: Transform.translate(
                offset: const Offset(0, -12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PSU Campus Tour',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
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
        color: const Color(psuGreen),
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
                  _showAdminSnack('Admin mode disabled', enabled: false);
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
            icon: Icon(Icons.view_in_ar),
            label: 'AR',
          ),
        ],
          ),
        ),
      ),
    );
  }

  void _showAdminSnack(String message, {required bool enabled}) {
    if (!mounted) return;
    final Color base = enabled ? const Color(0xFF2E7D32) : const Color(0xFFB23B3B);
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
              Icon(enabled ? Icons.verified_user : Icons.shield_moon_outlined, color: Colors.white),
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
}
