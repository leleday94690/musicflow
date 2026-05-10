import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();
  runApp(const MusicFlowApp());
}

Future<void> _configureDesktopWindow() async {
  if (!Platform.isWindows) {
    return;
  }
  await windowManager.ensureInitialized();
  const minWidth = 1000.0;
  const minHeight = 680.0;
  var screenWidth = 1440.0;
  var screenHeight = 900.0;
  try {
    final display = await screenRetriever.getPrimaryDisplay();
    screenWidth = display.size.width;
    screenHeight = display.size.height;
  } catch (_) {}
  final options = WindowOptions(
    size: Size(
      (screenWidth * 0.76).clamp(minWidth, 1440.0),
      (screenHeight * 0.78).clamp(minHeight, 980.0),
    ),
    minimumSize: const Size(minWidth, minHeight),
    center: true,
    title: 'MusicFlow',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  });
}
