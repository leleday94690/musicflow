import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';

final _desktopWindowController = _DesktopWindowController();

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
  await _desktopWindowController.initialize();
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
    await windowManager.setPreventClose(true);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  });
}

class _DesktopWindowController with WindowListener, TrayListener {
  var _isQuitting = false;

  Future<void> initialize() async {
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
    await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    await trayManager.setToolTip('MusicFlow');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示 MusicFlow'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: '退出 MusicFlow'),
        ],
      ),
    );
  }

  @override
  void onWindowClose() async {
    final preventClose = await windowManager.isPreventClose();
    if (!preventClose) {
      return;
    }
    if (Platform.isWindows) {
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        return;
      }
    }
    if (_isQuitting) {
      await windowManager.destroy();
      return;
    }
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await _showWindow();
      case 'exit':
        _isQuitting = true;
        await trayManager.destroy();
        await windowManager.destroy();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
