// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map.dart'; // left-hand page
import 'camera.dart'; // right-hand page

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('App starting...');
    runApp(const MyApp());
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
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

  // All three pages.  No extra file for the Home page—it’s defined inline.
  late final List<Widget> _pages = [
    const MapScreen(), // ← left
    const _InlineHomePage(), //   center (banner shows here)
    const CameraScreen(), // → right
  ];

  /// Animate safely to a new page & update state
  void _goToPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = index);
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
              title: const Text('Campus Tour App'),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            )
          : null,

      // PageView holds Map ← Home → Camera
      body: PageView(
        controller: _pageCtrl,
        physics:
            const NeverScrollableScrollPhysics(), // disable swipe; arrows only
        onPageChanged: (idx) => setState(() => _currentPage = idx),
        children: _pages,
      ),

      // Bottom navigation bar with 3 icons
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (index) => _goToPage(index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
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
    );
  }
}

/// Home page widget
class _InlineHomePage extends StatelessWidget {
  const _InlineHomePage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '🏠 Home Screen',
        style: TextStyle(fontSize: 24),
        textAlign: TextAlign.center,
      ),
    );
  }
}
