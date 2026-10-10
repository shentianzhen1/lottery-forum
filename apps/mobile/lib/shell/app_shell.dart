import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/session.dart';
import '../pages/account_page.dart';
import '../pages/home_page.dart';
import '../pages/placeholder_page.dart';
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
  final _client = ApiClient(const ApiConfig(), Session());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscapeReady = constraints.maxWidth >= 960;
          return Row(
            children: [
              _NavRail(
                selected: _index,
                compact: !landscapeReady,
                onSelected: (index) => setState(() => _index = index),
              ),
              Expanded(child: _pageFor(_index, landscapeReady)),
            ],
          );
        },
      ),
    );
  }

  Widget _pageFor(int index, bool landscapeReady) {
    switch (index) {
      case 0:
        return HomePage(
          landscapeReady: landscapeReady,
          loggedIn: _client.session.token != null,
          reader: ApiPointsReader(_client, includeEntries: false),
          onGoToAccount: () => setState(() => _index = 4),
        );
      case 1:
        return PlayCenterPage(landscapeReady: landscapeReady);
      case 2:
        return PointsCenterPage(
          landscapeReady: landscapeReady,
          reader: ApiPointsReader(_client),
        );
      case 3:
        return const PlaceholderPage(
          title: '版主中心',
          detail: '达标即可开通，尚未接入开通入口。',
        );
      default:
        return AccountPage(client: _client, onChanged: () => setState(() {}));
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
      leading: compact
          ? const SizedBox(height: 24)
          : const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                '彩票论坛',
                key: Key('brand-mark'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
