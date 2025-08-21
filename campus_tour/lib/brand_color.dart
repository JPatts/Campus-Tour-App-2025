import 'package:flutter/material.dart';

/// Global brand color controller.
///
/// Wraps a ValueNotifier so the app theme and widgets can react to changes.
class BrandColor {
  static final ValueNotifier<Color> notifier =
      ValueNotifier<Color>(const Color(0xFF8a8a67));

  static Color get current => notifier.value;

  static void set(Color color) {
    notifier.value = color;
  }

  /// Parses a hex string like "#RRGGBB", "RRGGBB", or "#AARRGGBB".
  /// Returns null if invalid.
  static Color? parseHex(String input) {
    String hex = input.trim();
    if (hex.isEmpty) return null;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) {
      hex = 'FF$hex';
    } else if (hex.length != 8) {
      return null;
    }
    final int? value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }
}


