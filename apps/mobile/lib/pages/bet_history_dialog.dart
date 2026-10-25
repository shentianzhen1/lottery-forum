import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'bet_history.dart';

class BetHistoryDialog extends StatefulWidget {
  const BetHistoryDialog({required this.reader, super.key});

  final BetHistoryReader reader;

  @override
  State<BetHistoryDialog> createState() => _BetHistoryDialogState();
}

class _BetHistoryDialogState extends State<BetHistoryDialog> {
  List<BetHistoryItem>? _items;
  Object? _error;
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
                  const Spacer(),
                  IconButton(
                    key: const Key('bet-history-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '仅展示当前账号自己的投注记录，最新记录排在前面。',
                style: TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
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
                                  return _BetHistoryRow(item: visible[index]);
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
  const _BetHistoryRow({required this.item});

  final BetHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.active ? AppTheme.teal : AppTheme.muted;
    return Padding(
      key: Key('bet-history-${item.betId}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
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
                      item.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '号码 ${item.numbersLabel}  ·  ${item.stake} 积分',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.timeLabel}  ·  期号记录 ${_shortId(item.roundId)}',
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

String _shortId(String value) {
  if (value.isEmpty) return '—';
  return value.length <= 12 ? value : '${value.substring(0, 8)}…';
}
