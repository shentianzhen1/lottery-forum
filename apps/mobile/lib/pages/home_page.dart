import 'package:flutter/material.dart';

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

  static const games = <(PlayKind, String, String, String)>[
    (PlayKind.numberPick, '数字选号', '选择 3 个不重复数字', 'home-game-number-pick'),
    (PlayKind.fujian31, '福建31', '任选2–5与选7', 'home-game-fujian-31'),
  ];

  @override
  Widget build(BuildContext context) {
    if (!landscapeReady) {
      return const _NarrowNotice();
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        key: const Key('home-landscape-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: _MainColumn(feed: feed, onOpenPlay: onOpenPlay),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 280,
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
  }
}

class _MainColumn extends StatefulWidget {
  const _MainColumn({required this.feed, this.onOpenPlay});

  final HomeFeed feed;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data != null && data.banners.isNotEmpty) ...[
          _BannerStrip(banners: data.banners),
          const SizedBox(height: 16),
        ],
        _AnnouncementBoard(
          announcements: data?.announcements ?? const [],
          loading: data == null && _error == null,
        ),
        const SizedBox(height: 16),
        Expanded(child: _GameBoard(onOpenPlay: widget.onOpenPlay)),
      ],
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
      height: 96,
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
              title: Text(
                item.pinned ? '置顶 · ${item.title}' : item.title,
              ),
              subtitle: Text(item.summary),
              trailing: item.pinned
                  ? const Text('置顶', key: Key('announcement-pinned-badge'))
                  : null,
            ),
        ],
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({this.onOpenPlay});

  final ValueChanged<PlayKind>? onOpenPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('热门玩法', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              for (final game in HomePage.games)
                _GameCard(
                  cardKey: Key(game.$4),
                  title: game.$2,
                  subtitle: game.$3,
                  onTap: onOpenPlay == null ? null : () => onOpenPlay!(game.$1),
                ),
            ],
          ),
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
    this.onTap,
  });

  final Key cardKey;
  final String title;
  final String subtitle;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(subtitle),
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
      children: [
        _HomePointsCard(
          loggedIn: loggedIn,
          reader: reader,
          onGoToAccount: onGoToAccount,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            key: const Key('open-moderator'),
            title: const Text('开通版主'),
            subtitle: const Text('达标即可开通（默认门槛 10000，开通时冻结），无需审核'),
            onTap: onGoToModerator,
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
        child: ListTile(
          key: const Key('home-points-login-hint'),
          title: const Text('积分'),
          subtitle: const Text('去个人中心登录'),
          trailing: const Text('--'),
          onTap: widget.onGoToAccount,
        ),
      );
    }

    if (_loading && _snapshot == null && _error == null) {
      return const Card(
        child: ListTile(
          title: Text('积分'),
          subtitle: Text('正在读取'),
          trailing: Text('…'),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: ListTile(
          key: const Key('home-points-load-error'),
          title: const Text('积分'),
          subtitle: Text(
            _error is PointsLoadException
                ? (_error! as PointsLoadException).message
                : '读取失败',
          ),
          trailing: const Text('重试'),
          onTap: _load,
        ),
      );
    }

    final snapshot = _snapshot;
    final balance = snapshot?.balance;
    return Card(
      child: ListTile(
        title: const Text('积分'),
        subtitle: const Text('账面余额'),
        trailing: Text(
          balance == null ? '--' : '$balance',
          key: const Key('home-points-balance'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
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
