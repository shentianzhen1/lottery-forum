import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.landscapeReady, super.key});

  final bool landscapeReady;

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
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        key: Key('home-landscape-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: _MainColumn()),
          SizedBox(width: 20),
          SizedBox(width: 280, child: _SidePanel()),
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
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        Card(
          child: ListTile(
            title: Text('积分'),
            subtitle: Text('账本未实现'),
            trailing: Text('--', key: Key('points-placeholder')),
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: ListTile(
            key: Key('apply-moderator'),
            title: Text('申请版主'),
            subtitle: Text('审核流程未实现'),
          ),
        ),
      ],
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
