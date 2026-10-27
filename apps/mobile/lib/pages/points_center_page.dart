import 'package:flutter/material.dart';

import '../design/app_theme.dart';
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
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '积分读取失败',
                  key: Key('points-load-error'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _error is PointsLoadException
                      ? (_error! as PointsLoadException).message
                      : '请稍后重试',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 18),
                FilledButton(onPressed: _load, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }
    if (snapshot == null) {
      return const Center(child: Text('正在读取积分'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Padding(
          padding: EdgeInsets.all(compact ? 18 : 24),
          child: Row(
            key: const Key('points-landscape-columns'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? 270 : 320,
                child: _Summary(snapshot: snapshot),
              ),
              SizedBox(width: compact ? 14 : 20),
              Expanded(child: _Entries(snapshot: snapshot)),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final PointsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text('积分钱包', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF234B70), Color(0xFF142942)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF3B6085)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('账面余额', style: TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 6),
              Text(
                '${snapshot.balance}',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _BalanceLine(
                label: '账面余额 ${snapshot.balance}',
                value: '${snapshot.balance}',
                key: const Key('points-book-balance'),
              ),
              const SizedBox(height: 8),
              _BalanceLine(label: '冻结 ${snapshot.frozen}', value: '${snapshot.frozen}'),
              const SizedBox(height: 8),
              _BalanceLine(
                label: '可用余额 ${snapshot.available}',
                value: '${snapshot.available}',
                key: const Key('points-available'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '冻结会减少可用余额，不改变账面余额。保证金数量尚未确定。',
              style: TextStyle(color: AppTheme.muted, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('变动明细', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            key: const Key('points-entry-list'),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  title: Text(rows[index]),
                  trailing: const Text('记录', style: TextStyle(color: AppTheme.muted)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
