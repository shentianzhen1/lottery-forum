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
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 2),
      child: Row(
        children: [
          Expanded(
            child: _StatusCard(
              key: const Key('home-current-round-card'),
              icon: Icons.schedule_rounded,
              eyebrow: '福建31 · 当前期号',
              title: _loading
                  ? '正在读取…'
                  : round == null
                      ? '暂无可展示期号'
                      : (round.code.isEmpty ? '当前期' : round.code),
              detail: _loading
                  ? '正在同步销售状态'
                  : round == null
                      ? '等待期号开放'
                      : selling
                          ? '本期正在受理 · 点击进入玩法'
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
            width: 258,
            child: _StatusCard(
              key: const Key('home-my-bets-card'),
              icon: Icons.confirmation_number_outlined,
              eyebrow: '我的本期投注',
              title: !widget.loggedIn
                  ? '登录后查看'
                  : _loading
                      ? '正在读取…'
                      : betCount == null
                          ? '暂不可用'
                          : '$betCount 笔',
              detail: !widget.loggedIn
                  ? '登录后查看本期订单'
                  : betCount == null
                      ? '点击进入玩法中心'
                      : betCount == 0
                          ? '本期暂无已受理订单'
                          : '可继续查看或撤单',
              accent: AppTheme.gold,
              onTap: widget.loggedIn ? widget.onOpenFujian31 : widget.onGoToAccount,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            height: 86,
            child: _HistoryAction(
              loggedIn: widget.loggedIn,
              onTap: widget.loggedIn ? widget.onOpenHistory : widget.onGoToAccount,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.accent,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String detail;
  final Color accent;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 86,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceRaised,
                Color.alphaBlend(accent.withOpacity(.035), AppTheme.surface),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: onTap == null ? AppTheme.border : accent.withOpacity(.30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.10),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: accent.withOpacity(.24)),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withOpacity(.28),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              eyebrow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .1,
                              ),
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 9),
                            trailing!,
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
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
                  Icon(Icons.chevron_right_rounded, size: 19, color: accent.withOpacity(.88)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryAction extends StatelessWidget {
  const _HistoryAction({required this.loggedIn, this.onTap});

  final bool loggedIn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home-bet-history-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withOpacity(.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.receipt_long_outlined, size: 18, color: AppTheme.gold),
                ),
                const SizedBox(height: 5),
                const Text(
                  '全部记录',
                  maxLines: 1,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
                Text(
                  loggedIn ? '查看历史' : '需登录',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 9, color: AppTheme.muted),
                ),
              ],
            ),
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
    final accent = active ? AppTheme.teal : AppTheme.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}
