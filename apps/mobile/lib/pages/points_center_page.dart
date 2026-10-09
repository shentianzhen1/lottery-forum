import 'package:flutter/material.dart';

class PointsSnapshot {
  const PointsSnapshot({
    required this.balance,
    required this.frozen,
    required this.entries,
    required this.connected,
  });

  final int balance;
  final int frozen;
  final List<String> entries;
  final bool connected;

  int get available => balance - frozen;
}

class PointsCenterPage extends StatelessWidget {
  const PointsCenterPage({
    required this.landscapeReady,
    this.snapshot = const PointsSnapshot(
      balance: 0,
      frozen: 0,
      entries: [],
      connected: false,
    ),
    super.key,
  });

  final bool landscapeReady;
  final PointsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (!landscapeReady) {
      return const Center(
        child: Text('请使用横屏查看积分中心', key: Key('points-landscape-required')),
      );
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
        const Text('冻结尚未用于版主保证金。不提供充值、提现或转账。'),
      ],
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({required this.snapshot});

  final PointsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.connected
        ? snapshot.entries
        : const ['接口尚未接入此页'];
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
