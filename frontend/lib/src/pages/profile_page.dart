import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../delayed_loading.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/artwork.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.isMobile,
    required this.overview,
    required this.onOpenFavoriteMusic,
    required this.onOpenRecentPlays,
    required this.onOpenDownloadManagement,
    required this.onLogin,
    required this.onLogout,
  });

  final bool isMobile;
  final ProfileOverview? overview;
  final VoidCallback onOpenFavoriteMusic;
  final VoidCallback onOpenRecentPlays;
  final VoidCallback onOpenDownloadManagement;
  final Future<void> Function(String username, String password) onLogin;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final data = overview;
    if (data == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = isMobile ? 16.0 : 24.0;
          final verticalPadding = isMobile ? 16.0 : 24.0;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - verticalPadding * 2).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: _LoginCard(onLogin: onLogin),
                ),
              ),
            ),
          );
        },
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 18 : 24,
        isMobile ? 20 : 24,
        isMobile ? 18 : 24,
        24,
      ),
      children: [
        _ProfileHero(isMobile: isMobile, user: data.user),
        const SizedBox(height: 14),
        if (isMobile)
          _QuickGrid(
            onOpenFavoriteMusic: onOpenFavoriteMusic,
            onOpenRecentPlays: onOpenRecentPlays,
            onOpenDownloadManagement: onOpenDownloadManagement,
          )
        else
          _VipBanner(user: data.user),
        const SizedBox(height: 16),
        if (isMobile) ...[
          _FavoritesCard(
            songs: data.favorites,
            onActionTap: onOpenFavoriteMusic,
          ),
          const SizedBox(height: 14),
          _DownloadsCard(
            tasks: data.downloads,
            onActionTap: onOpenDownloadManagement,
          ),
        ] else
          _DesktopCards(
            overview: data,
            onLogout: onLogout,
            onOpenFavoriteMusic: onOpenFavoriteMusic,
            onOpenRecentPlays: onOpenRecentPlays,
            onOpenDownloadManagement: onOpenDownloadManagement,
          ),
      ],
    );
  }
}

class _LoginCard extends StatefulWidget {
  const _LoginCard({required this.onLogin});

  final Future<void> Function(String username, String password) onLogin;

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameFocusNode = FocusNode(debugLabel: 'login-username');
  final passwordFocusNode = FocusNode(debugLabel: 'login-password');
  final loginButtonFocusNode = FocusNode(debugLabel: 'login-submit');
  final DelayedLoadingController loginLoading = DelayedLoadingController();
  bool obscurePassword = true;
  String? errorMessage;

  bool get loading => loginLoading.active;

  @override
  void dispose() {
    loginLoading.dispose();
    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    loginButtonFocusNode.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loginLoading.addListener(_handleLoadingChanged);
  }

  void _handleLoadingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 820;
        final compact = constraints.maxWidth < 620;
        final intro = _LoginHeroPanel(compact: !split);
        final form = _buildForm(context, compact: compact);
        final card = Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 24 : 32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0C5FA4).withValues(alpha: .10),
                blurRadius: 48,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: !split
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, form],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 9, child: intro),
                      Expanded(flex: 11, child: form),
                    ],
                  ),
                ),
        );
        return card;
      },
    );
  }

  Widget _buildForm(BuildContext context, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 28,
        compact ? 24 : 32,
        compact ? 20 : 28,
        compact ? 24 : 32,
      ),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.tab, shift: true):
                PreviousFocusIntent(),
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '账号登录',
                style: TextStyle(
                  color: kInk,
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '使用数据库账号进入你的音乐空间',
                style: TextStyle(color: kMuted, fontSize: 13, height: 1.4),
              ),
              SizedBox(height: compact ? 20 : 26),
              _FormLabel(text: '用户名'),
              const SizedBox(height: 6),
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: TextField(
                  controller: usernameController,
                  focusNode: usernameFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onEditingComplete: () => passwordFocusNode.requestFocus(),
                  decoration: _inputDecoration(
                    context,
                    hint: '请输入用户名',
                    icon: Icons.person_rounded,
                  ),
                ),
              ),
              SizedBox(height: compact ? 12 : 16),
              _FormLabel(text: '密码'),
              const SizedBox(height: 6),
              FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: TextField(
                  controller: passwordController,
                  focusNode: passwordFocusNode,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!loading) {
                      _submit();
                    }
                  },
                  decoration: _inputDecoration(
                    context,
                    hint: '请输入密码',
                    icon: Icons.lock_rounded,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: kMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: .22),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: compact ? 20 : 24),
              FocusTraversalOrder(
                order: const NumericFocusOrder(3),
                child: SizedBox(
                  width: double.infinity,
                  height: compact ? 50 : 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: loginLoading.active
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF18B9E6), Color(0xFF6C5CE7)],
                            ),
                      color: loginLoading.active
                          ? const Color(0xFFE4E8EC)
                          : null,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: loginLoading.active
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(
                                  0xFF18B9E6,
                                ).withValues(alpha: .36),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        focusNode: loginButtonFocusNode,
                        borderRadius: BorderRadius.circular(18),
                        onTap: loginLoading.active ? null : _submit,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (loginLoading.visible)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.login_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              const SizedBox(width: 10),
                              Text(
                                loginLoading.visible ? '登录中…' : '登录',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '所有数据都来自你本地的 MySQL，不会上传第三方。',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: kMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, color: kAccent, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF6F8FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE3E8EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kAccent, width: 1.6),
      ),
      hintStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFAAB3BE)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    );
  }

  Future<void> _submit() async {
    loginLoading.start();
    setState(() => errorMessage = null);
    try {
      await widget.onLogin(
        usernameController.text.trim(),
        passwordController.text,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => errorMessage = error.toString());
    } finally {
      loginLoading.stop();
    }
  }
}

class _LoginHeroPanel extends StatelessWidget {
  const _LoginHeroPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0EA5E9), Color(0xFF4F7DFF)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'MusicFlow',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '登录后同步收藏、下载与最近播放',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .82),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(32, 36, 32, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0EA5E9), Color(0xFF4F7DFF), Color(0xFF7C5CFF)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: 20,
            top: 24,
            child: Icon(
              Icons.music_note_rounded,
              color: Colors.white.withValues(alpha: .16),
              size: 64,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'MusicFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 32 : 44),
              const Text(
                '欢迎回来',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '登录后同步你的收藏、下载与最近播放',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              SizedBox(height: compact ? 24 : 32),
              const _LoginFeatureItem(
                icon: Icons.favorite_rounded,
                label: '真实收藏',
              ),
              const SizedBox(height: 14),
              const _LoginFeatureItem(
                icon: Icons.history_rounded,
                label: '最近播放',
              ),
              const SizedBox(height: 14),
              const _LoginFeatureItem(
                icon: Icons.cloud_done_rounded,
                label: '下载同步',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginFeatureItem extends StatelessWidget {
  const _LoginFeatureItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: .9), size: 16),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .92),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: kInk,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.isMobile, required this.user});

  final bool isMobile;
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final name = user.name.isEmpty ? user.username : user.name;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactDesktop = !isMobile && constraints.maxWidth < 1040;
        final showChevron = isMobile || constraints.maxWidth >= 1080;
        final avatarSize = isMobile ? 72.0 : (compactDesktop ? 68.0 : 84.0);
        final avatarPadding = compactDesktop ? 3.0 : 4.0;
        final avatarIconSize = isMobile ? 34.0 : (compactDesktop ? 28.0 : 34.0);
        final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: isMobile ? 20 : (compactDesktop ? 21 : 22),
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.12,
        );

        return Container(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 18 : 24,
            isMobile ? 18 : 20,
            isMobile ? 18 : 24,
            isMobile ? 18 : 20,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF6FCFE)],
            ),
            border: Border.all(color: const Color(0xFFDDEFF4)),
            boxShadow: [
              BoxShadow(
                color: kAccent.withValues(alpha: .075),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    padding: EdgeInsets.all(avatarPadding),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB9DCE8), Color(0xFF6CAFC0)],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF9CC0D0),
                      backgroundImage: user.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(user.avatarUrl),
                      child: user.avatarUrl.isEmpty
                          ? Icon(
                              Icons.landscape_rounded,
                              color: Colors.white,
                              size: avatarIconSize,
                            )
                          : null,
                    ),
                  ),
                  SizedBox(width: compactDesktop ? 14 : 20),
                  Expanded(
                    flex: compactDesktop ? 5 : 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                            if (user.vip)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: kAccent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'VIP',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ID: ${user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: kMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '真实账号数据 · 本地音乐空间已连接',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(height: 1.28),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    SizedBox(width: compactDesktop ? 16 : 24),
                    _ProfileMetricGroup(
                      favoriteCount: user.favoriteCount,
                      playlistCount: user.playlistCount,
                      recentCount: user.recentCount,
                      compact: compactDesktop,
                    ),
                  ],
                  if (showChevron) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: kLine),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: kMuted,
                      ),
                    ),
                  ],
                ],
              ),
              if (isMobile) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileMetric(
                        value: '${user.favoriteCount}',
                        label: '收藏',
                        icon: Icons.favorite_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileMetric(
                        value: '${user.playlistCount}',
                        label: '歌单',
                        icon: Icons.queue_music_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileMetric(
                        value: '${user.recentCount}',
                        label: '最近',
                        icon: Icons.history_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProfileMetricGroup extends StatelessWidget {
  const _ProfileMetricGroup({
    required this.favoriteCount,
    required this.playlistCount,
    required this.recentCount,
    this.compact = false,
  });

  final int favoriteCount;
  final int playlistCount;
  final int recentCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileMetricSegment(
            value: '$favoriteCount',
            label: '收藏歌曲',
            icon: Icons.favorite_rounded,
            compact: compact,
          ),
          const _ProfileMetricDivider(),
          _ProfileMetricSegment(
            value: '$playlistCount',
            label: '歌单',
            icon: Icons.queue_music_rounded,
            compact: compact,
          ),
          const _ProfileMetricDivider(),
          _ProfileMetricSegment(
            value: '$recentCount',
            label: '最近播放',
            icon: Icons.history_rounded,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _ProfileMetricDivider extends StatelessWidget {
  const _ProfileMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: kLine);
  }
}

class _ProfileMetricSegment extends StatelessWidget {
  const _ProfileMetricSegment({
    required this.value,
    required this.label,
    required this.icon,
    this.compact = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 74 : 86,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: kAccentDark),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .76)),
        boxShadow: [
          BoxShadow(
            color: kInk.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: kAccentDark),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _VipBanner extends StatelessWidget {
  const _VipBanner({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final title = user.vip ? 'VIP 会员' : '普通会员';
    final subtitle = user.vip ? '高品质音乐 · 专属音效 · 无限下载' : '登录账号已接入真实数据';
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7E6), Color(0xFFFFEAC2)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE1A3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC98E25).withValues(alpha: .10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFC98E25).withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.diamond_rounded,
              color: Color(0xFFC98E25),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF9A6712),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFB17B1F),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_formatStorage(user.storageLimitMb)} 空间 >',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF9A6712),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({
    required this.onOpenFavoriteMusic,
    required this.onOpenRecentPlays,
    required this.onOpenDownloadManagement,
  });

  final VoidCallback onOpenFavoriteMusic;
  final VoidCallback onOpenRecentPlays;
  final VoidCallback onOpenDownloadManagement;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.favorite_rounded, '我的收藏', true),
      (Icons.history_rounded, '最近播放', true),
      (Icons.download_rounded, '下载管理', true),
      (Icons.color_lens_rounded, '主题设置', false),
      (Icons.schedule_rounded, '定时关闭', false),
      (Icons.tune_rounded, '音质设置', false),
      (Icons.security_rounded, '账号安全', false),
      (Icons.more_horiz_rounded, '更多', false),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: cardDecoration(radius: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        childAspectRatio: 1.15,
        children: [
          for (var i = 0; i < items.length; i++)
            InkWell(
              onTap: items[i].$3 ? () => _selectQuickItem(i) : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(items[i].$1, color: items[i].$3 ? kAccent : kMuted),
                  const SizedBox(height: 6),
                  Text(
                    items[i].$2,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: items[i].$3 ? kInk : kMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _selectQuickItem(int index) {
    if (index == 0) {
      onOpenFavoriteMusic();
    } else if (index == 1) {
      onOpenRecentPlays();
    } else if (index == 2) {
      onOpenDownloadManagement();
    }
  }
}

class _DesktopCards extends StatelessWidget {
  const _DesktopCards({
    required this.overview,
    required this.onLogout,
    required this.onOpenFavoriteMusic,
    required this.onOpenRecentPlays,
    required this.onOpenDownloadManagement,
  });

  final ProfileOverview overview;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenFavoriteMusic;
  final VoidCallback onOpenRecentPlays;
  final VoidCallback onOpenDownloadManagement;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 980 ? 3 : 2;
        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final cards = [
          _FavoritesCard(
            songs: overview.favorites,
            onActionTap: onOpenFavoriteMusic,
          ),
          _RecentCard(items: overview.recent, onActionTap: onOpenRecentPlays),
          _DownloadsCard(
            tasks: overview.downloads,
            onActionTap: onOpenDownloadManagement,
          ),
          _StorageCard(user: overview.user),
          _ThemeCard(),
          _SecurityCard(onLogout: onLogout),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _FavoritesCard extends StatelessWidget {
  const _FavoritesCard({required this.songs, required this.onActionTap});

  final List<Song> songs;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '我的收藏',
      icon: Icons.favorite_rounded,
      action: '查看全部 >',
      onActionTap: onActionTap,
      child: songs.isEmpty
          ? const _ProfileEmptyState(
              icon: Icons.favorite_border_rounded,
              message: '暂无收藏歌曲',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final song in songs)
                  _ProfileSongRow(
                    song: song,
                    trailing: Text(formatDuration(song.duration)),
                  ),
              ],
            ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.items, required this.onActionTap});

  final List<PlayHistoryItem> items;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '最近播放',
      icon: Icons.history_rounded,
      action: '查看全部 >',
      onActionTap: onActionTap,
      child: items.isEmpty
          ? const _ProfileEmptyState(
              icon: Icons.history_rounded,
              message: '暂无最近播放',
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  _RecentSongRow(
                    item: items[index],
                    isLast: index == items.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _DownloadsCard extends StatelessWidget {
  const _DownloadsCard({required this.tasks, this.onActionTap});

  final List<DownloadTask> tasks;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(3).toList();
    return _Panel(
      title: '下载管理',
      icon: Icons.download_done_rounded,
      action: onActionTap == null ? '' : '查看全部 >',
      onActionTap: onActionTap,
      child: tasks.isEmpty
          ? const _ProfileEmptyState(
              icon: Icons.download_rounded,
              message: '暂无下载歌曲',
            )
          : Column(
              children: [
                for (var index = 0; index < visibleTasks.length; index++)
                  _DownloadTaskMiniRow(
                    task: visibleTasks[index],
                    isLast: index == visibleTasks.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final limit = user.storageLimitMb <= 0 ? 1 : user.storageLimitMb;
    final progress = (user.storageUsedMb / limit).clamp(0.0, 1.0);
    return _Panel(
      title: '存储空间',
      icon: Icons.cloud_rounded,
      action: '${(progress * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已使用 ${_formatStorage(user.storageUsedMb)} / ${_formatStorage(user.storageLimitMb)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 14),
          Text(
            '音乐 ${_formatStorage(user.storageUsedMb)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '主题设置',
      icon: Icons.color_lens_rounded,
      action: '',
      child: Row(
        children: [
          Container(
            width: 58,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAccent, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 58,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2B3D),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 58,
            height: 86,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE3C8), Color(0xFF9CC7D1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return _Panel(
      title: '账号与安全',
      icon: Icons.security_rounded,
      action: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kAccent.withValues(alpha: .10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .84),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: kAccentDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '账号安全',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: kInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '本地账号已保护',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已保护',
                    style: textTheme.labelMedium?.copyWith(
                      color: kAccentDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          const _VersionInfoTile(),
          const SizedBox(height: 7),
          InkWell(
            onTap: () => _confirmLogout(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: .10),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .68),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: colorScheme.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '退出登录',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.error.withValues(alpha: .72),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: kInk.withValues(alpha: .32),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color.lerp(Colors.white, kAccent, .035)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: .86)),
                boxShadow: [
                  BoxShadow(
                    color: kInk.withValues(alpha: .08),
                    blurRadius: 42,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: .12),
                          ),
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          color: colorScheme.error.withValues(alpha: .86),
                          size: 21,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        color: kMuted,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .72),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '退出当前账号？',
                    style: textTheme.headlineSmall?.copyWith(
                      color: kInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '你将回到未登录状态，个人资料、收藏和播放记录需要重新登录后才能查看。',
                    style: textTheme.bodyMedium?.copyWith(
                      color: kMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kLine.withValues(alpha: .72)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.library_music_rounded,
                          color: kAccentDark,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '本地音乐和已下载内容不会被删除',
                            style: textTheme.labelMedium?.copyWith(
                              color: kInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            backgroundColor: Colors.white,
                            foregroundColor: kInk,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: kLine),
                            ),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            foregroundColor: colorScheme.error,
                            side: BorderSide(
                              color: colorScheme.error.withValues(alpha: .22),
                            ),
                            backgroundColor: colorScheme.error.withValues(
                              alpha: .06,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('退出登录'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmed == true) {
      await onLogout();
    }
  }
}

class _VersionInfoTile extends StatelessWidget {
  const _VersionInfoTile();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final versionText = info == null
            ? '读取中'
            : 'v${info.version}+${info.buildNumber}';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kLine.withValues(alpha: .82)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .76),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: kMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '当前版本',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: kInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                versionText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: kMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: kAccentDark, size: 20),
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ProfileSongRow extends StatelessWidget {
  const _ProfileSongRow({required this.song, required this.trailing});

  final Song song;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Artwork(song: song, size: 36, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: kInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 58,
            child: Align(
              alignment: Alignment.centerRight,
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: textTheme.labelMedium?.copyWith(
                  color: kMuted,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: trailing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSongRow extends StatelessWidget {
  const _RecentSongRow({required this.item, required this.isLast});

  final PlayHistoryItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final song = item.song;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Artwork(song: song, size: 34, radius: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: kInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 82,
            child: Text(
              item.playedAt.millisecondsSinceEpoch == 0
                  ? '最近听过'
                  : formatRelativeTime(item.playedAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: kMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTaskMiniRow extends StatelessWidget {
  const _DownloadTaskMiniRow({required this.task, required this.isLast});

  final DownloadTask task;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
      child: Row(
        children: [
          Artwork(song: task.song, size: 32, radius: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF273746),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: task.progress,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF68CFE1),
                    ),
                    backgroundColor: const Color(0xFFEAF7FA),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: SizedBox(
              width: 42,
              child: Text(
                '${(task.progress * 100).round()}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF93A1AE),
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.action,
    required this.child,
    this.onActionTap,
  });

  final String title;
  final IconData icon;
  final String action;
  final Widget child;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EEF3)),
        boxShadow: [
          BoxShadow(
            color: kInk.withValues(alpha: .045),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kAccent.withValues(alpha: .08)),
                  ),
                  child: Icon(icon, size: 17, color: kAccentDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (action.isNotEmpty)
                  _PanelAction(label: action, onTap: onActionTap),
              ],
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasArrow = label.trimRight().endsWith('>');
    final normalizedLabel = hasArrow
        ? label
              .trimRight()
              .substring(0, label.trimRight().length - 1)
              .trimRight()
        : label;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          normalizedLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (hasArrow) ...[
          const SizedBox(width: 3),
          const Icon(Icons.chevron_right_rounded, size: 16, color: kMuted),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

String _formatStorage(int mb) {
  if (mb >= 1024) {
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 10 ? 0 : 1)} GB';
  }
  return '$mb MB';
}
