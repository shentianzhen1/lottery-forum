import 'dart:async';

import 'package:flutter/material.dart';

import '../api/forum_api.dart';
import '../design/app_theme.dart';
import 'forum_ui.dart';
import 'home_feed.dart';
import 'play_betting.dart';
import 'points_reader.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.landscapeReady,
    this.loggedIn = false,
    this.reader = const DisconnectedPointsReader(),
    this.feed = const EmptyHomeFeed(),
    this.forumApi,
    this.onGoToAccount,
    this.onGoToModerator,
    this.onOpenPlay,
    super.key,
  });

  final bool landscapeReady;
  final bool loggedIn;
  final PointsReader reader;
  final HomeFeed feed;
  final ForumApi? forumApi;
  final VoidCallback? onGoToAccount;
  final VoidCallback? onGoToModerator;
  final ValueChanged<PlayKind>? onOpenPlay;

  static const games = <_HomeGameEntry>[
    _HomeGameEntry(
      kind: PlayKind.fujian31,
      title: '福建31',
      subtitle: '任选2–5与选7',
      keyName: 'home-game-fujian-31',
      badge: '31',
      status: '已开放',
      accent: Color(0xFF83C9BC),
    ),
    _HomeGameEntry(
      kind: PlayKind.numberPick,
      title: '数字选号',
      subtitle: '选择3个不重复数字',
      keyName: 'home-game-number-pick',
      badge: '3',
      status: '已开放',
      accent: Color(0xFFE3C58C),
    ),
    _HomeGameEntry(
      title: '排列三',
      subtitle: '彩种目录已加入',
      keyName: 'home-game-pailie-3',
      badge: 'P3',
      status: '筹备中',
      accent: Color(0xFF9D8AC7),
    ),
    _HomeGameEntry(
      title: '快乐8',
      subtitle: '彩种目录已加入',
      keyName: 'home-game-kuaile-8',
      badge: '8+',
      status: '筹备中',
      accent: Color(0xFF73B2E8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!landscapeReady) return const _NarrowNotice();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        final sideWidth = compact ? 248.0 : 288.0;
        final outerPadding = compact ? 18.0 : 24.0;
        final gap = compact ? 14.0 : 20.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            outerPadding,
            compact ? 16 : 20,
            outerPadding,
            outerPadding,
          ),
          child: Row(
            key: const Key('home-landscape-columns'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MainColumn(
                  feed: feed,
                  compact: compact,
                  forumApi: forumApi,
                  loggedIn: loggedIn,
                  onGoToAccount: onGoToAccount,
                  onOpenPlay: onOpenPlay,
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: sideWidth,
                child: _SidePanel(
                  loggedIn: loggedIn,
                  reader: reader,
                  onGoToAccount: onGoToAccount,
                  onGoToModerator: onGoToModerator,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MainColumn extends StatefulWidget {
  const _MainColumn({
    required this.feed,
    required this.compact,
    required this.forumApi,
    required this.loggedIn,
    this.onGoToAccount,
    this.onOpenPlay,
  });

  final HomeFeed feed;
  final bool compact;
  final ForumApi? forumApi;
  final bool loggedIn;
  final VoidCallback? onGoToAccount;
  final ValueChanged<PlayKind>? onOpenPlay;

  @override
  State<_MainColumn> createState() => _MainColumnState();
}

class _MainColumnState extends State<_MainColumn> {
  HomeFeedData? _data;
  Object? _error;
  int _forumRevision = 0;

  Future<void> _createThread() async {
    if (!widget.loggedIn) {
      widget.onGoToAccount?.call();
      return;
    }
    final created = await showCreateThreadDialog(context, widget.forumApi!);
    if (created && mounted) setState(() => _forumRevision++);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MainColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feed != oldWidget.feed) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await widget.feed.load();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _data = const HomeFeedData(banners: [], announcements: []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final banners = data?.banners ?? const <HomeBanner>[];
    final announcements = data?.announcements ?? const <HomeAnnouncement>[];
    final recentDraws = data?.recentDraws ?? const <HomeRecentDraw>[];
    final loading = data == null && _error == null;

    return ListView(
      key: const Key('home-main-scroll'),
      padding: EdgeInsets.zero,
      children: [
        if (widget.forumApi != null) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('home-forum-search'),
                  onPressed: () => showForumSearchDialog(context, widget.forumApi!),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('搜索帖子、话题或关键词'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const Key('home-forum-publish'),
                onPressed: _createThread,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(widget.loggedIn ? '发布帖子' : '登录后发帖'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ForumOverview(
            key: ValueKey('home-forum-$_forumRevision'),
            api: widget.forumApi!,
            loggedIn: widget.loggedIn,
            onOpenBoard: (id) => showForumSearchDialog(context, widget.forumApi!, boardId: id),
            onOpenThread: (id) async {
              await showForumThreadDialog(context, widget.forumApi!, id);
              if (mounted) setState(() => _forumRevision++);
            },
            onCreateThread: _createThread,
          ),
          const SizedBox(height: 18),
        ],
        if (widget.compact) ...[
          _PromoPanel(banners: banners, compact: true),
          const SizedBox(height: 12),
          _AnnouncementTicker(
            announcements: announcements,
            loading: loading,
            compact: true,
          ),
        ] else
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _PromoPanel(banners: banners, compact: false),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _AnnouncementTicker(
                    announcements: announcements,
                    loading: loading,
                    compact: false,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: widget.compact ? 18 : 22),
        _GameBoard(onOpenPlay: widget.onOpenPlay, compact: widget.compact),
        const SizedBox(height: 14),
        _RecentDrawsPanel(draws: recentDraws),
        const SizedBox(height: 14),
        const _HomeBoundaryStrip(),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PromoPanel extends StatefulWidget {
  const _PromoPanel({required this.banners, required this.compact});

  final List<HomeBanner> banners;
  final bool compact;

  @override
  State<_PromoPanel> createState() => _PromoPanelState();
}

class _PromoPanelState extends State<_PromoPanel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _PromoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _current = 0;
      _timer?.cancel();
      _startTimer();
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  void _startTimer() {
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients || widget.banners.length <= 1) return;
      final next = (_current + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 152.0 : 190.0;
    return Container(
      key: const Key('home-welcome-panel'),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF203A40), Color(0xFF172A35), Color(0xFF151E2B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF355054)),
      ),
      child: widget.banners.isEmpty
          ? _DefaultPromo(compact: widget.compact)
          : Stack(
              children: [
                PageView.builder(
                  key: const Key('home-banner-strip'),
                  controller: _controller,
                  itemCount: widget.banners.length,
                  onPageChanged: (index) => setState(() => _current = index),
                  itemBuilder: (context, index) => _BannerPage(
                    banner: widget.banners[index],
                  ),
                ),
                if (widget.banners.length > 1)
                  Positioned(
                    left: 26,
                    bottom: 18,
                    child: Row(
                      key: const Key('home-banner-dots'),
                      children: [
                        for (var i = 0; i < widget.banners.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: i == _current ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: i == _current
                                  ? AppTheme.gold
                                  : AppTheme.muted.withOpacity(.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DefaultPromo extends StatelessWidget {
  const _DefaultPromo({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: compact ? -38 : -10,
          top: compact ? -72 : -56,
          child: Container(
            width: compact ? 180 : 230,
            height: compact ? 180 : 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold.withOpacity(.14), width: 28),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 26,
            compact ? 20 : 26,
            compact ? 92 : 130,
            compact ? 18 : 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'CAIYOU FORUM',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.6,
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '分享经验 · 交流心得',
                style: TextStyle(
                  fontSize: compact ? 23 : 29,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '一起讨论彩种、开奖与玩法',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BannerPage extends StatelessWidget {
  const _BannerPage({required this.banner});

  final HomeBanner banner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('home-banner-${banner.id}'),
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '平台推荐',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            banner.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            banner.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTicker extends StatefulWidget {
  const _AnnouncementTicker({
    required this.announcements,
    required this.loading,
    required this.compact,
  });

  final List<HomeAnnouncement> announcements;
  final bool loading;
  final bool compact;

  @override
  State<_AnnouncementTicker> createState() => _AnnouncementTickerState();
}

class _AnnouncementTickerState extends State<_AnnouncementTicker> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _AnnouncementTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announcements.length != widget.announcements.length) {
      _index = 0;
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    if (widget.announcements.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.announcements.length <= 1) return;
      setState(() => _index = (_index + 1) % widget.announcements.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.announcements.isEmpty
        ? null
        : widget.announcements[_index % widget.announcements.length];

    return Card(
      key: const Key('announcement-board'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, widget.compact ? 14 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '平台公告',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  widget.announcements.isEmpty
                      ? ''
                      : '${_index + 1}/${widget.announcements.length}',
                  key: const Key('announcement-page-indicator'),
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.loading)
              const Text('正在读取', style: TextStyle(color: AppTheme.muted))
            else if (item == null)
              const Text(
                '暂无公告',
                key: Key('announcement-empty'),
                style: TextStyle(color: AppTheme.muted),
              )
            else
              SizedBox(
                height: widget.compact ? 72 : 112,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, .18),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: _AnnouncementItem(
                    key: ValueKey(item.id),
                    item: item,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementItem extends StatelessWidget {
  const _AnnouncementItem({required this.item, super.key});

  final HomeAnnouncement item;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        key: Key('announcement-${item.id}'),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSoft.withOpacity(.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.pinned ? '置顶 · ${item.title}' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (item.pinned) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '置顶',
                    key: Key('announcement-pinned-badge'),
                    style: TextStyle(fontSize: 10, color: AppTheme.gold),
                  ),
                ],
              ],
            ),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                item.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({required this.compact, this.onOpenPlay});

  final bool compact;
  final ValueChanged<PlayKind>? onOpenPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('热门彩种', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            const Text('4 个入口', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: HomePage.games.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 2 : 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: compact ? 126 : 142,
          ),
          itemBuilder: (context, index) {
            final game = HomePage.games[index];
            final enabled = game.kind != null && onOpenPlay != null;
            return _GameCard(
              entry: game,
              onTap: enabled ? () => onOpenPlay!(game.kind!) : null,
            );
          },
        ),
      ],
    );
  }
}

class _HomeGameEntry {
  const _HomeGameEntry({
    this.kind,
    required this.title,
    required this.subtitle,
    required this.keyName,
    required this.badge,
    required this.status,
    required this.accent,
  });

  final PlayKind? kind;
  final String title;
  final String subtitle;
  final String keyName;
  final String badge;
  final String status;
  final Color accent;
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.entry, this.onTap});

  final _HomeGameEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Card(
      key: Key(entry.keyName),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    key: Key('${entry.keyName}-badge'),
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.accent.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: entry.accent.withOpacity(.38)),
                    ),
                    child: Text(
                      entry.badge,
                      style: TextStyle(
                        color: entry.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: entry.badge.length > 1 ? 15 : 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: enabled ? entry.accent.withOpacity(.10) : AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: enabled ? entry.accent : AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                entry.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentDrawsPanel extends StatelessWidget {
  const _RecentDrawsPanel({required this.draws});

  final List<HomeRecentDraw> draws;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home-recent-draws'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('最新开奖', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            const Text(
              '仅展示已确认结果',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: draws.isEmpty
                ? const SizedBox(
                    height: 52,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '暂无已确认开奖',
                        key: Key('home-recent-draws-empty'),
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < draws.length; i++) ...[
                        _RecentDrawRow(draw: draws[i]),
                        if (i != draws.length - 1) const Divider(height: 17),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _RecentDrawRow extends StatelessWidget {
  const _RecentDrawRow({required this.draw});

  final HomeRecentDraw draw;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('home-draw-${draw.code}'),
      children: [
        SizedBox(
          width: 138,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '福建31 · ${draw.code}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                draw.drawDate,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final number in draw.mainNumbers) _DrawNumber(number: number),
              for (final number in draw.extraNumbers) _DrawNumber(number: number, extra: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawNumber extends StatelessWidget {
  const _DrawNumber({required this.number, this.extra = false});

  final int number;
  final bool extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: extra ? AppTheme.gold.withOpacity(.16) : AppTheme.teal.withOpacity(.14),
        border: Border.all(
          color: extra ? AppTheme.gold.withOpacity(.58) : AppTheme.teal.withOpacity(.48),
        ),
      ),
      child: Text(
        number.toString().padLeft(2, '0'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: extra ? AppTheme.gold : AppTheme.ink,
        ),
      ),
    );
  }
}

class _HomeBoundaryStrip extends StatelessWidget {
  const _HomeBoundaryStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-boundary-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft.withOpacity(.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Row(
        children: [
          Text('●', style: TextStyle(color: AppTheme.teal, fontSize: 10)),
          SizedBox(width: 8),
          Text('积分娱乐', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
          SizedBox(width: 14),
          Text('开奖数据留证后人工复核', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          Spacer(),
          Text('不含现金充值、提现或兑付', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.loggedIn,
    required this.reader,
    this.onGoToAccount,
    this.onGoToModerator,
  });

  final bool loggedIn;
  final PointsReader reader;
  final VoidCallback? onGoToAccount;
  final VoidCallback? onGoToModerator;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home-side-panel'),
      padding: EdgeInsets.zero,
      children: [
        _HomePointsCard(
          loggedIn: loggedIn,
          reader: reader,
          onGoToAccount: onGoToAccount,
        ),
        const SizedBox(height: 12),
        Card(
          child: InkWell(
            key: const Key('open-moderator'),
            onTap: onGoToModerator,
            borderRadius: BorderRadius.circular(18),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '版主中心',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .8,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('开通版主', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 7),
                  Text(
                    '达标即可开通（默认门槛 10000，开通时冻结），无需审核',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('彩种进度', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 10),
                Text('福建31 · 已开放', style: TextStyle(fontSize: 12)),
                SizedBox(height: 6),
                Text('数字选号 · 已开放', style: TextStyle(fontSize: 12)),
                SizedBox(height: 6),
                Text('排列三 / 快乐8 · 筹备中', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomePointsCard extends StatefulWidget {
  const _HomePointsCard({
    required this.loggedIn,
    required this.reader,
    this.onGoToAccount,
  });

  final bool loggedIn;
  final PointsReader reader;
  final VoidCallback? onGoToAccount;

  @override
  State<_HomePointsCard> createState() => _HomePointsCardState();
}

class _HomePointsCardState extends State<_HomePointsCard> {
  PointsSnapshot? _snapshot;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.loggedIn) _load();
  }

  @override
  void didUpdateWidget(covariant _HomePointsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loggedIn == oldWidget.loggedIn && widget.reader == oldWidget.reader) return;
    if (widget.loggedIn) {
      _load();
    } else {
      setState(() {
        _snapshot = null;
        _error = null;
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.reader.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loggedIn) {
      return Card(
        child: InkWell(
          key: const Key('home-points-login-hint'),
          onTap: widget.onGoToAccount,
          borderRadius: BorderRadius.circular(18),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我的积分', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                SizedBox(height: 14),
                Text('--', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('去个人中心登录', style: TextStyle(color: AppTheme.muted)),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading && _snapshot == null && _error == null) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(18), child: Text('积分正在读取…')),
      );
    }

    if (_error != null) {
      return Card(
        child: InkWell(
          key: const Key('home-points-load-error'),
          onTap: _load,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('积分读取失败'),
                const SizedBox(height: 6),
                Text(
                  _error is PointsLoadException
                      ? (_error! as PointsLoadException).message
                      : '读取失败',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 8),
                const Text('点击重试', style: TextStyle(color: AppTheme.gold)),
              ],
            ),
          ),
        ),
      );
    }

    final balance = _snapshot?.balance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('我的积分', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Text(
              balance == null ? '--' : '$balance',
              key: const Key('home-points-balance'),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('账面余额', style: TextStyle(color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _NarrowNotice extends StatelessWidget {
  const _NarrowNotice();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '请使用横屏查看首页',
          key: Key('landscape-required'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
