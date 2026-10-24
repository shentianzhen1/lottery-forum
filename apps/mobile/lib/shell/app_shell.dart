import 'package:flutter/material.dart';
import '../design/app_theme.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/session.dart';
import '../pages/account_page.dart';
import '../api/home_feed_api.dart';
import '../api/play_betting_api.dart';
import '../pages/home_page.dart';
import '../pages/moderator_page.dart';
import '../pages/play_betting.dart';
import '../pages/play_center_page.dart';
import '../pages/points_center_page.dart';

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
];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  PlayKind _playKind = PlayKind.numberPick;
  final _client = ApiClient(const ApiConfig(), Session());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: LayoutBuilder(
        builder: (context, constraints) {
          final landscapeReady = constraints.maxWidth >= 960;
          return Row(
            children: [
              _NavRail(
                selected: _index,
                compact: !landscapeReady,
                onSelected: (index) => setState(() => _index = index),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    if (landscapeReady)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                        child: Row(
                          children: [
                            const Icon(Icons.space_dashboard_outlined, size: 18, color: AppTheme.gold),
                            const SizedBox(width: 12),
                            Text('${destinations[_index].label} /', style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                            const SizedBox(width: 8),
                            const Text('积分社区', style: TextStyle(fontSize: 13)),
                            const Spacer(),
                            const Text('LOTTERY FORUM', style: TextStyle(color: AppTheme.muted, fontSize: 10, letterSpacing: 2)),
                          ],
                        ),
                      ),
                    Expanded(child: _pageFor(_index, landscapeReady)),
                  ],
                ),
              ),
            ],
          );
        },
      )),
    );
  }

  Widget _pageFor(int index, bool landscapeReady) {
    final loggedIn = _client.session.token != null;
    switch (index) {
      case 0:
        return HomePage(
          landscapeReady: landscapeReady,
          loggedIn: loggedIn,
          reader: ApiPointsReader(_client, includeEntries: false),
          feed: ApiHomeFeed(_client),
          onGoToAccount: () => setState(() => _index = 4),
          onGoToModerator: () => setState(() => _index = 3),
          onOpenPlay: (kind) => setState(() {
            _playKind = kind;
            _index = 1;
          }),
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
      default:
        return AccountPage(
          landscapeReady: landscapeReady,
          client: _client,
          onChanged: () => setState(() {}),
        );
    }
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
    return NavigationRail(
      key: const Key('primary-nav'),
      selectedIndex: selected,
      onDestinationSelected: onSelected,
      extended: !compact,
      minExtendedWidth: 196,
      labelType: compact
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.none,
      groupAlignment: -0.7,
      leading: compact
          ? const SizedBox(height: 24)
          : const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF343229),
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(13),
                      child: Icon(Icons.auto_awesome_outlined, color: AppTheme.gold, size: 28),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('彩票论坛', key: Key('brand-mark'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  SizedBox(height: 6),
                  Text('每一笔，都有迹可循', style: TextStyle(fontSize: 10, color: AppTheme.muted)),
                ],
              ),
            ),
      destinations: [
        for (final item in destinations)
          NavigationRailDestination(
            icon: Icon(item.icon),
            label: Text(item.label),
          ),
      ],
    );
  }
}
