import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/home_feed_api.dart';
import '../api/play_betting_api.dart';
import '../api/session.dart';
import '../design/app_theme.dart';
import '../pages/account_page.dart';
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
                if (landscapeReady) const VerticalDivider(width: 1),
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
          const Text(
            '彩友论坛',
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
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
    return NavigationRail(
      key: const Key('primary-nav'),
      selectedIndex: selected,
      onDestinationSelected: onSelected,
      extended: !compact,
      minExtendedWidth: 204,
      labelType: compact
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.none,
      groupAlignment: -0.72,
      leading: compact
          ? const Padding(
              padding: EdgeInsets.only(top: 14, bottom: 18),
              child: _CompactBrandMark(),
            )
          : const Padding(
              padding: EdgeInsets.fromLTRB(18, 20, 18, 30),
              child: _ExtendedBrandMark(),
            ),
      destinations: [
        for (final item in destinations)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.icon),
            label: Text(item.label),
          ),
      ],
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
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF332F27),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.gold.withOpacity(.3)),
          ),
          child: const Text(
            '彩',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '彩友论坛',
          key: Key('brand-mark'),
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
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
