import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'auth_storage.dart';
import 'audio_controller.dart';
import 'delayed_loading.dart';
import 'library_state.dart';
import 'models.dart';
import 'pages/download_management_page.dart';
import 'pages/downloads_page.dart';
import 'pages/home_page.dart';
import 'pages/player_page.dart';
import 'pages/playlists_page.dart';
import 'pages/profile_page.dart';
import 'pages/recent_plays_page.dart';
import 'pages/search_page.dart';
import 'playback_controller.dart';
import 'playback_state_storage.dart';
import 'theme.dart';
import 'update_service.dart';
import 'widgets/empty_state.dart';
import 'widgets/edit_song_dialog.dart';
import 'widgets/navigation.dart';
import 'widgets/player_bar.dart';
import 'widgets/request_loading.dart';

final RouteObserver<PageRoute<dynamic>> musicFlowRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class MusicFlowApp extends StatelessWidget {
  const MusicFlowApp({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [musicFlowRouteObserver],
      title: 'MusicFlow',
      debugShowCheckedModeBanner: false,
      theme: buildMusicTheme(),
      home: const MusicShell(),
    );
  }
}

class MusicShell extends StatefulWidget {
  const MusicShell({super.key});

  @override
  State<MusicShell> createState() => _MusicShellState();
}

class _MusicShellState extends State<MusicShell> with RouteAware {
  static const int _songPageSize = 80;

  MusicSection section = MusicSection.music;
  int musicInitialSegment = 0;
  final MusicAudioController audioController = MusicAudioController();
  final PlaybackController playbackController = PlaybackController();
  final DelayedLoadingController appLoading = DelayedLoadingController();
  final DelayedLoadingController requestLoading = DelayedLoadingController();
  final UpdateService updateService = const UpdateService();
  late final StreamSubscription<void> _completionSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  Timer? _playbackSaveTimer;
  Timer? _updateTimer;
  PageRoute<dynamic>? _currentRoute;
  bool _restoringPlaybackState = false;
  bool _updateChecking = false;
  bool _updateDialogShown = false;
  bool _updateBannerDismissed = false;
  bool _installPromptShowing = false;
  bool _isRouteVisible = true;
  ProfileOverview? profileOverview;
  AppUpdateInfo? availableUpdate;
  UpdateDownloadState updateDownload = const UpdateDownloadState();
  String? authToken;
  bool hasLoadedData = false;
  bool hasMoreSongs = false;
  bool isLoadingMoreSongs = false;
  int songNextCursor = 0;
  int songTotalCount = 0;
  String onlineDownloadKeyword = '';
  List<Map<String, dynamic>> onlineDownloadResults = const [];
  Set<String> onlineDownloadedIds = {};
  String? onlineDownloadingId;
  String? onlineDownloadError;
  bool onlineSearchActive = false;
  bool onlineBatchActive = false;
  bool onlineBatchPauseRequested = false;
  int onlineBatchCompleted = 0;
  int onlineBatchTotal = 0;
  int onlineBatchSuccess = 0;
  List<Map<String, dynamic>> onlineBatchQueue = const [];
  String? loadError;

  Song? get currentSong => playbackController.currentSong;
  set currentSong(Song? song) => playbackController.setCurrentSong(song);

  PlaybackMode get playbackMode => playbackController.playbackMode;

  bool get canManageLibrary => profileOverview?.user.isAdmin ?? false;

  bool get isAudioLoading => playbackController.isAudioLoading;
  set isAudioLoading(bool value) => playbackController.setAudioLoading(value);

  bool get isPlaying => playbackController.isPlaying;
  set isPlaying(bool value) => playbackController.setPlaying(value);

  @override
  void initState() {
    super.initState();
    libraryController.addListener(_handleLibraryChanged);
    playbackController.addListener(_handlePlaybackChanged);
    appLoading.addListener(_handleLoadingChanged);
    requestLoading.addListener(_handleLoadingChanged);
    _completionSubscription = audioController.completionStream.listen((_) {
      _handlePlaybackComplete();
    });
    _positionSubscription = audioController.positionStream.listen((_) {
      _schedulePlaybackStateSave();
    });
    _restoreSessionAndLoadData();
    _scheduleUpdateChecks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _currentRoute) {
      if (_currentRoute != null) {
        musicFlowRouteObserver.unsubscribe(this);
      }
      _currentRoute = route;
      musicFlowRouteObserver.subscribe(this, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 760;

    final content = switch (section) {
      MusicSection.music => HomePage(
        isMobile: isMobile,
        canManageLibrary: canManageLibrary,
        isRouteVisible: _isRouteVisible,
        currentPosition: audioController.currentPosition,
        initialSegment: musicInitialSegment,
        currentSong: currentSong,
        isAudioLoading: isAudioLoading,
        onSongTap: _selectSong,
        onQueuePlayAll: _playQueue,
        onSongPlayNext: _queueSongNext,
        onSongAddToPlaylist: _addSongToPlaylistFromList,
        onSongEdit: _editSong,
        onFavoriteToggle: _toggleFavorite,
        onSongDownload: _downloadSongFromList,
        onSongsAddToPlaylist: _addSongsToPlaylistFromList,
        onSongsDownload: _downloadSongsFromList,
        onLocalImport: _importLocalMusic,
        onSongDelete: _deleteSong,
        onSongsDelete: _deleteSongsFromList,
        onSectionChanged: _setSection,
        positionStream: audioController.positionStream,
        playingListenable: audioController.playingNotifier,
        onTogglePlay: _togglePlay,
        onNext: _playNext,
        onPrevious: _playPrevious,
        playbackMode: playbackMode,
        onPlaybackModeChanged: _cyclePlaybackMode,
        hasMoreSongs: hasMoreSongs,
        isLoadingMoreSongs: isLoadingMoreSongs,
        songTotalCount: songTotalCount,
        onLoadMoreSongs: _loadMoreSongs,
      ),
      MusicSection.playlists => PlaylistsPage(
        isMobile: isMobile,
        canManageLibrary: canManageLibrary,
        onSongTap: _selectSong,
        onSongPlayNext: _queueSongNext,
        onSongAddToPlaylist: _addSongToPlaylistFromList,
        onSongEdit: _editSong,
        onSectionChanged: _setSection,
        onCreatePlaylist: _createPlaylist,
        onUpdatePlaylist: _updatePlaylist,
        onDeletePlaylist: _deletePlaylist,
        onFetchPlaylist: _fetchPlaylist,
        onPlaylistFavoriteToggle: _togglePlaylistFavorite,
        onAddSongToPlaylist: _addSongToPlaylist,
        onRemoveSongFromPlaylist: _removeSongFromPlaylist,
        onReorderPlaylistSongs: _reorderPlaylistSongs,
        onSongDownload: _downloadSongFromList,
      ),
      MusicSection.search => SearchPage(
        isMobile: isMobile,
        canManageLibrary: canManageLibrary,
        authToken: authToken,
        onSongTap: _selectSearchSong,
        onQueuePlayAll: _playQueue,
        onSongPlayNext: _queueSongNext,
        onSongAddToPlaylist: _addSongToPlaylistFromList,
        onSongEdit: _editSong,
        onFavoriteToggle: _toggleFavorite,
        onSongDownload: _downloadSongFromList,
      ),
      MusicSection.downloads => DownloadsPage(
        isMobile: isMobile,
        canManageLibrary: canManageLibrary,
        authToken: authToken,
        searchKeyword: onlineDownloadKeyword,
        results: onlineDownloadResults,
        downloadedOnlineIds: onlineDownloadedIds,
        downloadingId: onlineDownloadingId,
        errorMessage: onlineDownloadError,
        searching: onlineSearchActive,
        batchActive: onlineBatchActive,
        batchPaused: onlineBatchPauseRequested,
        batchCompleted: onlineBatchCompleted,
        batchTotal: onlineBatchTotal,
        batchSuccess: onlineBatchSuccess,
        onSearchKeywordChanged: _setOnlineDownloadKeyword,
        onSearch: _searchOnlineDownloads,
        onDownload: _downloadOnlineSong,
        onBatchDownload: _downloadOnlineBatch,
        onBatchPause: _pauseOnlineBatch,
        onClearError: _clearOnlineDownloadError,
        onSongTap: _selectSong,
        onSongDownloaded: _addDownloadedSong,
        onAuthExpired: _logout,
      ),
      MusicSection.profile => ProfilePage(
        isMobile: isMobile,
        overview: profileOverview,
        onOpenFavoriteMusic: () => _openMusic(initialSegment: 1),
        onOpenRecentPlays: () => _setSection(MusicSection.recent),
        onOpenDownloadManagement: () =>
            _setSection(MusicSection.downloadManagement),
        onLogin: _login,
        onLogout: _logout,
      ),
      MusicSection.recent => RecentPlaysPage(
        isMobile: isMobile,
        token: authToken,
        fallbackItems: profileOverview?.recent ?? const [],
        onBack: () => _setSection(MusicSection.profile),
        onSongTap: _selectSong,
        onFavoriteToggle: _toggleFavorite,
      ),
      MusicSection.downloadManagement => DownloadManagementPage(
        isMobile: isMobile,
        canManageLibrary: canManageLibrary,
        authToken: authToken,
        fallbackTasks: profileOverview?.downloads ?? downloads,
        onBack: () => _setSection(MusicSection.profile),
        onSongTap: _selectSong,
        onSongDelete: _deleteSong,
        onDownloadsChanged: _handleDownloadsChanged,
      ),
      MusicSection.player =>
        currentSong == null
            ? const SizedBox.shrink()
            : PlayerPage(
                song: currentSong!,
                queue: playbackController.queueOr(songs),
                queueHasMore: hasMoreSongs,
                queueLoadingMore: isLoadingMoreSongs,
                queueTotalCount: songTotalCount,
                onQueueLoadMore: _loadMoreQueueSongs,
                onSongTap: _selectSong,
                onFavoriteToggle: _toggleFavorite,
                onSongEdit: canManageLibrary ? _editSong : null,
                audioController: audioController,
                isLoading: isAudioLoading,
                onTogglePlay: _togglePlay,
                onSeek: _seek,
                onNext: _playNext,
                onPrevious: _playPrevious,
                playbackMode: playbackMode,
                onPlaybackModeChanged: _cyclePlaybackMode,
                downloaded: _isSongDownloaded(currentSong!),
                onDownload: _downloadCurrentSong,
                onLyricsOffsetChanged: canManageLibrary
                    ? _updateSongLyricsOffset
                    : null,
                onLyricsFetch: canManageLibrary ? _fetchSongLyrics : null,
                onQueueRemove: _removeSongFromQueue,
                onQueuePlayNext: _moveSongNextInQueue,
                onQueueReorder: _reorderPlaybackQueue,
                onQueueClear: _clearPlaybackQueue,
              ),
    };
    final bodyContent = loadError != null
        ? _LoadErrorState(message: loadError!, onRetry: _loadData)
        : !hasLoadedData && appLoading.active
        ? appLoading.visible
              ? const _LoadingState()
              : const SizedBox.shrink()
        : content;

    if (isMobile) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: _withRequestOverlay(bodyContent, isMobile)),
              PlayerBar(
                song: currentSong,
                isMobile: true,
                onOpenPlayer: _openPlayer,
                onOpenQueue: _openQueue,
                onTogglePlay: _togglePlay,
                audioController: audioController,
                isLoading: isAudioLoading,
                onSeek: _seek,
                onNext: _playNext,
                onPrevious: _playPrevious,
                playbackMode: playbackMode,
                onPlaybackModeChanged: _cyclePlaybackMode,
              ),
              MobileTabs(
                current: section,
                onChanged: _setSection,
                canManageLibrary: canManageLibrary,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1460),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: cardDecoration(radius: 18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        SideNavigation(
                          current: section,
                          onChanged: _setSection,
                          canManageLibrary: canManageLibrary,
                        ),
                        Expanded(
                          child: _withRequestOverlay(bodyContent, isMobile),
                        ),
                      ],
                    ),
                  ),
                  PlayerBar(
                    song: currentSong,
                    isMobile: false,
                    onOpenPlayer: _openPlayer,
                    onOpenQueue: _openQueue,
                    onTogglePlay: _togglePlay,
                    audioController: audioController,
                    isLoading: isAudioLoading,
                    onSeek: _seek,
                    onNext: _playNext,
                    onPrevious: _playPrevious,
                    playbackMode: playbackMode,
                    onPlaybackModeChanged: _cyclePlaybackMode,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didPushNext() {
    if (_isRouteVisible && mounted) {
      setState(() => _isRouteVisible = false);
    }
  }

  @override
  void didPopNext() {
    if (!_isRouteVisible && mounted) {
      setState(() => _isRouteVisible = true);
    }
  }

  void _setSection(MusicSection value) {
    setState(() {
      if (value == MusicSection.music) {
        musicInitialSegment = 0;
      }
      section = value;
    });
  }

  void _openMusic({int initialSegment = 0}) {
    setState(() {
      musicInitialSegment = initialSegment;
      section = MusicSection.music;
    });
  }

  void _handleLibraryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handlePlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
    _schedulePlaybackStateSave();
  }

  void _handleLoadingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _schedulePlaybackStateSave() {
    if (_restoringPlaybackState || !hasLoadedData) {
      return;
    }
    _playbackSaveTimer?.cancel();
    _playbackSaveTimer = Timer(const Duration(milliseconds: 650), () {
      unawaited(_savePlaybackStateNow());
    });
  }

  Future<void> _savePlaybackStateNow() async {
    if (_restoringPlaybackState || !hasLoadedData) {
      return;
    }
    final song = currentSong;
    if (song == null) {
      await PlaybackStateStorage.clear();
      return;
    }
    await PlaybackStateStorage.save(
      SavedPlaybackState(
        songId: song.id,
        queueIds: playbackController.currentQueue
            .map((item) => item.id)
            .where((id) => id > 0)
            .toList(),
        playbackMode: playbackMode,
        position: audioController.currentPosition,
      ),
    );
  }

  Widget _withRequestOverlay(Widget child, bool isMobile) {
    final updateBanner = _buildUpdateBanner(isMobile: isMobile);
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (updateBanner != null)
          Positioned(
            top: requestLoading.visible
                ? (isMobile ? 62 : 70)
                : (isMobile ? 12 : 18),
            right: isMobile ? 12 : 18,
            left: isMobile ? 12 : null,
            child: updateBanner,
          ),
        if (requestLoading.visible)
          Positioned(
            top: isMobile ? 12 : 18,
            left: 0,
            right: 0,
            child: const Center(child: RequestLoadingBanner()),
          ),
      ],
    );
  }

  Widget? _buildUpdateBanner({required bool isMobile}) {
    final info = availableUpdate;
    if (info == null || _updateBannerDismissed) {
      return null;
    }
    if (updateDownload.hasDownloaded) {
      return _UpdateStatusBanner(
        isMobile: isMobile,
        icon: Icons.install_desktop_rounded,
        title: '新版本已下载',
        message: 'v${info.version} 已准备好安装',
        actionText: '安装',
        onAction: _installDownloadedUpdate,
        onClose: info.mandatory ? null : _dismissUpdateBanner,
      );
    }
    if (updateDownload.isDownloading) {
      return _UpdateStatusBanner(
        isMobile: isMobile,
        icon: Icons.downloading_rounded,
        title: '正在下载更新',
        message: '${(updateDownload.progress * 100).clamp(0, 100).round()}%',
        progress: updateDownload.progress,
      );
    }
    if (updateDownload.errorMessage != null) {
      return _UpdateStatusBanner(
        isMobile: isMobile,
        icon: Icons.error_outline_rounded,
        title: '更新下载失败',
        message: updateDownload.errorMessage!,
        actionText: '重试',
        destructive: true,
        onAction: _startUpdateDownload,
        onClose: _dismissUpdateBanner,
      );
    }
    return _UpdateStatusBanner(
      isMobile: isMobile,
      icon: Icons.system_update_alt_rounded,
      title: '发现新版本 v${info.version}',
      message: info.mandatory ? '需要更新后继续使用' : '可在后台下载',
      actionText: '更新',
      onAction: () => _showUpdateDialog(info),
      onClose: info.mandatory ? null : _dismissUpdateBanner,
    );
  }

  void _scheduleUpdateChecks() {
    if (!updateService.isSupportedPlatform) {
      return;
    }
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        unawaited(_checkForAppUpdate());
      }
    });
    _updateTimer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(_checkForAppUpdate(showDialogWhenFound: false));
    });
  }

  Future<void> _checkForAppUpdate({bool showDialogWhenFound = true}) async {
    if (_updateChecking ||
        updateDownload.isDownloading ||
        updateDownload.hasDownloaded) {
      return;
    }
    _updateChecking = true;
    try {
      final info = await updateService.checkForUpdate();
      if (!mounted || info == null) {
        return;
      }
      setState(() {
        availableUpdate = info;
        _updateBannerDismissed = false;
      });
      if (showDialogWhenFound && !_updateDialogShown) {
        _updateDialogShown = true;
        unawaited(_showUpdateDialog(info));
      }
    } catch (error) {
      debugPrint('[Update] check failed: $error');
    } finally {
      _updateChecking = false;
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo info) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (context) => _UpdateDiscoverDialog(
        info: info,
        onLater: info.mandatory
            ? null
            : () {
                Navigator.of(context).pop();
              },
        onDownload: () {
          Navigator.of(context).pop();
          unawaited(_startUpdateDownload());
        },
      ),
    );
  }

  Future<void> _startUpdateDownload() async {
    final info = availableUpdate;
    if (info == null || updateDownload.isDownloading) {
      return;
    }
    setState(() {
      _updateBannerDismissed = false;
      updateDownload = const UpdateDownloadState(isDownloading: true);
    });
    try {
      final path = await updateService.downloadUpdate(
        info,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            updateDownload = UpdateDownloadState(
              isDownloading: true,
              progress: progress,
            );
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        updateDownload = UpdateDownloadState(progress: 1, downloadedPath: path);
      });
      _showTopToast(icon: Icons.download_done_rounded, message: '新版本已下载');
      unawaited(_installDownloadedUpdate());
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        updateDownload = UpdateDownloadState(
          errorMessage: error.toString().replaceFirst('Exception: ', ''),
        );
      });
    }
  }

  Future<void> _installDownloadedUpdate() async {
    final filePath = updateDownload.downloadedPath;
    if (filePath == null || filePath.isEmpty || _installPromptShowing) {
      return;
    }
    _installPromptShowing = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('更新已下载完成'),
        content: const Text('确认后会自动安装并重启应用，安装过程中当前窗口会关闭。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kAccentDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.install_desktop_rounded),
            label: const Text('立即安装'),
          ),
        ],
      ),
    );
    _installPromptShowing = false;
    if (confirmed != true) {
      return;
    }
    final installed = await updateService.installAndRestart(filePath);
    if (!installed && mounted) {
      await updateService.openInstaller(filePath);
    }
  }

  void _dismissUpdateBanner() {
    setState(() => _updateBannerDismissed = true);
  }

  void _setDownloads(List<DownloadTask> value) {
    libraryController.setDownloads(value);
  }

  void _handleDownloadsChanged(List<DownloadTask> value) {
    _setDownloads(value);
    unawaited(_refreshProfileOverview());
  }

  Future<void> _restoreSessionAndLoadData() async {
    final token = await AuthStorage.loadToken();
    if (!mounted) {
      return;
    }
    setState(() => authToken = token);
    await _loadData();
  }

  Future<void> _addDownloadedSong(Song song) async {
    if (canManageLibrary) {
      libraryController.addSongIfAbsentToFront(song);
    }
    final loadedDownloads = await MusicApiClient(
      token: authToken,
    ).fetchDownloads();
    if (!mounted) {
      return;
    }
    _setDownloads(loadedDownloads);
    await _refreshProfileOverview();
  }

  Future<void> _downloadCurrentSong(Song song) async {
    await _downloadSongToLocal(song, showFeedback: false);
  }

  Future<void> _downloadSongFromList(Song song) async {
    try {
      await _downloadSongToLocal(song, showFeedback: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.error_outline_rounded,
        message: '下载失败：${error.toString().replaceFirst('Exception: ', '')}',
        destructive: true,
      );
    }
  }

  Future<void> _downloadSongsFromList(List<Song> selectedSongs) async {
    final targets = selectedSongs
        .where((song) => song.id != 0 && !_isSongDownloaded(song))
        .toList();
    if (targets.isEmpty) {
      _showTopToast(icon: Icons.download_done_rounded, message: '所选歌曲已在本地');
      return;
    }
    try {
      for (final song in targets) {
        await _downloadSongToLocal(song, showFeedback: false);
      }
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.download_done_rounded,
        message: '已下载 ${targets.length} 首歌曲到本地',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.error_outline_rounded,
        message: '批量下载失败：${error.toString().replaceFirst('Exception: ', '')}',
        destructive: true,
      );
    }
  }

  Future<void> _downloadSongToLocal(
    Song song, {
    required bool showFeedback,
  }) async {
    if (_isSongDownloaded(song)) {
      if (showFeedback) {
        _showTopToast(
          icon: Icons.download_done_rounded,
          message: '《${song.title}》已在本地',
        );
      }
      return;
    }
    final loadedDownloads = await requestLoading.track(
      () => MusicApiClient(token: authToken).createDownload(song.id),
    );
    if (!mounted) {
      return;
    }
    _setDownloads(loadedDownloads);
    final downloadedTask = loadedDownloads
        .where((task) => task.song.id == song.id)
        .cast<DownloadTask?>()
        .firstWhere((task) => task != null, orElse: () => null);
    if (downloadedTask != null) {
      _replaceSong(downloadedTask.song);
    }
    await _refreshProfileOverview();
    if (showFeedback) {
      _showTopToast(
        icon: Icons.download_done_rounded,
        message: '已下载《${song.title}》到本地',
      );
    }
  }

  bool _isSongDownloaded(Song song) {
    return downloads.any((task) => task.song.id == song.id);
  }

  Future<int> _importLocalMusic(List<String> paths) async {
    if (!canManageLibrary) {
      return 0;
    }
    final importedSongs = await requestLoading.track(
      () => MusicApiClient(token: authToken).importLocalMusic(paths),
    );
    final loadedSongs = await requestLoading.track(
      () => MusicApiClient(token: authToken).fetchSongs(),
    );
    final loadedDownloads = await requestLoading.track(
      () => MusicApiClient(token: authToken).fetchDownloads(),
    );
    if (!mounted) {
      return importedSongs.length;
    }
    libraryController.setSongs(loadedSongs);
    _setDownloads(loadedDownloads);
    if (importedSongs.isNotEmpty && currentSong == null) {
      playbackController.setCurrentSong(
        importedSongs.first,
        queue: loadedSongs,
      );
    }
    await _refreshProfileOverview();
    _showTopToast(
      icon: Icons.library_add_check_rounded,
      message: '已导入 ${importedSongs.length} 首本地音乐',
    );
    return importedSongs.length;
  }

  void _setOnlineDownloadKeyword(String value) {
    onlineDownloadKeyword = value;
  }

  void _clearOnlineDownloadError() {
    if (onlineDownloadError == null) {
      return;
    }
    setState(() => onlineDownloadError = null);
  }

  void _pauseOnlineBatch() {
    if (!onlineBatchActive) {
      return;
    }
    setState(() {
      onlineBatchPauseRequested = true;
      onlineDownloadError = '已暂停，当前歌曲完成后会停止批量获取';
    });
  }

  Future<void> _searchOnlineDownloads() async {
    final keyword = onlineDownloadKeyword.trim();
    if (keyword.isEmpty || onlineSearchActive || onlineBatchActive) {
      return;
    }
    setState(() {
      onlineSearchActive = true;
      onlineDownloadError = null;
      onlineDownloadResults = const [];
      onlineBatchCompleted = 0;
      onlineBatchTotal = 0;
      onlineBatchSuccess = 0;
      onlineBatchQueue = const [];
      onlineBatchPauseRequested = false;
    });
    try {
      final data = await MusicApiClient(
        token: authToken,
      ).searchOnlineMusic(keyword);
      if (!mounted) {
        return;
      }
      setState(() {
        onlineDownloadResults = data;
        onlineDownloadError = data.isEmpty ? '没有搜索到相关歌曲' : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException && error.isUnauthorized) {
        await _logout();
        if (mounted) {
          setState(() => onlineDownloadError = '登录状态已过期，请重新登录后再获取歌曲');
        }
        return;
      }
      setState(
        () => onlineDownloadError = error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => onlineSearchActive = false);
      }
    }
  }

  Future<void> _downloadOnlineSong(Map<String, dynamic> song) async {
    final id = song['id'] as String? ?? '';
    if (id.isEmpty ||
        onlineDownloadingId != null ||
        onlineDownloadedIds.contains(id) ||
        onlineBatchActive) {
      return;
    }
    setState(() {
      onlineDownloadingId = id;
      onlineDownloadError = null;
    });
    try {
      final downloaded = await MusicApiClient(token: authToken)
          .downloadOnlineMusic(
            id,
            song['title'] as String? ?? '在线歌曲',
            song['artist'] as String? ?? '',
          );
      if (!mounted) {
        return;
      }
      setState(() {
        onlineDownloadedIds = {...onlineDownloadedIds, id};
        onlineDownloadError = null;
      });
      await _addDownloadedSong(downloaded);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException && error.isUnauthorized) {
        await _logout();
        if (mounted) {
          setState(() => onlineDownloadError = '登录状态已过期，请重新登录后再获取歌曲');
        }
        return;
      }
      setState(
        () => onlineDownloadError = error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => onlineDownloadingId = null);
      }
    }
  }

  Future<void> _downloadOnlineBatch(List<Map<String, dynamic>> items) async {
    final canResume =
        onlineBatchQueue.isNotEmpty &&
        onlineBatchCompleted > 0 &&
        onlineBatchCompleted < onlineBatchTotal;
    final targets = canResume
        ? onlineBatchQueue.skip(onlineBatchCompleted).toList()
        : items
              .where((song) => !onlineDownloadedIds.contains(song['id']))
              .toList();
    if (targets.isEmpty || onlineBatchActive || onlineDownloadingId != null) {
      return;
    }
    setState(() {
      onlineBatchActive = true;
      onlineBatchPauseRequested = false;
      if (!canResume) {
        onlineBatchCompleted = 0;
        onlineBatchTotal = targets.length;
        onlineBatchSuccess = 0;
        onlineBatchQueue = targets;
      }
      onlineDownloadingId = null;
      onlineDownloadError = null;
    });
    final failedTitles = <String>[];
    try {
      for (final song in targets) {
        if (!mounted || onlineBatchPauseRequested) {
          break;
        }
        final id = song['id'] as String? ?? '';
        if (id.isEmpty || onlineDownloadedIds.contains(id)) {
          if (mounted) {
            setState(() => onlineBatchCompleted++);
          }
          continue;
        }
        setState(() {
          onlineDownloadingId = id;
          onlineDownloadError = null;
        });
        try {
          final downloaded = await MusicApiClient(token: authToken)
              .downloadOnlineMusic(
                id,
                song['title'] as String? ?? '在线歌曲',
                song['artist'] as String? ?? '',
              );
          if (!mounted) {
            return;
          }
          setState(() {
            onlineDownloadedIds = {...onlineDownloadedIds, id};
            onlineBatchSuccess++;
          });
          await _addDownloadedSong(downloaded);
        } catch (error) {
          if (error is ApiException && error.isUnauthorized) {
            if (!mounted) {
              return;
            }
            await _logout();
            if (mounted) {
              setState(() {
                onlineDownloadError = '登录状态已过期，请重新登录后再批量获取';
                onlineDownloadingId = null;
              });
            }
            return;
          }
          failedTitles.add(song['title'] as String? ?? '未知歌曲');
        } finally {
          if (mounted) {
            setState(() => onlineBatchCompleted++);
          }
        }
      }
      if (!mounted) {
        return;
      }
      if (onlineBatchPauseRequested) {
        setState(
          () => onlineDownloadError =
              '已暂停在 $onlineBatchCompleted/$onlineBatchTotal',
        );
      } else if (failedTitles.isNotEmpty) {
        final firstFailed = failedTitles.take(2).join('、');
        final suffix = failedTitles.length > 2
            ? '等 ${failedTitles.length} 首'
            : '';
        setState(() {
          onlineDownloadError = onlineBatchSuccess > 0
              ? '已获取 $onlineBatchSuccess 首，$firstFailed$suffix 暂时不可获取'
              : '$firstFailed$suffix 暂时不可下载，请换一个版本试试';
          onlineBatchQueue = const [];
        });
      } else if (onlineBatchSuccess == 0) {
        setState(() {
          onlineDownloadError = '没有可获取的歌曲';
          onlineBatchQueue = const [];
        });
      } else {
        setState(() {
          onlineDownloadError = null;
          onlineBatchQueue = const [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          onlineBatchActive = false;
          onlineBatchPauseRequested = false;
          onlineDownloadingId = null;
        });
      }
    }
  }

  Future<void> _selectSong(Song song, {List<Song>? queue}) async {
    await _selectSongWithFallback(song, queue: queue, wrap: true);
  }

  Future<void> _selectSearchSong(Song song, {List<Song>? queue}) async {
    final mergedQueue = <Song>[song];
    for (final item in songs) {
      if (item.id != song.id) {
        mergedQueue.add(item);
      }
    }
    for (final item in queue ?? const <Song>[]) {
      if (!mergedQueue.any((queued) => queued.id == item.id)) {
        mergedQueue.add(item);
      }
    }
    await _selectSongWithFallback(song, queue: mergedQueue, wrap: true);
  }

  Future<bool> _selectSongWithFallback(
    Song song, {
    List<Song>? queue,
    required bool wrap,
    Duration startPosition = Duration.zero,
    bool allowFallback = false,
  }) async {
    final playbackQueue = queue ?? playbackController.queueOr(songs);
    final played = await _playSong(
      song,
      queue: playbackQueue,
      startPosition: startPosition,
    );
    if (played) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    if (!allowFallback) {
      final message =
          playbackController.playbackError ??
          '${song.title} 暂时无法播放，请检查音频文件或稍后重试';
      playbackController.failSongLoad(message: message);
      _showPlaybackError(message);
      return false;
    }

    final failedSongIds = <int>{};
    failedSongIds.add(song.id);
    Song? candidate = playbackController.fallbackSong(
      playbackQueue,
      failedSongIds,
      wrap: wrap,
    );
    Object? lastError;
    while (candidate != null && mounted) {
      final played = await _playSong(candidate, queue: playbackQueue);
      if (played) {
        return true;
      }
      failedSongIds.add(candidate.id);
      lastError = playbackController.playbackError;
      candidate = playbackController.fallbackSong(
        playbackQueue,
        failedSongIds,
        wrap: wrap,
      );
    }
    if (!mounted) {
      return false;
    }
    playbackController.failSongLoad(message: '当前播放队列暂时无法播放');
    _showPlaybackError(playbackController.playbackError ?? lastError);
    return false;
  }

  Future<void> _playQueue(List<Song> queue) async {
    final playableQueue = queue.where((song) => song.id != 0).toList();
    if (playableQueue.isEmpty) {
      return;
    }
    final played = await _selectSongWithFallback(
      playableQueue.first,
      queue: playableQueue,
      wrap: true,
    );
    if (!mounted || !played) {
      return;
    }
    _showTopToast(
      icon: Icons.queue_play_next_rounded,
      message: '已用 ${playableQueue.length} 首歌曲替换当前队列',
    );
  }

  Future<bool> _playSong(
    Song song, {
    List<Song>? queue,
    Duration startPosition = Duration.zero,
  }) async {
    playbackController.prepareSong(song, queue: queue);
    try {
      await audioController.play(
        song,
        startPosition: startPosition,
        authToken: authToken,
      );
      try {
        await MusicApiClient(token: authToken).recordPlay(song.id);
        await _refreshProfileOverview();
      } catch (_) {}
      if (!mounted) {
        return false;
      }
      playbackController.finishSongLoad(playing: audioController.isPlaying);
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      final message = _playbackFailureMessage(song, error);
      playbackController.failSongLoad(message: message);
      return false;
    }
  }

  String _playbackFailureMessage(Song song, Object error) {
    if (error is TimeoutException) {
      return '《${song.title}》加载超时，请检查网络或音频文件';
    }
    final detail = error.toString().replaceFirst('Exception: ', '').trim();
    if (detail.isEmpty) {
      return '《${song.title}》暂时无法播放';
    }
    return '《${song.title}》暂时无法播放：$detail';
  }

  void _showPlaybackError(Object? error) {
    final detail = error?.toString().replaceFirst('Exception: ', '');
    final message = detail == null || detail.isEmpty ? '当前播放队列暂时无法播放' : detail;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Song> _toggleFavorite(Song song) async {
    final updated = await requestLoading.track(
      () => MusicApiClient(
        token: authToken,
      ).updateSongFavorite(song.id, !song.isFavorite),
    );
    if (!mounted) {
      return updated;
    }
    _replaceSong(updated);
    await _refreshProfileOverview();
    return updated;
  }

  Future<void> _editSong(Song song) async {
    if (!canManageLibrary) {
      return;
    }
    final updated = await showDialog<Song>(
      context: context,
      builder: (context) => EditSongDialog(
        song: song,
        onUpdate: (title, artist, album, lyrics, lyricsOffsetMs) =>
            _updateSong(song, title, artist, album, lyrics, lyricsOffsetMs),
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    _showTopToast(icon: Icons.edit_rounded, message: '已更新《${updated.title}》');
  }

  Future<Song> _updateSong(
    Song song,
    String title,
    String artist,
    String album,
    String lyrics,
    int lyricsOffsetMs,
  ) async {
    if (!canManageLibrary) {
      return song;
    }
    final updated = await requestLoading.track(
      () => MusicApiClient(
        token: authToken,
      ).updateSong(song.id, title, artist, album, lyrics, lyricsOffsetMs),
    );
    if (!mounted) {
      return updated;
    }
    _replaceSong(updated);
    await _refreshProfileOverview();
    return updated;
  }

  Future<Song> _updateSongLyricsOffset(Song song, int lyricsOffsetMs) {
    return _updateSong(
      song,
      song.title,
      song.artist,
      song.album,
      song.lyrics,
      lyricsOffsetMs,
    );
  }

  Future<Song> _fetchSongLyrics(Song song) async {
    if (!canManageLibrary) {
      return song;
    }
    final updated = await requestLoading.track(
      () => MusicApiClient(token: authToken).fetchSongLyrics(song.id),
    );
    if (!mounted) {
      return updated;
    }
    _replaceSong(updated);
    await _refreshProfileOverview();
    _showTopToast(
      icon: Icons.lyrics_rounded,
      message: '已补全《${updated.title}》歌词',
    );
    return updated;
  }

  Future<void> _deleteSong(Song song) async {
    if (!canManageLibrary) {
      return;
    }
    final confirmed = await _confirmDeleteSong(song);
    if (!confirmed || !mounted) {
      return;
    }
    final wasCurrent = currentSong?.id == song.id;
    final remainingSongs = songs.where((item) => item.id != song.id).toList();
    if (wasCurrent) {
      try {
        await audioController.stop();
      } catch (_) {}
      audioController.currentSong = null;
      audioController.currentPosition = Duration.zero;
      audioController.currentDuration = Duration.zero;
    }
    try {
      await requestLoading.track(
        () => MusicApiClient(token: authToken).deleteSong(song.id),
      );
      if (!mounted) {
        return;
      }
      libraryController.removeSongEverywhere(song.id);
      final nextCurrent = wasCurrent
          ? (remainingSongs.isEmpty ? null : remainingSongs.first)
          : currentSong;
      playbackController.setCurrentSong(nextCurrent, queue: remainingSongs);
      unawaited(_refreshProfileOverview());
      _showTopToast(
        icon: Icons.check_circle_rounded,
        message: '已删除《${song.title}》',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.error_outline_rounded,
        message: '删除失败：$error',
        destructive: true,
      );
    }
  }

  Future<void> _deleteSongsFromList(List<Song> selectedSongs) async {
    if (!canManageLibrary) {
      return;
    }
    final targets = selectedSongs.where((song) => song.id != 0).toList();
    if (targets.isEmpty) {
      return;
    }
    final confirmed = await _confirmDeleteSongs(targets);
    if (!confirmed || !mounted) {
      return;
    }
    final deleteIds = targets.map((song) => song.id).toSet();
    final wasCurrent =
        currentSong != null && deleteIds.contains(currentSong!.id);
    final remainingSongs = songs
        .where((song) => !deleteIds.contains(song.id))
        .toList();
    if (wasCurrent) {
      try {
        await audioController.stop();
      } catch (_) {}
      audioController.currentSong = null;
      audioController.currentPosition = Duration.zero;
      audioController.currentDuration = Duration.zero;
    }
    try {
      await requestLoading.track(() async {
        final client = MusicApiClient(token: authToken);
        for (final song in targets) {
          await client.deleteSong(song.id);
        }
      });
      if (!mounted) {
        return;
      }
      for (final song in targets) {
        libraryController.removeSongEverywhere(song.id);
      }
      final nextCurrent = wasCurrent
          ? (remainingSongs.isEmpty ? null : remainingSongs.first)
          : currentSong;
      playbackController.setCurrentSong(nextCurrent, queue: remainingSongs);
      unawaited(_refreshProfileOverview());
      _showTopToast(
        icon: Icons.check_circle_rounded,
        message: '已删除 ${targets.length} 首歌曲',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.error_outline_rounded,
        message: '批量删除失败：$error',
        destructive: true,
      );
    }
  }

  void _showTopToast({
    required IconData icon,
    required String message,
    bool destructive = false,
  }) {
    final color = destructive ? const Color(0xFFE15B5B) : kAccent;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.up,
          margin: EdgeInsets.only(
            left: 92,
            right: 92,
            bottom: MediaQuery.sizeOf(context).height - 92,
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          duration: const Duration(milliseconds: 2200),
          content: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.white, color, .08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: .18)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .13),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: kInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  Future<bool> _confirmDeleteSong(Song song) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return false;
    }
    final completer = Completer<bool>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _DeleteSongConfirmOverlay(
        song: song,
        onCompleted: (confirmed) {
          entry.remove();
          if (!completer.isCompleted) {
            completer.complete(confirmed);
          }
        },
      ),
    );
    overlay.insert(entry);
    return completer.future;
  }

  Future<bool> _confirmDeleteSongs(List<Song> selectedSongs) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('批量删除歌曲？'),
        content: Text('将从曲库中删除 ${selectedSongs.length} 首歌曲，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE15B5B),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('删除'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmDeletePlaylist(Playlist playlist) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return false;
    }
    final completer = Completer<bool>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _DeletePlaylistConfirmOverlay(
        playlist: playlist,
        onCompleted: (confirmed) {
          entry.remove();
          if (!completer.isCompleted) {
            completer.complete(confirmed);
          }
        },
      ),
    );
    overlay.insert(entry);
    return completer.future;
  }

  Future<Playlist> _createPlaylist(String name, String description) async {
    final created = await requestLoading.track(
      () => MusicApiClient(token: authToken).createPlaylist(name, description),
    );
    if (!mounted) {
      return created;
    }
    libraryController.addPlaylistToFront(created);
    await _refreshProfileOverview();
    return created;
  }

  Future<Playlist> _updatePlaylist(
    Playlist playlist,
    String name,
    String description,
  ) async {
    final updated = await requestLoading.track(
      () => MusicApiClient(
        token: authToken,
      ).updatePlaylist(playlist.id, name, description),
    );
    if (!mounted) {
      return updated;
    }
    _replacePlaylist(updated);
    await _refreshProfileOverview();
    _showTopToast(icon: Icons.edit_rounded, message: '已更新歌单「${updated.name}」');
    return updated;
  }

  Future<bool> _deletePlaylist(Playlist playlist) async {
    final confirmed = await _confirmDeletePlaylist(playlist);
    if (!confirmed || !mounted) {
      return false;
    }
    try {
      await requestLoading.track(
        () => MusicApiClient(token: authToken).deletePlaylist(playlist.id),
      );
      if (!mounted) {
        return false;
      }
      libraryController.removePlaylist(playlist.id);
      await _refreshProfileOverview();
      _showTopToast(
        icon: Icons.check_circle_rounded,
        message: '已删除歌单「${playlist.name}」',
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      _showTopToast(
        icon: Icons.error_outline_rounded,
        message: '删除失败：${error.toString().replaceFirst('Exception: ', '')}',
        destructive: true,
      );
      return false;
    }
  }

  Future<Playlist> _fetchPlaylist(Playlist playlist) async {
    final loaded = await requestLoading.track(
      () => MusicApiClient(token: authToken).fetchPlaylist(playlist.id),
    );
    if (mounted) {
      _replacePlaylist(loaded);
    }
    return loaded;
  }

  Future<Playlist> _togglePlaylistFavorite(Playlist playlist) async {
    final updated = await requestLoading.track(
      () => MusicApiClient(
        token: authToken,
      ).updatePlaylistFavorite(playlist.id, !playlist.isFavorite),
    );
    if (mounted) {
      _replacePlaylist(updated);
      await _refreshProfileOverview();
    }
    return updated;
  }

  Future<Playlist> _addSongToPlaylist(Playlist playlist, Song song) async {
    final updated = await requestLoading.track(
      () => MusicApiClient(
        token: authToken,
      ).addSongToPlaylist(playlist.id, song.id),
    );
    if (mounted) {
      _replacePlaylist(updated);
      await _refreshProfileOverview();
    }
    return updated;
  }

  Future<void> _addSongToPlaylistFromList(Song song) async {
    if (song.id == 0) {
      return;
    }
    final choice = await _showAddToPlaylistOverlay(song, playlists);
    if (choice == null || !mounted) {
      return;
    }
    try {
      final target = choice.playlist;
      if (target != null) {
        if (target.songs.any((item) => item.id == song.id)) {
          _showTopToast(
            icon: Icons.playlist_add_check_rounded,
            message: '《${song.title}》已在「${target.name}」',
          );
          return;
        }
        final updated = await _addSongToPlaylist(target, song);
        if (!mounted) {
          return;
        }
        _showTopToast(
          icon: Icons.playlist_add_rounded,
          message: '已添加到「${updated.name}」',
        );
        return;
      }
      final created = await _createPlaylist(
        choice.name.trim(),
        choice.description.trim(),
      );
      final updated = await _addSongToPlaylist(created, song);
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.playlist_add_rounded,
        message: '已添加到「${updated.name}」',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.error_outline_rounded,
        message: '添加失败：${error.toString().replaceFirst('Exception: ', '')}',
        destructive: true,
      );
    }
  }

  Future<void> _addSongsToPlaylistFromList(List<Song> selectedSongs) async {
    final targets = selectedSongs.where((song) => song.id != 0).toList();
    if (targets.isEmpty) {
      return;
    }
    final choice = await _showAddToPlaylistOverlay(targets.first, playlists);
    if (choice == null || !mounted) {
      return;
    }
    try {
      final target = choice.playlist;
      Playlist destination;
      if (target == null) {
        destination = await _createPlaylist(
          choice.name.trim(),
          choice.description.trim(),
        );
      } else {
        destination = target;
      }
      final existingIds = destination.songs.map((song) => song.id).toSet();
      final songsToAdd = targets
          .where((song) => !existingIds.contains(song.id))
          .toList();
      if (songsToAdd.isEmpty) {
        _showTopToast(
          icon: Icons.playlist_add_check_rounded,
          message: '所选歌曲已在「${destination.name}」',
        );
        return;
      }
      var updated = destination;
      await requestLoading.track(() async {
        final client = MusicApiClient();
        for (final song in songsToAdd) {
          updated = await client.addSongToPlaylist(updated.id, song.id);
        }
      });
      if (!mounted) {
        return;
      }
      _replacePlaylist(updated);
      await _refreshProfileOverview();
      _showTopToast(
        icon: Icons.playlist_add_rounded,
        message: '已添加 ${songsToAdd.length} 首歌曲到「${updated.name}」',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.error_outline_rounded,
        message: '批量添加失败：${error.toString().replaceFirst('Exception: ', '')}',
        destructive: true,
      );
    }
  }

  Future<_AddToPlaylistChoice?> _showAddToPlaylistOverlay(
    Song song,
    List<Playlist> playlists,
  ) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return Future.value();
    }
    final completer = Completer<_AddToPlaylistChoice?>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AddToPlaylistOverlay(
        song: song,
        playlists: playlists,
        onCompleted: (playlist) {
          entry.remove();
          if (!completer.isCompleted) {
            completer.complete(playlist);
          }
        },
      ),
    );
    overlay.insert(entry);
    return completer.future;
  }

  Future<Playlist> _removeSongFromPlaylist(Playlist playlist, Song song) async {
    final updated = await requestLoading.track(
      () => MusicApiClient(
        token: authToken,
      ).removeSongFromPlaylist(playlist.id, song.id),
    );
    if (mounted) {
      _replacePlaylist(updated);
      await _refreshProfileOverview();
    }
    return updated;
  }

  Future<Playlist> _reorderPlaylistSongs(
    Playlist playlist,
    List<Song> orderedSongs,
  ) async {
    final updated = await requestLoading.track(
      () => MusicApiClient(token: authToken).reorderPlaylistSongs(
        playlist.id,
        orderedSongs.map((song) => song.id).toList(),
      ),
    );
    if (mounted) {
      _replacePlaylist(updated);
      await _refreshProfileOverview();
    }
    return updated;
  }

  void _replacePlaylist(Playlist updated) {
    libraryController.upsertPlaylist(updated);
  }

  void _replaceSong(Song updated) {
    playbackController.updateCurrentSongIfMatching(updated);
    libraryController.replaceSongEverywhere(updated);
  }

  Future<void> _loadData() async {
    appLoading.start();
    setState(() {
      loadError = null;
    });

    try {
      final savedPlayback = await PlaybackStateStorage.load();
      ProfileOverview? loadedOverview;
      var nextAuthToken = authToken;
      final client = MusicApiClient(token: nextAuthToken);
      final songPage = await client.fetchSongsPage(limit: _songPageSize);
      final loadedSongs = songPage.items;
      var loadedPlaylists = <Playlist>[];
      var loadedDownloads = <DownloadTask>[];
      if (nextAuthToken != null) {
        try {
          final authedClient = MusicApiClient(token: nextAuthToken);
          loadedPlaylists = await authedClient.fetchPlaylists();
          loadedDownloads = await authedClient.fetchDownloads();
          loadedOverview = await authedClient.fetchProfileOverview();
        } on ApiException catch (error) {
          if (!error.isUnauthorized) {
            rethrow;
          }
          await AuthStorage.clearToken();
          nextAuthToken = null;
        }
      }
      if (!mounted) {
        return;
      }
      libraryController.setAll(
        songs: loadedSongs,
        playlists: loadedPlaylists,
        downloads: loadedDownloads,
      );
      final byId = {for (final song in loadedSongs) song.id: song};
      final currentID = currentSong?.id;
      final refreshedCurrent = currentID == null ? null : byId[currentID];
      final restoredCurrent = savedPlayback?.songId == null
          ? null
          : byId[savedPlayback!.songId];
      final restoredQueue = savedPlayback == null
          ? const <Song>[]
          : savedPlayback.queueIds
                .map((id) => byId[id])
                .whereType<Song>()
                .toList();
      final nextCurrent =
          restoredCurrent ??
          refreshedCurrent ??
          (loadedSongs.isEmpty ? null : loadedSongs.first);
      final nextQueue = restoredQueue.isEmpty ? loadedSongs : restoredQueue;
      setState(() {
        authToken = nextAuthToken;
        profileOverview = loadedOverview;
        hasMoreSongs = songPage.hasMore;
        songNextCursor = songPage.nextCursor;
        songTotalCount = songPage.totalCount;
        hasLoadedData = true;
      });
      _restoringPlaybackState = true;
      if (savedPlayback != null) {
        playbackController.setPlaybackMode(savedPlayback.playbackMode);
      }
      playbackController.setCurrentSong(nextCurrent, queue: nextQueue);
      if (nextCurrent == null || nextCurrent.id != restoredCurrent?.id) {
        audioController.currentPosition = Duration.zero;
        audioController.currentDuration = Duration.zero;
      } else {
        final duration = nextCurrent.duration;
        final position = savedPlayback!.position;
        audioController.currentDuration = duration;
        audioController.currentPosition =
            duration > Duration.zero && position >= duration
            ? Duration.zero
            : position;
      }
      _restoringPlaybackState = false;
      _schedulePlaybackStateSave();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        loadError = error.toString();
      });
    } finally {
      appLoading.stop();
    }
  }

  Future<void> _loadMoreSongs() async {
    if (isLoadingMoreSongs || !hasMoreSongs) {
      return;
    }
    setState(() => isLoadingMoreSongs = true);
    try {
      final page = await MusicApiClient(
        token: authToken,
      ).fetchSongsPage(limit: _songPageSize, cursor: songNextCursor);
      if (!mounted) {
        return;
      }
      libraryController.appendSongs(page.items);
      setState(() {
        hasMoreSongs = page.hasMore;
        songNextCursor = page.nextCursor;
        songTotalCount = page.totalCount;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTopToast(
        icon: Icons.error_outline_rounded,
        message: '加载更多失败：${error.toString().replaceFirst('Exception: ', '')}',
        destructive: true,
      );
    } finally {
      if (mounted) {
        setState(() => isLoadingMoreSongs = false);
      }
    }
  }

  Future<List<Song>> _loadMoreQueueSongs() async {
    if (isLoadingMoreSongs || !hasMoreSongs) {
      return const [];
    }
    setState(() => isLoadingMoreSongs = true);
    try {
      final page = await MusicApiClient(
        token: authToken,
      ).fetchSongsPage(limit: _songPageSize, cursor: songNextCursor);
      if (!mounted) {
        return const [];
      }
      libraryController.appendSongs(page.items);
      final currentQueue = playbackController.queueOr(songs);
      final existingIds = currentQueue.map((song) => song.id).toSet();
      final nextQueue = [
        ...currentQueue,
        ...page.items.where((song) => existingIds.add(song.id)),
      ];
      playbackController.setQueue(nextQueue);
      setState(() {
        hasMoreSongs = page.hasMore;
        songNextCursor = page.nextCursor;
        songTotalCount = page.totalCount;
      });
      return page.items;
    } catch (error) {
      if (mounted) {
        _showTopToast(
          icon: Icons.error_outline_rounded,
          message: '加载队列失败：${error.toString().replaceFirst('Exception: ', '')}',
          destructive: true,
        );
      }
      return const [];
    } finally {
      if (mounted) {
        setState(() => isLoadingMoreSongs = false);
      }
    }
  }

  Future<void> _login(String username, String password) async {
    final session = await requestLoading.track(
      () => MusicApiClient().login(username, password),
    );
    final authedClient = MusicApiClient(token: session.token);
    final overview = await requestLoading.track(
      () => authedClient.fetchProfileOverview(),
    );
    final loadedPlaylists = await requestLoading.track(
      () => authedClient.fetchPlaylists(),
    );
    final loadedDownloads = await requestLoading.track(
      () => authedClient.fetchDownloads(),
    );
    await AuthStorage.saveToken(session.token);
    if (!mounted) {
      return;
    }
    libraryController.setPlaylists(loadedPlaylists);
    _setDownloads(loadedDownloads);
    setState(() {
      authToken = session.token;
      profileOverview = overview;
    });
  }

  Future<void> _refreshProfileOverview() async {
    final token = authToken;
    if (token == null) {
      return;
    }
    final overview = await requestLoading.track(
      () => MusicApiClient(token: token).fetchProfileOverview(),
    );
    if (!mounted) {
      return;
    }
    setState(() => profileOverview = overview);
  }

  Future<void> _logout() async {
    await AuthStorage.clearToken();
    if (!mounted) {
      return;
    }
    libraryController.setPlaylists(const []);
    _setDownloads(const []);
    setState(() {
      authToken = null;
      profileOverview = null;
    });
  }

  void _openPlayer() {
    final initialSong = currentSong;
    if (initialSong == null) {
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => AnimatedBuilder(
          animation: playbackController,
          builder: (context, _) {
            final routeSong = currentSong ?? initialSong;
            return PlayerPage(
              song: routeSong,
              queue: playbackController.queueOr(songs),
              queueHasMore: hasMoreSongs,
              queueLoadingMore: isLoadingMoreSongs,
              queueTotalCount: songTotalCount,
              onQueueLoadMore: _loadMoreQueueSongs,
              onSongTap: _selectSong,
              onFavoriteToggle: _toggleFavorite,
              onSongEdit: canManageLibrary ? _editSong : null,
              audioController: audioController,
              isLoading: isAudioLoading,
              onTogglePlay: _togglePlay,
              onSeek: _seek,
              onNext: _playNext,
              onPrevious: _playPrevious,
              playbackMode: playbackMode,
              onPlaybackModeChanged: _cyclePlaybackMode,
              downloaded: _isSongDownloaded(routeSong),
              onDownload: _downloadCurrentSong,
              onLyricsOffsetChanged: canManageLibrary
                  ? _updateSongLyricsOffset
                  : null,
              onLyricsFetch: canManageLibrary ? _fetchSongLyrics : null,
              onQueueRemove: _removeSongFromQueue,
              onQueuePlayNext: _moveSongNextInQueue,
              onQueueReorder: _reorderPlaybackQueue,
              onQueueClear: _clearPlaybackQueue,
            );
          },
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _openQueue() {
    final song = currentSong;
    if (song == null) {
      return;
    }
    showPlaybackQueueSheet(
      context,
      currentSong: song,
      queue: playbackController.queueOr(songs),
      queueHasMore: hasMoreSongs,
      queueLoadingMore: isLoadingMoreSongs,
      queueTotalCount: songTotalCount,
      onQueueLoadMore: _loadMoreQueueSongs,
      onSongTap: _selectSong,
      onFavoriteToggle: _toggleFavorite,
      onQueueRemove: _removeSongFromQueue,
      onQueuePlayNext: _moveSongNextInQueue,
      onQueueReorder: _reorderPlaybackQueue,
      onQueueClear: _clearPlaybackQueue,
    );
  }

  void _removeSongFromQueue(Song song, List<Song> queue) {
    playbackController.removeFromQueue(song, queue);
    _showTopToast(icon: Icons.playlist_remove_rounded, message: '已从队列移除');
  }

  void _moveSongNextInQueue(Song song, List<Song> queue) {
    playbackController.moveSongNext(song, queue);
    _showTopToast(icon: Icons.low_priority_rounded, message: '已设为下一首播放');
  }

  void _queueSongNext(Song song) {
    if (currentSong == null) {
      _showTopToast(icon: Icons.info_outline_rounded, message: '请先播放一首歌');
      return;
    }
    if (currentSong?.id == song.id) {
      _showTopToast(icon: Icons.graphic_eq_rounded, message: '这首歌正在播放');
      return;
    }
    final queued = playbackController.queueSongNext(song);
    if (!queued) {
      return;
    }
    _showTopToast(icon: Icons.low_priority_rounded, message: '已加入下一首播放');
  }

  void _reorderPlaybackQueue(List<Song> queue, int oldIndex, int newIndex) {
    playbackController.moveQueueItem(queue, oldIndex, newIndex);
  }

  void _clearPlaybackQueue() {
    playbackController.clearQueue();
    _showTopToast(icon: Icons.clear_all_rounded, message: '已清空播放队列');
  }

  Future<void> _togglePlay() async {
    final song = currentSong;
    if (song == null) {
      return;
    }
    if (audioController.currentSong == null) {
      await _selectSongWithFallback(
        song,
        queue: playbackController.queueOr(songs),
        wrap: true,
        startPosition: audioController.currentPosition,
      );
      return;
    }
    playbackController.setAudioLoading(true);
    try {
      await audioController.toggle();
      if (!mounted) {
        return;
      }
      playbackController.finishSongLoad(playing: audioController.isPlaying);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _playbackFailureMessage(song, error);
      playbackController.failSongLoad(message: message);
      _showPlaybackError(message);
    }
  }

  Future<void> _seek(Duration position) async {
    playbackController.setAudioLoading(true);
    try {
      await audioController.seek(position);
      _schedulePlaybackStateSave();
    } finally {
      if (mounted) {
        playbackController.setAudioLoading(false);
      }
    }
  }

  Future<void> _playNext() async {
    final queue = playbackController.queueOr(songs);
    final next = playbackController.nextSong(queue, wrap: true);
    if (next == null) {
      return;
    }
    await _selectSongWithFallback(next, queue: queue, wrap: true);
  }

  Future<void> _playPrevious() async {
    final queue = playbackController.queueOr(songs);
    final previous = playbackController.previousSong(queue);
    if (previous == null) {
      return;
    }
    await _selectSongWithFallback(previous, queue: queue, wrap: true);
  }

  Future<void> _handlePlaybackComplete() async {
    audioController.markCompleted();
    if (!mounted) {
      return;
    }
    playbackController.markCompleted();
    final queue = playbackController.queueOr(songs);
    if (playbackController.shouldStopAtQueueEnd(queue)) {
      return;
    }
    final next = playbackController.nextSong(
      queue,
      wrap: playbackMode != PlaybackMode.sequential,
    );
    if (next == null) {
      return;
    }
    await _selectSongWithFallback(
      next,
      queue: queue,
      wrap: playbackMode != PlaybackMode.sequential,
    );
  }

  void _cyclePlaybackMode() {
    playbackController.cyclePlaybackMode();
    _schedulePlaybackStateSave();
  }

  @override
  void dispose() {
    musicFlowRouteObserver.unsubscribe(this);
    libraryController.removeListener(_handleLibraryChanged);
    playbackController.removeListener(_handlePlaybackChanged);
    appLoading.removeListener(_handleLoadingChanged);
    requestLoading.removeListener(_handleLoadingChanged);
    _playbackSaveTimer?.cancel();
    _updateTimer?.cancel();
    unawaited(_savePlaybackStateNow());
    _completionSubscription.cancel();
    _positionSubscription.cancel();
    audioController.dispose();
    playbackController.dispose();
    appLoading.dispose();
    requestLoading.dispose();
    super.dispose();
  }
}

class _UpdateDiscoverDialog extends StatelessWidget {
  const _UpdateDiscoverDialog({
    required this.info,
    required this.onDownload,
    required this.onLater,
  });

  final AppUpdateInfo info;
  final VoidCallback onDownload;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final notes = info.releaseNotes.trim();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: cardDecoration(radius: 24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                color: const Color(0xFFEAF8FC),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.system_update_alt_rounded,
                            color: kAccentDark,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '发现新版本',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'v${info.currentVersion}  ->  v${info.version}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (info.mandatory) ...[
                      const SizedBox(height: 12),
                      Text(
                        '这是一次必要更新',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: kAccentDark),
                      ),
                    ],
                  ],
                ),
              ),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 170),
                    child: SingleChildScrollView(
                      child: Text(
                        notes,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: kMuted,
                          height: 1.58,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Row(
                  children: [
                    if (onLater != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onLater,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kMuted,
                            side: const BorderSide(color: kLine),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('稍后'),
                        ),
                      ),
                    if (onLater != null) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: onDownload,
                        style: FilledButton.styleFrom(
                          backgroundColor: kAccentDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('后台下载'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateStatusBanner extends StatelessWidget {
  const _UpdateStatusBanner({
    required this.isMobile,
    required this.icon,
    required this.title,
    required this.message,
    this.progress,
    this.actionText,
    this.onAction,
    this.onClose,
    this.destructive = false,
  });

  final bool isMobile;
  final IconData icon;
  final String title;
  final String message;
  final double? progress;
  final String? actionText;
  final VoidCallback? onAction;
  final VoidCallback? onClose;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFE15B5B) : kAccentDark;
    return Align(
      alignment: isMobile ? Alignment.topCenter : Alignment.topRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 360),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: .16)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .13),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, size: 19, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(color: kInk),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      if (actionText != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: FilledButton(
                            onPressed: onAction,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(64, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(actionText!),
                          ),
                        ),
                      if (onClose != null)
                        IconButton(
                          tooltip: '关闭',
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                          color: kMuted,
                          iconSize: 18,
                        ),
                    ],
                  ),
                ),
                if (progress != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0, 1).toDouble(),
                      minHeight: 3,
                      backgroundColor: color.withValues(alpha: .08),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteSongConfirmOverlay extends StatefulWidget {
  const _DeleteSongConfirmOverlay({
    required this.song,
    required this.onCompleted,
  });

  final Song song;
  final ValueChanged<bool> onCompleted;

  @override
  State<_DeleteSongConfirmOverlay> createState() =>
      _DeleteSongConfirmOverlayState();
}

class _DeleteSongConfirmOverlayState extends State<_DeleteSongConfirmOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> barrierFade;
  late final Animation<double> dialogFade;
  late final Animation<double> dialogMotion;
  bool closing = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 90),
    );
    barrierFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, .55, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    dialogFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(.04, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    dialogMotion = CurvedAnimation(
      parent: controller,
      curve: const Interval(.04, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _close(bool confirmed) async {
    if (closing) {
      return;
    }
    closing = true;
    await controller.reverse();
    if (mounted) {
      widget.onCompleted(confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: barrierFade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _close(false),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: kInk.withValues(alpha: .32)),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: dialogFade,
              child: AnimatedBuilder(
                animation: dialogMotion,
                builder: (context, child) {
                  final value = dialogMotion.value;
                  return Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: Transform.scale(
                      scale: .985 + value * .015,
                      child: child,
                    ),
                  );
                },
                child: RepaintBoundary(
                  child: _DeleteSongDialogCard(
                    song: widget.song,
                    onCancel: () => _close(false),
                    onConfirm: () => _close(true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteSongDialogCard extends StatelessWidget {
  const _DeleteSongDialogCard({
    required this.song,
    required this.onCancel,
    required this.onConfirm,
  });

  final Song song;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: kLine),
            boxShadow: [
              BoxShadow(
                color: kInk.withValues(alpha: .10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE15B5B).withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE15B5B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '删除歌曲',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '确定要删除《${song.title}》吗？本地音频文件也会一起移除，之后可以重新下载。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: kMuted, height: 1.55),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE15B5B),
                        ),
                        onPressed: onConfirm,
                        child: const Text('删除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletePlaylistConfirmOverlay extends StatefulWidget {
  const _DeletePlaylistConfirmOverlay({
    required this.playlist,
    required this.onCompleted,
  });

  final Playlist playlist;
  final ValueChanged<bool> onCompleted;

  @override
  State<_DeletePlaylistConfirmOverlay> createState() =>
      _DeletePlaylistConfirmOverlayState();
}

class _DeletePlaylistConfirmOverlayState
    extends State<_DeletePlaylistConfirmOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> barrierFade;
  late final Animation<double> dialogFade;
  late final Animation<double> dialogMotion;
  bool closing = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 90),
    );
    barrierFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, .55, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    dialogFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(.04, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    dialogMotion = CurvedAnimation(
      parent: controller,
      curve: const Interval(.04, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _close(bool confirmed) async {
    if (closing) {
      return;
    }
    closing = true;
    await controller.reverse();
    if (mounted) {
      widget.onCompleted(confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: barrierFade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _close(false),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: kInk.withValues(alpha: .32)),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: dialogFade,
              child: AnimatedBuilder(
                animation: dialogMotion,
                builder: (context, child) {
                  final value = dialogMotion.value;
                  return Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: Transform.scale(
                      scale: .985 + value * .015,
                      child: child,
                    ),
                  );
                },
                child: RepaintBoundary(
                  child: _DeletePlaylistDialogCard(
                    playlist: widget.playlist,
                    onCancel: () => _close(false),
                    onConfirm: () => _close(true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletePlaylistDialogCard extends StatelessWidget {
  const _DeletePlaylistDialogCard({
    required this.playlist,
    required this.onCancel,
    required this.onConfirm,
  });

  final Playlist playlist;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: kLine),
            boxShadow: [
              BoxShadow(
                color: kInk.withValues(alpha: .10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE15B5B).withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE15B5B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '删除歌单',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '确定要删除歌单「${playlist.name}」吗？歌曲不会被删除，只会移除此歌单。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: kMuted, height: 1.55),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE15B5B),
                        ),
                        onPressed: onConfirm,
                        child: const Text('删除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _AddToPlaylistChoice {
  const _AddToPlaylistChoice.existing(this.playlist)
    : name = '',
      description = '';

  const _AddToPlaylistChoice.create({
    required this.name,
    required this.description,
  }) : playlist = null;

  final Playlist? playlist;
  final String name;
  final String description;
}

class _AddToPlaylistOverlay extends StatefulWidget {
  const _AddToPlaylistOverlay({
    required this.song,
    required this.playlists,
    required this.onCompleted,
  });

  final Song song;
  final List<Playlist> playlists;
  final ValueChanged<_AddToPlaylistChoice?> onCompleted;

  @override
  State<_AddToPlaylistOverlay> createState() => _AddToPlaylistOverlayState();
}

class _AddToPlaylistOverlayState extends State<_AddToPlaylistOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> barrierFade;
  late final Animation<double> dialogFade;
  late final Animation<double> dialogMotion;
  bool closing = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 90),
    );
    barrierFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, .55, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    dialogFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(.04, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    dialogMotion = CurvedAnimation(
      parent: controller,
      curve: const Interval(.04, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _close(_AddToPlaylistChoice? choice) async {
    if (closing) {
      return;
    }
    closing = true;
    await controller.reverse();
    if (mounted) {
      widget.onCompleted(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: barrierFade,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _close(null),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: kInk.withValues(alpha: .32)),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: dialogFade,
              child: AnimatedBuilder(
                animation: dialogMotion,
                builder: (context, child) {
                  final value = dialogMotion.value;
                  return Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: Transform.scale(
                      scale: .985 + value * .015,
                      child: child,
                    ),
                  );
                },
                child: RepaintBoundary(
                  child: _AddToPlaylistCard(
                    song: widget.song,
                    playlists: widget.playlists,
                    onSelected: _close,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddToPlaylistCard extends StatefulWidget {
  const _AddToPlaylistCard({
    required this.song,
    required this.playlists,
    required this.onSelected,
  });

  final Song song;
  final List<Playlist> playlists;
  final ValueChanged<_AddToPlaylistChoice?> onSelected;

  @override
  State<_AddToPlaylistCard> createState() => _AddToPlaylistCardState();
}

class _AddToPlaylistCardState extends State<_AddToPlaylistCard> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  bool creating = false;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _submitCreate() {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    if (name.isEmpty) {
      setState(() => errorMessage = '请输入歌单名称');
      return;
    }
    widget.onSelected(
      _AddToPlaylistChoice.create(name: name, description: description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxCardHeight = viewportHeight < 420
        ? viewportHeight - 24
        : viewportHeight < 620
        ? viewportHeight - 48
        : 560.0;
    final playlistCount = widget.playlists.length;
    final visiblePlaylistRows = playlistCount == 0
        ? 1
        : playlistCount > 4
        ? 4
        : playlistCount;
    final playlistRowsHeight = playlistCount == 0
        ? 96.0
        : visiblePlaylistRows * 76.0 + (visiblePlaylistRows - 1) * 8.0;
    final desiredListCardHeight =
        44.0 + 18.0 + 62.0 + 12.0 + playlistRowsHeight + 18.0 + 50.0 + 44.0;
    final desiredCreateCardHeight =
        44.0 + 18.0 + 38.0 + 22.0 + 62.0 + 12.0 + 116.0 + 18.0 + 50.0 + 44.0;
    final minListCardHeight = maxCardHeight < 360 ? maxCardHeight : 360.0;
    final desiredCardHeight = desiredListCardHeight > desiredCreateCardHeight
        ? desiredListCardHeight
        : desiredCreateCardHeight;
    final listCardHeight = desiredCardHeight
        .clamp(minListCardHeight, maxCardHeight)
        .toDouble();
    final cardHeight = listCardHeight;
    final sortedPlaylists = List<Playlist>.of(widget.playlists)
      ..sort((a, b) => a.name.compareTo(b.name));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, minWidth: 320),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: cardHeight,
            child: DecoratedBox(
              decoration: cardDecoration(radius: 26),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF8FC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.playlist_add_rounded,
                            color: kAccentDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('添加到歌单', style: textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(
                                widget.song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 140),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: [...previousChildren, ?currentChild],
                          );
                        },
                        child: creating
                            ? SingleChildScrollView(
                                key: const ValueKey('create-playlist'),
                                child: _AddToPlaylistCreateForm(
                                  nameController: nameController,
                                  descriptionController: descriptionController,
                                  errorMessage: errorMessage,
                                  onBack: () {
                                    setState(() {
                                      creating = false;
                                      errorMessage = null;
                                    });
                                  },
                                  onSubmit: _submitCreate,
                                ),
                              )
                            : Column(
                                key: const ValueKey('playlist-list'),
                                children: [
                                  _AddToPlaylistCreateButton(
                                    onTap: () =>
                                        setState(() => creating = true),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: sortedPlaylists.isEmpty
                                        ? EmptyState(
                                            icon: Icons.queue_music_rounded,
                                            message: '还没有歌单，先新建一个吧',
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 18,
                                            ),
                                          )
                                        : ListView.separated(
                                            itemCount: sortedPlaylists.length,
                                            separatorBuilder: (_, _) =>
                                                const SizedBox(height: 8),
                                            itemBuilder: (context, index) {
                                              final playlist =
                                                  sortedPlaylists[index];
                                              final alreadyAdded = playlist
                                                  .songs
                                                  .any(
                                                    (item) =>
                                                        item.id ==
                                                        widget.song.id,
                                                  );
                                              return _AddToPlaylistRow(
                                                playlist: playlist,
                                                alreadyAdded: alreadyAdded,
                                                onTap: () => widget.onSelected(
                                                  _AddToPlaylistChoice.existing(
                                                    playlist,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => widget.onSelected(null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kInk,
                          side: const BorderSide(color: kLine),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddToPlaylistCreateButton extends StatelessWidget {
  const _AddToPlaylistCreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kAccent.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: kAccentDark,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '新建歌单并添加',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: kInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '创建后自动加入当前歌曲',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kAccentDark),
          ],
        ),
      ),
    );
  }
}

class _AddToPlaylistCreateForm extends StatelessWidget {
  const _AddToPlaylistCreateForm({
    required this.nameController,
    required this.descriptionController,
    required this.onBack,
    required this.onSubmit,
    this.errorMessage,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: kLine.withValues(alpha: .82)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: kAccentDark, width: 1.4),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onBack,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F8FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kLine.withValues(alpha: .72)),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: kMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '创建新歌单',
                    style: textTheme.titleMedium?.copyWith(
                      color: kInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '保存后会立即加入当前歌曲',
                    style: textTheme.bodyMedium?.copyWith(color: kMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        TextField(
          controller: nameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          style: textTheme.titleSmall?.copyWith(
            color: kInk,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            labelText: '歌单名称',
            hintText: '例如：冷雨夜',
            prefixIcon: const Icon(Icons.album_outlined, color: kMuted),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedBorder,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          minLines: 3,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          style: textTheme.bodyLarge?.copyWith(color: kInk),
          decoration: InputDecoration(
            labelText: '描述',
            hintText: '写下这张歌单的氛围',
            alignLabelWithHint: true,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(Icons.notes_rounded, color: kMuted),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedBorder,
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFE15B5B).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFE15B5B),
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE15B5B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kInk,
                  side: BorderSide(color: kLine.withValues(alpha: .9)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: const Text('返回列表'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: kAccentDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('创建并添加'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddToPlaylistRow extends StatelessWidget {
  const _AddToPlaylistRow({
    required this.playlist,
    required this.alreadyAdded,
    required this.onTap,
  });

  final Playlist playlist;
  final bool alreadyAdded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: alreadyAdded
              ? kAccent.withValues(alpha: 0.07)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: alreadyAdded ? kAccent.withValues(alpha: 0.22) : kLine,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: playlist.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(playlist.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: kInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.songCount} 首歌曲',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (alreadyAdded)
              const Icon(
                Icons.check_circle_rounded,
                color: kAccentDark,
                size: 20,
              )
            else
              const Icon(Icons.chevron_right_rounded, color: kMuted),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: kMuted),
            const SizedBox(height: 12),
            Text('后端接口连接失败', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}
