import 'package:flutter/material.dart';

import 'points_reader.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.landscapeReady,
    this.loggedIn = false,
    this.reader = const DisconnectedPointsReader(),
    this.onGoToAccount,
    super.key,
  });

  final bool landscapeReady;
  final bool loggedIn;
  final PointsReader reader;
  final VoidCallback? onGoToAccount;

  static const games = <(String, String)>[
    ('数字选号', '数字类入口，规则未接入'),
    ('排名竞猜', '排名类入口，规则未接入'),
    ('自选组合', '组合类入口，规则未接入'),
    ('本期推荐', '推荐位，数据未接入'),
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
          const Expanded(flex: 5, child: _MainColumn()),
          const SizedBox(width: 20),
          SizedBox(
            width: 280,
            child: _SidePanel(
              loggedIn: loggedIn,
              reader: reader,
              onGoToAccount: onGoToAccount,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnnouncementBoard(),
        SizedBox(height: 16),
        Expanded(child: _GameBoard()),
      ],
    );
  }
}

class _AnnouncementBoard extends StatelessWidget {
  const _AnnouncementBoard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      key: Key('announcement-board'),
      child: ListTile(
        title: Text('平台公告'),
        subtitle: Text('暂无公告'),
        trailing: Text('更多'),
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard();

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
                _GameCard(title: game.$1, subtitle: game.$2),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
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
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.loggedIn,
    required this.reader,
    this.onGoToAccount,
  });

  final bool loggedIn;
  final PointsReader reader;
  final VoidCallback? onGoToAccount;

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
        const Card(
          child: ListTile(
            key: Key('open-moderator'),
            title: Text('开通版主'),
            subtitle: Text('达标即可开通，入口尚未接入'),
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
