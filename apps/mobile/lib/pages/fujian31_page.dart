import 'package:flutter/material.dart';

class Fujian31Page extends StatelessWidget {
  const Fujian31Page({
    required this.landscapeReady,
    this.selected = const [1, 2, 3, 7, 8, 9, 31],
    super.key,
  });

  final bool landscapeReady;
  final List<int> selected;

  @override
  Widget build(BuildContext context) {
    if (!landscapeReady) {
      return const Center(
        child: Text('请使用横屏查看福建31选7', key: Key('fujian-landscape-required')),
      );
    }
    final ordered = [...selected]..sort();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        key: const Key('fujian-landscape-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _NumberGrid(selected: ordered)),
          const SizedBox(width: 20),
          SizedBox(width: 360, child: _ResultPanel(selected: ordered)),
        ],
      ),
    );
  }
}

class _NumberGrid extends StatelessWidget {
  const _NumberGrid({required this.selected});

  final List<int> selected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 8,
      childAspectRatio: 1.4,
      children: [
        for (var number = 1; number <= 31; number++)
          Card(
            child: Center(
              child: Text(
                '$number',
                key: Key('fujian-number-$number'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.selected});

  final List<int> selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('福建31选7', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text('已选 ${selected.join(' ')}', key: const Key('fujian-selected')),
        const Text('21 对', key: Key('fujian-pair-count')),
        const SizedBox(height: 12),
        const Text('只展示选号。不扣分，不开奖，不派奖。'),
      ],
    );
  }
}
