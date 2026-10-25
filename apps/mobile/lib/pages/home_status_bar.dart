import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'home_status.dart';

class HomeStatusBar extends StatefulWidget {
  const HomeStatusBar({
    required this.reader,
    required this.loggedIn,
    this.onOpenFujian31,
    this.onOpenHistory,
    this.onGoToAccount,
    super.key,
  });

  final HomeStatusReader reader;
  final bool loggedIn;
  final VoidCallback? onOpenFujian31;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onGoToAccount;

  @override
  State<HomeStatusBar> createState() => _HomeStatusBarState();
}

class _HomeStatusBarState extends State<HomeStatusBar> {
  HomeStatusSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reader != oldWidget.reader || widget.loggedIn != oldWidget.loggedIn) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snapshot = await widget.reader.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final round = snapshot?.currentRound;
    final selling = round?.acceptsBets == true;
    final betCount = snapshot?.currentAcceptedBets;

    return Container(
      key: const Key('home-status-bar'),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatusCard(
              key: const Key('home-current-round-card'),
              eyebrow: '福建31 · 本期状态',
              title: _loading
                  ? '正在读取…'
                  : round == null
                      ? '暂无可展示期号'
                      : (round.code.isEmpty ? '当前期' : round.code),
              detail: _loading
                  ? ' '
                  : round == null
                      ? '等待期号开放'
                      : round.statusLabel,
              accent: selling ? AppTheme.teal : AppTheme.gold,
              trailing: round == null
                  ? null
                  : _StatusPill(
                      text: round.statusLabel,
                      active: selling,
                    ),
              onTap: selling ? widget.onOpenFujian31 : null,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 250,
            child: _StatusCard(
              key: const Key('home-my-bets-card'),
              eyebrow: '我的本期投注',
              title: !widget.loggedIn
                  ? '登录后查看'
                  : _loading
                      ? '正在读取…'
                      : betCount == null
                          ? '暂不可用'
                          : '$betCount 笔',
              detail: !widget.loggedIn
                  ? '查看本期已受理订单'
                  : betCount == null
                      ? '点击重试或进入玩法中心'
                      : betCount == 0
                          ? '本期暂无已受理订单'
                          : '点击进入查看或撤单',
              accent: AppTheme.gold,
              onTap: widget.loggedIn ? widget.onOpenFujian31 : widget.onGoToAccount,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            height: 82,
            child: OutlinedButton(
              key: const Key('home-bet-history-button'),
              onPressed: widget.loggedIn ? widget.onOpenHistory : widget.onGoToAccount,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(76, 82),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 20),
                  SizedBox(height: 5),
                  Text('记录', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.accent,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final Color accent;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 10),
                          trailing!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18, color: AppTheme.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (active ? AppTheme.teal : AppTheme.gold).withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active ? AppTheme.teal : AppTheme.gold,
        ),
      ),
    );
  }
}
