import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';

class UpdateService {
  const UpdateService({this.baseUrl = AppConfig.apiBaseUrl});

  final String baseUrl;

  bool get isSupportedPlatform => Platform.isMacOS || Platform.isWindows;

  String get platform {
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    return Platform.operatingSystem;
  }

  Future<AppUpdateInfo?> checkForUpdate({String channel = 'stable'}) async {
    if (!isSupportedPlatform) {
      return null;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    final buildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    final query = Uri(
      path: '/api/app-update/latest',
      queryParameters: {
        'platform': platform,
        'channel': channel,
        'version': packageInfo.version,
        'buildNumber': '$buildNumber',
      },
    ).toString();
    final uri = Uri.parse('$baseUrl$query');
    final data = await _getJson(uri);
    final info = AppUpdateInfo.fromJson(
      data,
      currentVersion: packageInfo.version,
      currentBuild: buildNumber,
    );
    return info.available ? info : null;
  }

  Future<String> downloadUpdate(
    AppUpdateInfo info, {
    required void Function(double progress) onProgress,
  }) async {
    final downloadUrl = info.downloadUrl.trim();
    if (downloadUrl.isEmpty) {
      throw const UpdateException('更新包暂未准备好');
    }

    final uri = Uri.parse(downloadUrl);
    try {
      final directory = await getTemporaryDirectory();
      final fileName = _safeFileName(
        info.fileName.isEmpty
            ? (Platform.isMacOS ? 'MusicFlow.dmg' : 'MusicFlow-Setup.exe')
            : info.fileName,
      );
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      final partialFile = File('${file.path}.part');
      if (await partialFile.exists()) {
        await partialFile.delete();
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(minutes: 8),
          sendTimeout: const Duration(seconds: 12),
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.bytes,
        ),
      );
      await dio.download(
        uri.toString(),
        partialFile.path,
        options: Options(headers: {'Accept': 'application/octet-stream'}),
        onReceiveProgress: (received, total) {
          final denominator = total > 0 ? total : info.fileSize;
          if (denominator > 0) {
            onProgress((received / denominator).clamp(0, .98).toDouble());
          }
        },
      );

      if (await file.exists()) {
        await file.delete();
      }
      await partialFile.rename(file.path);

      if (info.sha256.isNotEmpty) {
        final digest = await sha256
            .bind(file.openRead())
            .first
            .timeout(const Duration(seconds: 20));
        if (digest.toString().toLowerCase() != info.sha256.toLowerCase()) {
          await file.delete().catchError((_) => file);
          throw const UpdateException('更新包校验失败，请重新下载');
        }
      }
      onProgress(1);
      return file.path;
    } on TimeoutException {
      throw const UpdateException('下载超时，请稍后重试');
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const UpdateException('下载超时，请稍后重试');
      }
      throw UpdateException('更新包下载失败：${error.message ?? '网络异常'}');
    } on SocketException {
      throw const UpdateException('无法连接到更新服务器');
    }
  }

  Future<bool> installAndRestart(String filePath) async {
    if (Platform.isMacOS) {
      return _installMacOS(filePath);
    }
    if (Platform.isWindows) {
      return _installWindows(filePath);
    }
    return false;
  }

  Future<void> openInstaller(String filePath) async {
    if (Platform.isMacOS) {
      await Process.run('open', [filePath]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', filePath]);
    }
  }

  Future<void> openDownloadPage(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 18),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 18));
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('更新检查失败：${response.statusCode}');
      }
      final data = jsonDecode(body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on TimeoutException {
      throw const UpdateException('更新检查超时');
    } on SocketException {
      throw const UpdateException('无法连接到更新服务器');
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _installMacOS(String dmgPath) async {
    try {
      final dmgFile = File(dmgPath);
      if (!await dmgFile.exists()) {
        debugPrint('[Update] macOS installer not found: $dmgPath');
        return false;
      }

      final directory = await getTemporaryDirectory();
      final script = File(
        '${directory.path}${Platform.pathSeparator}musicflow_update_${DateTime.now().millisecondsSinceEpoch}.sh',
      );
      await script.writeAsString(_macOSInstallScript);
      final chmodResult = await Process.run('chmod', ['700', script.path]);
      if (chmodResult.exitCode != 0) {
        debugPrint(
          '[Update] macOS installer chmod failed: ${chmodResult.stderr}',
        );
        return false;
      }

      await Process.start('/bin/bash', [
        script.path,
        dmgPath,
        '$pid',
      ], mode: ProcessStartMode.detached);
      exit(0);
    } catch (error) {
      debugPrint('[Update] macOS install failed: $error');
      return false;
    }
  }

  Future<bool> _installWindows(String installerPath) async {
    try {
      final installerFile = File(installerPath);
      if (!await installerFile.exists()) {
        debugPrint('[Update] Windows installer not found: $installerPath');
        return false;
      }
      final directory = await getTemporaryDirectory();
      final script = File(
        '${directory.path}${Platform.pathSeparator}musicflow_update_${DateTime.now().millisecondsSinceEpoch}.cmd',
      );
      final installDir = File(Platform.resolvedExecutable).parent.path;
      await script.writeAsString(
        _windowsInstallScript(
          installerPath: installerPath,
          installDir: installDir,
          appPid: pid,
        ),
      );
      await Process.start('cmd.exe', [
        '/c',
        script.path,
      ], mode: ProcessStartMode.detached);
      exit(0);
    } catch (error) {
      debugPrint('[Update] Windows install failed: $error');
      return false;
    }
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'MusicFlow-Update' : sanitized;
  }
}

const String _macOSInstallScript = r'''#!/bin/bash
set -u

SOURCE_PATH="$1"
APP_PID="$2"
LOG_PATH="$HOME/Library/Logs/MusicFlow-updater.log"
MOUNT_POINT=""
VOLUME_NAME="MusicFlow"
WORK_DIR=""

/bin/mkdir -p "$(/usr/bin/dirname "$LOG_PATH")" >/dev/null 2>&1 || true

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_PATH"
}

open_manual_installer() {
  if [ -f "$SOURCE_PATH" ]; then
    /usr/bin/open "$SOURCE_PATH" >/dev/null 2>&1 || true
  fi
}

cleanup() {
  if [ -n "$MOUNT_POINT" ]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true
  fi
  if [ -n "$WORK_DIR" ]; then
    /bin/rm -rf "$WORK_DIR" >/dev/null 2>&1 || true
  fi
}

fail() {
  log "failed: $*"
  cleanup
  open_manual_installer
  exit 1
}

trap cleanup EXIT

log "installer started, source=$SOURCE_PATH, appPid=$APP_PID"

for _ in $(seq 1 120); do
  if ! /bin/kill -0 "$APP_PID" >/dev/null 2>&1; then
    break
  fi
  /bin/sleep 0.25
done

[ -f "$SOURCE_PATH" ] || fail "update file not found"

case "$SOURCE_PATH" in
  *.zip)
    WORK_DIR=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/musicflow-update.XXXXXX") || fail "create work dir failed"
    log "extracting zip to $WORK_DIR"
    /usr/bin/ditto -x -k "$SOURCE_PATH" "$WORK_DIR" >> "$LOG_PATH" 2>&1 || fail "extract zip failed"
    APP_PATH=$(/usr/bin/find "$WORK_DIR" -maxdepth 3 -name '*.app' -type d | /usr/bin/head -n 1)
    ;;
  *)
    for volume in "/Volumes/$VOLUME_NAME" "/Volumes/$VOLUME_NAME "*; do
      if [ -e "$volume" ]; then
        log "detaching stale volume: $volume"
        /usr/bin/hdiutil detach "$volume" -force >> "$LOG_PATH" 2>&1 || true
      fi
    done

    MOUNT_OUTPUT=""
    for attempt in $(seq 1 6); do
      MOUNT_OUTPUT=$(/usr/bin/hdiutil attach "$SOURCE_PATH" -nobrowse -noverify -noautoopen 2>&1)
      ATTACH_CODE=$?
      if [ "$ATTACH_CODE" -eq 0 ]; then
        MOUNT_POINT=$(printf '%s\n' "$MOUNT_OUTPUT" | /usr/bin/awk -F '\t' '/\/Volumes\// {print $NF}' | /usr/bin/tail -n 1)
        if [ -n "$MOUNT_POINT" ]; then
          log "mounted at $MOUNT_POINT on attempt $attempt"
          break
        fi
      fi
      log "mount attempt $attempt failed: $MOUNT_OUTPUT"
      /bin/sleep "$attempt"
    done

    [ -n "$MOUNT_POINT" ] || fail "mount failed after retries: $MOUNT_OUTPUT"
    APP_PATH=$(/usr/bin/find "$MOUNT_POINT" -maxdepth 1 -name '*.app' -type d | /usr/bin/head -n 1)
    ;;
esac

[ -n "$APP_PATH" ] || fail "app not found in update file"

APP_NAME=$(/usr/bin/basename "$APP_PATH")
TARGET_PATH="/Applications/$APP_NAME"

log "copying $APP_PATH to $TARGET_PATH"
/bin/rm -rf "$TARGET_PATH" 2>> "$LOG_PATH" || fail "remove old app failed"
/usr/bin/ditto "$APP_PATH" "$TARGET_PATH" 2>> "$LOG_PATH" || fail "copy app failed"
/usr/bin/xattr -dr com.apple.quarantine "$TARGET_PATH" >/dev/null 2>&1 || true

cleanup
MOUNT_POINT=""

log "opening $TARGET_PATH"
/usr/bin/open -n "$TARGET_PATH" >/dev/null 2>&1 || fail "open app failed"
log "installer finished"
exit 0
''';

String _windowsInstallScript({
  required String installerPath,
  required String installDir,
  required int appPid,
}) {
  final installer = _escapeWindowsBatchValue(installerPath);
  final directory = _escapeWindowsBatchValue(installDir);
  return '''
@echo off
setlocal
set "INSTALLER=$installer"
set "INSTALL_DIR=$directory"
set "APP_PID=$appPid"
set "LOG=%TEMP%\\MusicFlow-updater.log"
echo [%date% %time%] installer started, pid=%APP_PID%, installer=%INSTALLER%, dir=%INSTALL_DIR%>>"%LOG%"
for /l %%i in (1,1,120) do (
  tasklist /FI "PID eq %APP_PID%" 2>nul | findstr /R /C:"[ ]%APP_PID%[ ]" >nul
  if errorlevel 1 goto install
  timeout /t 1 /nobreak >nul
)
echo [%date% %time%] app process still running, forcing taskkill>>"%LOG%"
taskkill /PID %APP_PID% /T /F >>"%LOG%" 2>&1
timeout /t 1 /nobreak >nul
:install
if not exist "%INSTALLER%" (
  echo [%date% %time%] installer not found>>"%LOG%"
  exit /b 1
)
echo [%date% %time%] running installer>>"%LOG%"
"%INSTALLER%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /DIR="%INSTALL_DIR%" >>"%LOG%" 2>&1
echo [%date% %time%] installer exit code=%ERRORLEVEL%>>"%LOG%"
exit /b %ERRORLEVEL%
''';
}

String _escapeWindowsBatchValue(String value) {
  return value
      .replaceAll('^', '^^')
      .replaceAll('&', '^&')
      .replaceAll('|', '^|')
      .replaceAll('<', '^<')
      .replaceAll('>', '^>')
      .replaceAll('%', '%%');
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.available,
    required this.currentVersion,
    required this.currentBuild,
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.channel,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.sha256,
    required this.mandatory,
  });

  final bool available;
  final String currentVersion;
  final int currentBuild;
  final String version;
  final int buildNumber;
  final String platform;
  final String channel;
  final String releaseNotes;
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final String sha256;
  final bool mandatory;

  factory AppUpdateInfo.fromJson(
    Map<String, dynamic> json, {
    required String currentVersion,
    required int currentBuild,
  }) {
    return AppUpdateInfo(
      available: json['available'] == true,
      currentVersion: json['currentVersion']?.toString() ?? currentVersion,
      currentBuild: (json['currentBuild'] as num?)?.toInt() ?? currentBuild,
      version: json['version']?.toString() ?? '',
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 0,
      platform: json['platform']?.toString() ?? '',
      channel: json['channel']?.toString() ?? 'stable',
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      sha256: json['sha256']?.toString() ?? '',
      mandatory: json['mandatory'] == true,
    );
  }
}

class UpdateDownloadState {
  const UpdateDownloadState({
    this.isDownloading = false,
    this.progress = 0,
    this.downloadedPath,
    this.errorMessage,
  });

  final bool isDownloading;
  final double progress;
  final String? downloadedPath;
  final String? errorMessage;

  bool get hasDownloaded =>
      downloadedPath != null && downloadedPath!.isNotEmpty;
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
