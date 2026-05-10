import 'package:flutter/material.dart';

const kAccent = Color(0xFF18B9E6);
const kAccentDark = Color(0xFF0399D0);
const kInk = Color(0xFF17222E);
const kMuted = Color(0xFF7B8794);
const kLine = Color(0xFFE8EDF2);
const kSurface = Color(0xFFFFFFFF);
const kScaffold = Color(0xFFF6F7F8);

ThemeData buildMusicTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kScaffold,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.light,
      surface: kSurface,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.12,
        fontWeight: FontWeight.w800,
        color: kInk,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.18,
        fontWeight: FontWeight.w800,
        color: kInk,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: kInk,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: kInk,
      ),
      bodyLarge: TextStyle(fontSize: 14, height: 1.45, color: kInk),
      bodyMedium: TextStyle(fontSize: 12, height: 1.45, color: kMuted),
      labelLarge: TextStyle(
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: kInk,
      ),
      labelMedium: TextStyle(fontSize: 11, height: 1.25, color: kMuted),
    ),
    dividerColor: kLine,
  );
}

BoxDecoration cardDecoration({double radius = 18, Color color = kSurface}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kLine),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 28,
        offset: const Offset(0, 14),
      ),
    ],
  );
}
