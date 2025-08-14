// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:campus_tour/main.dart';

void main() {
  testWidgets('App loads with Home page and bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Home (center) page should show the AppBar title
    expect(find.text('Campus Tour App'), findsOneWidget);

    // BottomNavigationBar labels
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);

    // Tapping Map should navigate to map page (no AppBar on non-center pages)
    await tester.tap(find.text('Map'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Campus Tour App'), findsNothing);

    // Return to Home
    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Campus Tour App'), findsOneWidget);
  });
}
