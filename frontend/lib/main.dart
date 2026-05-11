import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/theme.dart';

final _desktopWindowController = _DesktopWindowController();
final GlobalKey<NavigatorState> musicFlowNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();
  runApp(MusicFlowApp(navigatorKey: musicFlowNavigatorKey));
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
  var _closeDialogShowing = false;

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
          MenuItem(key: 'hide', label: '隐藏到托盘'),
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
    if (_isQuitting) {
      await windowManager.destroy();
      return;
    }
    if (_closeDialogShowing) {
      return;
    }
    final action = await _showCloseDialog();
    switch (action) {
      case _WindowCloseAction.hide:
        await windowManager.hide();
      case _WindowCloseAction.quit:
        await _quitApp();
      case _WindowCloseAction.cancel:
      case null:
        return;
    }
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
      case 'hide':
        await windowManager.hide();
      case 'exit':
        await _quitApp();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quitApp() async {
    if (_isQuitting) {
      return;
    }
    _isQuitting = true;
    try {
      await windowManager.setPreventClose(false);
    } catch (_) {}
    exit(0);
  }

  Future<_WindowCloseAction?> _showCloseDialog() async {
    final context = musicFlowNavigatorKey.currentContext;
    if (context == null) {
      return _WindowCloseAction.hide;
    }
    _closeDialogShowing = true;
    try {
      final action = await showDialog<_WindowCloseAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            icon: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: kAccentDark,
                size: 28,
              ),
            ),
            title: Text(
              '关闭 MusicFlow？',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: kInk,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              '你可以最小化到系统托盘继续播放，也可以完全退出应用。',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: kMuted,
                height: 1.55,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_WindowCloseAction.cancel),
                style: TextButton.styleFrom(
                  foregroundColor: kMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Text('取消'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_WindowCloseAction.hide),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccentDark,
                  side: BorderSide(color: kAccent.withValues(alpha: .26)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                label: const Text('最小化到托盘'),
              ),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_WindowCloseAction.quit),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE15B5B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                label: const Text('退出应用'),
              ),
            ],
          );
        },
      );
      return action;
    } finally {
      _closeDialogShowing = false;
    }
  }
}

enum _WindowCloseAction { cancel, hide, quit }
