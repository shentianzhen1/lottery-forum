import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'home_feed.dart';
import 'play_betting.dart';
import 'points_reader.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.landscapeReady,
    this.loggedIn = false,
    this.reader = const DisconnectedPointsReader(),
    this.feed = const EmptyHomeFeed(),
    this.onGoToAccount,
    this.onGoToModerator,
    this.onOpenPlay,
    super.key,
  });

  final bool landscapeReady;
  final bool loggedIn;
  final PointsReader reader;
  final HomeFeed feed;
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
    if (!landscapeReady) {
      return const _NarrowNotice();
    }

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
                  onOpenPlay: onOpenPlay,
                  compact: compact,
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
    this.onOpenPlay,
  });

  final HomeFeed feed;
  final bool compact;
  final ValueChanged<PlayKind>? onOpenPlay;

  @override
  State<_MainColumn> createState() => _MainColumnState();
}

class _MainColumnState extends State<_MainColumn> {
  HomeFeedData? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MainColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feed != oldWidget.feed) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await widget.feed.load();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _data = const HomeFeedData(banners: [], announcements: []);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final announcements = data?.announcements ?? const <HomeAnnouncement>[];
    final banners = data?.banners ?? const <HomeBanner>[];

    return ListView(
      key: const Key('home-main-scroll'),
      padding: EdgeInsets.zero,
      children: [
        if (widget.compact) ...[
          _PromoPanel(banners: banners, compact: true),
          const SizedBox(height: 12),
          _AnnouncementBoard(
            announcements: announcements,
            loading: data == null && _error == null,
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
                  child: _AnnouncementBoard(
                    announcements: announcements,
                    loading: data == null && _error == null,
                    compact: false,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: widget.compact ? 18 : 22),
        _GameBoard(onOpenPlay: widget.onOpenPlay, compact: widget.compact),
        const SizedBox(height: 14),
        const _HomeBoundaryStrip(),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PromoPanel extends StatelessWidget {
  const _PromoPanel({required this.banners, required this.compact});

  final List<HomeBanner> banners;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 152.0 : 190.0;
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
      child: banners.isEmpty
          ? _DefaultPromo(compact: compact)
          : PageView.builder(
              key: const Key('home-banner-strip'),
              itemCount: banners.length,
              itemBuilder: (context, index) {
                final banner = banners[index];
                return _BannerPage(banner: banner, index: index, total: banners.length);
              },
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
                '多种玩法 · 清晰记录',
                style: TextStyle(
                  fontSize: compact ? 23 : 29,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '积分娱乐 · 开奖留证 · 规则透明',
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
  const _BannerPage({required this.banner, required this.index, required this.total});

  final HomeBanner banner;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('home-banner-${banner.id}'),
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '平台推荐',
            style: TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700),
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
          if (total > 1) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                for (var i = 0; i < total; i++)
                  Container(
                    width: i == index ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: i == index ? AppTheme.gold : AppTheme.muted.withOpacity(.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AnnouncementBoard extends StatelessWidget {
  const _AnnouncementBoard({
    required this.announcements,
    required this.loading,
    required this.compact,
  });

  final List<HomeAnnouncement> announcements;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('announcement-board'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                  announcements.isEmpty ? '' : '${announcements.length} 条',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              const Text('正在读取', style: TextStyle(color: AppTheme.muted))
            else if (announcements.isEmpty)
              const Text('暂无公告', key: Key('announcement-empty'), style: TextStyle(color: AppTheme.muted))
            else
              ...announcements.take(compact ? 3 : 4).map(
                (item) => Padding(
                  key: Key('announcement-${item.id}'),
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.pinned ? AppTheme.gold : AppTheme.muted,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.pinned ? '置顶 · ${item.title}' : item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (item.summary.isNotEmpty)
                              Text(
                                item.summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                              ),
                          ],
                        ),
                      ),
                      if (item.pinned)
                        const Text(
                          '置顶',
                          key: Key('announcement-pinned-badge'),
                          style: TextStyle(fontSize: 10, color: AppTheme.gold),
                        ),
                    ],
                  ),
                ),
              ),
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
    if (widget.loggedIn) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant _HomePointsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loggedIn != oldWidget.loggedIn || widget.reader != oldWidget.reader) {
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
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.reader.load();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
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
                  _error is PointsLoadException ? (_error! as PointsLoadException).message : '读取失败',
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

    final snapshot = _snapshot;
    final balance = snapshot?.balance;
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
