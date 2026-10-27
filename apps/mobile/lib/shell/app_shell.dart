import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/bet_history_api.dart';
import '../api/forum_api.dart';
import '../api/home_feed_api.dart';
import '../api/home_status_api.dart';
import '../api/play_betting_api.dart';
import '../api/session.dart';
import '../api/standalone_api_client.dart';
import '../design/app_theme.dart';
import '../pages/account_page.dart';
import '../pages/bet_history_dialog.dart';
import '../pages/forum_center_page.dart';
import '../pages/home_page.dart';
import '../pages/home_status_bar.dart';
import '../pages/moderator_page.dart';
import '../pages/play_betting.dart';
import '../pages/play_center_page.dart';
import '../pages/points_center_page.dart';

const standaloneMode = bool.fromEnvironment('STANDALONE_MODE');

class AppDestination {
  const AppDestination(this.label, this.icon);
  final String label;
  final IconData icon;
}

const destinations = <AppDestination>[
  AppDestination('首页', Icons.home_outlined),
  AppDestination('玩法中心', Icons.grid_view_outlined),
  AppDestination('积分中心', Icons.account_balance_wallet_outlined),
  AppDestination('版主中心', Icons.verified_user_outlined),
  AppDestination('个人中心', Icons.person_outline),
  AppDestination('论坛', Icons.forum_outlined),
];

class AppShell extends StatefulWidget {
  const AppShell({this.client, super.key});
  final ApiClient? client;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  PlayKind _playKind = PlayKind.numberPick;
  late final ApiClient _client;
  late final ForumApi _forumApi;
  bool _clientReady = !standaloneMode;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? (standaloneMode
        ? StandaloneApiClient()
        : ApiClient(const ApiConfig(), Session()));
    _forumApi = ForumApi(_client);
    final client = _client;
    if (client is StandaloneApiClient) {
      client.initialize().whenComplete(() {
        if (!mounted) return;
        setState(() => _clientReady = true);
      });
    }
  }

  void _showBetHistory() {
    if (_client.session.token == null) {
      setState(() => _index = 4);
      return;
    }
    final standaloneClient = _client is StandaloneApiClient ? _client : null;
    showDialog<void>(
      context: context,
      builder: (_) => BetHistoryDialog(
        reader: ApiBetHistoryReader(_client),
        onSimulateSettlement: standaloneClient?.simulateSettlement,
      ),
    ).whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_clientReady) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(key: Key('standalone-restore-progress')),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscapeReady = constraints.maxWidth >= 960;
            return Row(
              children: [
                _NavRail(
                  selected: _index,
                  compact: !landscapeReady,
                  onSelected: (index) => setState(() => _index = index),
                ),
                Expanded(
                  child: Column(
                    children: [
                      if (landscapeReady)
                        _WorkspaceHeader(destination: destinations[_index].label),
                      Expanded(child: _pageFor(_index, landscapeReady)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pageFor(int index, bool landscapeReady) {
    final loggedIn = _client.session.token != null;
    switch (index) {
      case 0:
        if (!landscapeReady) {
          return HomePage(
            landscapeReady: false,
            loggedIn: loggedIn,
            reader: ApiPointsReader(_client, includeEntries: false),
            feed: ApiHomeFeed(_client),
          );
        }
        return Column(
          children: [
            HomeStatusBar(
              reader: ApiHomeStatusReader(_client),
              loggedIn: loggedIn,
              onGoToAccount: () => setState(() => _index = 4),
              onOpenHistory: _showBetHistory,
              onOpenFujian31: () => setState(() {
                _playKind = PlayKind.fujian31;
                _index = 1;
              }),
            ),
            Expanded(
              child: HomePage(
                landscapeReady: true,
                loggedIn: loggedIn,
                reader: ApiPointsReader(_client, includeEntries: false),
                feed: ApiHomeFeed(_client),
                forumApi: _forumApi,
                onGoToAccount: () => setState(() => _index = 4),
                onGoToModerator: () => setState(() => _index = 3),
                onOpenPlay: (kind) => setState(() {
                  _playKind = kind;
                  _index = 1;
                }),
              ),
            ),
          ],
        );
      case 1:
        return PlayCenterPage(
          landscapeReady: landscapeReady,
          loggedIn: loggedIn,
          gateway: ApiPlayBettingGateway(_client),
          initialKind: _playKind,
          onGoToAccount: () => setState(() => _index = 4),
        );
      case 2:
        return PointsCenterPage(
          landscapeReady: landscapeReady,
          reader: ApiPointsReader(_client),
        );
      case 3:
        return ModeratorPage(
          landscapeReady: landscapeReady,
          loggedIn: loggedIn,
          gateway: ApiModeratorGateway(_client),
          onGoToAccount: () => setState(() => _index = 4),
        );
      case 4:
        return AccountPage(
          landscapeReady: landscapeReady,
          client: _client,
          onChanged: () => setState(() {}),
        );
      case 5:
        return ForumCenterPage(
          landscapeReady: landscapeReady,
          loggedIn: loggedIn,
          api: _forumApi,
          onGoToAccount: () => setState(() => _index = 4),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.destination});
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Text(
            destination,
            key: const Key('workspace-title'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          const Text('·', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(width: 10),
          const Text('彩友论坛', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          if (standaloneMode) ...[
            const SizedBox(width: 10),
            Container(
              key: const Key('standalone-mode-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF332F27),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gold.withOpacity(.3)),
              ),
              child: const Text(
                '单机测试',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          const Text(
            'CAIYOU FORUM',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.2,
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.selected,
    required this.compact,
    required this.onSelected,
  });

  final int selected;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 76.0 : 190.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 12,
        compact ? 8 : 12,
        compact ? 8 : 10,
        compact ? 8 : 12,
      ),
      child: Container(
        key: const Key('primary-nav'),
        width: width,
        decoration: BoxDecoration(
          color: AppTheme.rail,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 14, 12, 20),
                child: Align(
                  alignment: Alignment.center,
                  child: _CompactBrandMark(),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: _ExtendedBrandMark(),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
              child: Column(
                children: [
                  for (var index = 0; index < 3; index++) ...[
                    _NavItem(
                      index: index,
                      destination: destinations[index],
                      selected: selected == index,
                      compact: compact,
                      onTap: () => onSelected(index),
                    ),
                    if (index != 2) const SizedBox(height: 4),
                  ],
                  SizedBox(height: compact ? 14 : 18),
                  for (var index = 3; index < destinations.length; index++) ...[
                    _NavItem(
                      index: index,
                      destination: destinations[index],
                      selected: selected == index,
                      compact: compact,
                      onTap: () => onSelected(index),
                    ),
                    if (index != destinations.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            const Spacer(),
            if (!compact)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Text(
                  'CAIYOU FORUM',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.8,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final int index;
  final AppDestination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.gold : AppTheme.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('nav-item-$index'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: compact ? 46 : 48,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF332F27) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: AppTheme.gold.withOpacity(.10))
                : null,
          ),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(destination.icon, size: 18, color: foreground),
              if (!compact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactBrandMark extends StatelessWidget {
  const _CompactBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF332F27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withOpacity(.28)),
      ),
      child: const Text(
        '彩',
        style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ExtendedBrandMark extends StatelessWidget {
  const _ExtendedBrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF332F27),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.gold.withOpacity(.3)),
          ),
          child: const Text(
            '彩',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '彩友论坛',
          key: Key('brand-mark'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '每一笔，都有迹可循',
          style: TextStyle(fontSize: 10, color: AppTheme.muted),
        ),
      ],
    );
  }
}
