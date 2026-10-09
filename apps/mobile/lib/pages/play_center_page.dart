import 'package:flutter/material.dart';

class PlayCenterPage extends StatelessWidget {
  const PlayCenterPage({required this.landscapeReady, super.key});

  final bool landscapeReady;

  static const games = <(String, String)>[
    ('数字选号', '选择 3 个不重复数字。结算未接入。'),
    ('排名竞猜', '排列 3 个不重复选项。结算未接入。'),
  ];

  @override
  Widget build(BuildContext context) {
    if (!landscapeReady) {
      return const Center(
        child: Text('请使用横屏查看玩法中心', key: Key('play-landscape-required')),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        key: Key('play-landscape-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 280, child: _GameList()),
          SizedBox(width: 20),
          Expanded(child: _PlayPanel()),
        ],
      ),
    );
  }
}

class _GameList extends StatelessWidget {
  const _GameList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('玩法', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final game in PlayCenterPage.games)
          Card(
            child: ListTile(
              title: Text(game.$1),
              subtitle: const Text('规则校验已预留'),
            ),
          ),
      ],
    );
  }
}

class _PlayPanel extends StatelessWidget {
  const _PlayPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('数字选号', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('左侧选择玩法，右侧展示输入和结果。当前只验证布局，不提交结算。'),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            title: Text('输入区'),
            subtitle: Text('选择 3 个不重复数字'),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            key: Key('play-result-panel'),
            title: Text('结果区'),
            subtitle: Text('结算未接入积分账本'),
          ),
        ),
      ],
    );
  }
}
