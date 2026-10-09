import 'package:flutter/material.dart';

class ModeratorPage extends StatelessWidget {
  const ModeratorPage({required this.landscapeReady, super.key});

  final bool landscapeReady;

  @override
  Widget build(BuildContext context) {
    if (!landscapeReady) {
      return const Center(
        child: Text('请使用横屏查看版主中心', key: Key('moderator-landscape-required')),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        key: Key('moderator-landscape-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _ApplyPanel()),
          SizedBox(width: 20),
          Expanded(child: _StatusPanel()),
        ],
      ),
    );
  }
}

class _ApplyPanel extends StatelessWidget {
  const _ApplyPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('申请版主', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('说明需要 10 到 200 个字符。提交后状态为待审核。'),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            title: Text('申请说明'),
            subtitle: Text('接口已预留，此页尚未提交。'),
          ),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        key: Key('moderator-status'),
        title: Text('审核状态'),
        subtitle: Text('待审核。不能自行通过。'),
      ),
    );
  }
}
