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

  static const games = <(PlayKind, String, String, String, String)>[
    (
      PlayKind.numberPick,
      '数字选号',
      '选择 3 个不重复数字',
      'home-game-number-pick',
      '3',
    ),
    (
      PlayKind.fujian31,
      '福建31',
      '任选2–5与选7',
      'home-game-fujian-31',
      '31',
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
    return ListView(
      key: const Key('home-main-scroll'),
      padding: EdgeInsets.zero,
      children: [
        _WelcomePanel(compact: widget.compact),
        SizedBox(height: widget.compact ? 14 : 18),
        if (data != null && data.banners.isNotEmpty) ...[
          _BannerStrip(banners: data.banners),
          const SizedBox(height: 14),
        ],
        _AnnouncementBoard(
          announcements: data?.announcements ?? const [],
          loading: data == null && _error == null,
        ),
        SizedBox(height: widget.compact ? 18 : 22),
        _GameBoard(onOpenPlay: widget.onOpenPlay, compact: widget.compact),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-welcome-panel'),
      constraints: BoxConstraints(minHeight: compact ? 122 : 138),
      width: double.infinity,
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
      child: Stack(
        children: [
          Positioned(
            right: compact ? -44 : -18,
            top: compact ? -76 : -66,
            child: Container(
              width: compact ? 190 : 220,
              height: compact ? 190 : 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.gold.withOpacity(.14),
                  width: 28,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 24,
              compact ? 20 : 24,
              compact ? 92 : 120,
              compact ? 20 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 8),
                Text(
                  '玩法、积分与记录，一目了然。',
                  style: TextStyle(
                    fontSize: compact ? 22 : 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '快速进入玩法 · 查看积分 · 管理版主入口',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStrip extends StatelessWidget {
  const _BannerStrip({required this.banners});

  final List<HomeBanner> banners;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('home-banner-strip'),
      height: 88,
      child: PageView.builder(
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Card(
            key: Key('home-banner-${banner.id}'),
            child: ListTile(
              title: Text(banner.title),
              subtitle: Text(banner.subtitle),
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementBoard extends StatelessWidget {
  const _AnnouncementBoard({
    required this.announcements,
    required this.loading,
  });

  final List<HomeAnnouncement> announcements;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        key: Key('announcement-board'),
        child: ListTile(
          title: Text('平台公告'),
          subtitle: Text('正在读取'),
        ),
      );
    }
    if (announcements.isEmpty) {
      return const Card(
        key: Key('announcement-board'),
        child: ListTile(
          title: Text('平台公告'),
          subtitle: Text('暂无公告', key: Key('announcement-empty')),
        ),
      );
    }
    return Card(
      key: const Key('announcement-board'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(title: Text('平台公告')),
          for (final item in announcements)
            ListTile(
              key: Key('announcement-${item.id}'),
              title: Text(item.pinned ? '置顶 · ${item.title}' : item.title),
              subtitle: Text(item.summary),
              trailing: item.pinned
                  ? const Text(
                      '置顶',
                      key: Key('announcement-pinned-badge'),
                      style: TextStyle(color: AppTheme.gold),
                    )
                  : null,
            ),
        ],
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
            Text('热门玩法', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            const Text(
              '快捷入口',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: HomePage.games.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: compact ? 12 : 14,
            crossAxisSpacing: compact ? 12 : 14,
            mainAxisExtent: compact ? 136 : 148,
          ),
          itemBuilder: (context, index) {
            final game = HomePage.games[index];
            return _GameCard(
              cardKey: Key(game.$4),
              title: game.$2,
              subtitle: game.$3,
              badge: game.$5,
              badgeKey: Key('${game.$4}-badge'),
              onTap: onOpenPlay == null ? null : () => onOpenPlay!(game.$1),
            );
          },
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.cardKey,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeKey,
    this.onTap,
  });

  final Key cardKey;
  final String title;
  final String subtitle;
  final String badge;
  final Key badgeKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cardKey,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                key: badgeKey,
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF332F27),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppTheme.gold.withOpacity(.34)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: badge.length > 1 ? 17 : 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '→',
                style: TextStyle(
                  fontSize: 20,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
                    '版主入口',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .8,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '开通版主',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
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
                Text(
                  '积分钱包',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 14),
                Text(
                  '--',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
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
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('积分正在读取…'),
        ),
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

    final snapshot = _snapshot;
    final balance = snapshot?.balance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '积分钱包',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
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
