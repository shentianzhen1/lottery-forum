import 'package:flutter/material.dart';

import 'points_reader.dart';

class PointsCenterPage extends StatefulWidget {
  const PointsCenterPage({
    required this.landscapeReady,
    this.reader = const DisconnectedPointsReader(),
    super.key,
  });

  final bool landscapeReady;
  final PointsReader reader;

  @override
  State<PointsCenterPage> createState() => _PointsCenterPageState();
}

class _PointsCenterPageState extends State<PointsCenterPage> {
  PointsSnapshot? _snapshot;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final snapshot = await widget.reader.load();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.landscapeReady) {
      return const Center(
        child: Text('请使用横屏查看积分中心', key: Key('points-landscape-required')),
      );
    }
    final snapshot = _snapshot;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('积分读取失败', key: Key('points-load-error')),
            Text(_error is PointsLoadException ? (_error! as PointsLoadException).message : '请稍后重试'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (snapshot == null) {
      return const Center(child: Text('正在读取积分'));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        key: const Key('points-landscape-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 320, child: _Summary(snapshot: snapshot)),
          const SizedBox(width: 20),
          Expanded(child: _Entries(snapshot: snapshot)),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final PointsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('积分钱包', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text('账面余额 ${snapshot.balance}', key: const Key('points-book-balance')),
        Text('冻结 ${snapshot.frozen}'),
        Text('可用余额 ${snapshot.available}', key: const Key('points-available')),
        const SizedBox(height: 12),
        const Text('冻结会减少可用余额，不改变账面余额。保证金数量尚未确定。'),
      ],
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({required this.snapshot});

  final PointsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.connected ? snapshot.entries : const ['接口尚未接入此页'];
    return ListView(
      key: const Key('points-entry-list'),
      children: [
        Text('变动明细', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final row in rows) Card(child: ListTile(title: Text(row))),
      ],
    );
  }
}
