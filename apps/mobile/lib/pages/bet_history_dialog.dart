import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'bet_history.dart';

typedef SimulateSettlement = Future<void> Function(String betId, String result);

class BetHistoryDialog extends StatefulWidget {
  const BetHistoryDialog({
    required this.reader,
    this.onSimulateSettlement,
    super.key,
  });

  final BetHistoryReader reader;
  final SimulateSettlement? onSimulateSettlement;

  @override
  State<BetHistoryDialog> createState() => _BetHistoryDialogState();
}

class _BetHistoryDialogState extends State<BetHistoryDialog> {
  List<BetHistoryItem>? _items;
  Object? _error;
  String? _actionError;
  String? _simulatingBetId;
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await widget.reader.load();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = error;
      });
    }
  }

  Future<void> _simulate(BetHistoryItem item, String result) async {
    final action = widget.onSimulateSettlement;
    if (action == null || _simulatingBetId != null) return;
    setState(() {
      _simulatingBetId = item.betId;
      _actionError = null;
    });
    try {
      await action(item.betId, result);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _simulatingBetId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final visible = items == null
        ? const <BetHistoryItem>[]
        : items.where((item) {
            switch (_filter) {
              case _HistoryFilter.all:
                return true;
              case _HistoryFilter.active:
                return item.active;
              case _HistoryFilter.finished:
                return !item.active;
            }
          }).toList();

    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.all(40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: SizedBox(
        key: const Key('bet-history-dialog'),
        width: 760,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '我的投注记录',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  if (widget.onSimulateSettlement != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      key: const Key('standalone-settlement-badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.gold.withOpacity(.25)),
                      ),
                      child: const Text(
                        '单机模拟结算',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    key: const Key('bet-history-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.onSimulateSettlement == null
                    ? '仅展示当前账号自己的投注记录；已结算记录会显示中奖结果和积分变化。'
                    : '单机测试可对已受理订单模拟中奖、未中或退回；余额、冻结积分和记录会同步变化。',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
              if (_actionError != null) ...[
                const SizedBox(height: 6),
                Text(
                  '模拟结算失败：$_actionError',
                  key: const Key('standalone-settlement-error'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.gold),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  _FilterChip(
                    label: '全部',
                    selected: _filter == _HistoryFilter.all,
                    onTap: () => setState(() => _filter = _HistoryFilter.all),
                  ),
                  _FilterChip(
                    label: '进行中',
                    selected: _filter == _HistoryFilter.active,
                    onTap: () => setState(() => _filter = _HistoryFilter.active),
                  ),
                  _FilterChip(
                    label: '已结束',
                    selected: _filter == _HistoryFilter.finished,
                    onTap: () => setState(() => _filter = _HistoryFilter.finished),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: items == null
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('投注记录读取失败'),
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  key: const Key('bet-history-retry'),
                                  onPressed: _load,
                                  child: const Text('重试'),
                                ),
                              ],
                            ),
                          )
                        : visible.isEmpty
                            ? const Center(
                                child: Text(
                                  '暂无符合条件的投注记录',
                                  key: Key('bet-history-empty'),
                                  style: TextStyle(color: AppTheme.muted),
                                ),
                              )
                            : ListView.separated(
                                key: const Key('bet-history-list'),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = visible[index];
                                  return _BetHistoryRow(
                                    item: item,
                                    simulating: _simulatingBetId == item.betId,
                                    onSimulate: widget.onSimulateSettlement == null ||
                                            !item.active ||
                                            item.settlementResult != null
                                        ? null
                                        : (result) => _simulate(item, result),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HistoryFilter { all, active, finished }

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _BetHistoryRow extends StatelessWidget {
  const _BetHistoryRow({
    required this.item,
    required this.simulating,
    this.onSimulate,
  });

  final BetHistoryItem item;
  final bool simulating;
  final ValueChanged<String>? onSimulate;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item);
    final settlementSummary = item.settlementSummaryLabel;
    return Padding(
      key: Key('bet-history-${item.betId}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.playId.startsWith('fujian-31') ? '31' : '3',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _playLabel(item.playId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      item.displayStatusLabel,
                      key: Key('bet-history-result-${item.betId}'),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (onSimulate != null) ...[
                      const SizedBox(width: 8),
                      if (simulating)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        PopupMenuButton<String>(
                          key: Key('standalone-settle-${item.betId}'),
                          tooltip: '模拟结算',
                          onSelected: onSimulate,
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'WIN', child: Text('模拟中奖')),
                            PopupMenuItem(value: 'LOSS', child: Text('模拟未中')),
                            PopupMenuItem(value: 'VOID', child: Text('模拟退回')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.gold.withOpacity(.35)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '模拟结算',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '号码 ${item.numbersLabel}  ·  投入 ${item.stake} 积分',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                if (settlementSummary != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    settlementSummary,
                    key: Key('bet-history-settlement-${item.betId}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  '${item.timeLabel}  ·  期号 ${_roundLabel(item)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(BetHistoryItem item) {
  if (!item.settlementFinalized && item.settlementResult != null) {
    return AppTheme.gold;
  }
  switch (item.settlementResult) {
    case 'WIN':
      return AppTheme.teal;
    case 'VOID':
      return AppTheme.gold;
    case 'LOSS':
      return AppTheme.muted;
    default:
      return item.active ? AppTheme.teal : AppTheme.muted;
  }
}

String _playLabel(String playId) {
  switch (playId) {
    case 'number-pick':
      return '数字选号';
    case 'fujian-31-any-2':
      return '福建31任选2';
    case 'fujian-31-any-3':
      return '福建31任选3';
    case 'fujian-31-any-4':
      return '福建31任选4';
    case 'fujian-31-any-5':
      return '福建31任选5';
    case 'fujian-31':
      return '福建31选7';
    default:
      return playId.isEmpty ? '未知玩法' : playId;
  }
}

String _roundLabel(BetHistoryItem item) {
  if (item.roundCode.trim().isNotEmpty) return item.roundCode.trim();
  return _shortId(item.roundId);
}

String _shortId(String value) {
  if (value.isEmpty) return '—';
  return value.length <= 12 ? value : '${value.substring(0, 8)}…';
}
