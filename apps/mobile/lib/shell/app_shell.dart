import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/moderator_page.dart';
import '../pages/placeholder_page.dart';
import '../pages/play_center_page.dart';

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
        return HomePage(landscapeReady: landscapeReady);
      case 1:
        return PlayCenterPage(landscapeReady: landscapeReady);
      case 2:
        return const PlaceholderPage(
          title: '积分中心',
          detail: '积分账本已可查询本人余额，横屏明细页尚未接入。当前不提供充值、提现或用户间转账。',
        );
      case 3:
        return ModeratorPage(landscapeReady: landscapeReady);
      default:
        return const PlaceholderPage(
          title: '个人中心',
          detail: '账户资料与安全设置尚未实现。',
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
