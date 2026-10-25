import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/main.dart';

void main() {
  testWidgets('彩友论坛 brand and lottery badges render at compact landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LotteryForumApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('彩友论坛'), findsWidgets);
    expect(find.text('彩票论坛'), findsNothing);
    expect(find.byKey(const Key('home-landscape-columns')), findsOneWidget);
    expect(find.byKey(const Key('home-main-scroll')), findsOneWidget);
    expect(find.byKey(const Key('home-side-panel')), findsOneWidget);

    expect(find.text('热门彩种'), findsOneWidget);
    expect(find.text('(门)'), findsNothing);
    expect(find.byKey(const Key('home-game-number-pick-badge')), findsOneWidget);
    expect(find.byKey(const Key('home-game-fujian-31-badge')), findsOneWidget);
    expect(find.byKey(const Key('home-game-pailie-3-badge')), findsOneWidget);
    expect(find.byKey(const Key('home-game-kuaile-8-badge')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('P3'), findsOneWidget);
    expect(find.text('8+'), findsOneWidget);

    final numberCard = find.byKey(const Key('home-game-number-pick'));
    final fujianCard = find.byKey(const Key('home-game-fujian-31'));
    expect(find.descendant(of: numberCard, matching: find.byType(Icon)), findsNothing);
    expect(find.descendant(of: fujianCard, matching: find.byType(Icon)), findsNothing);
  });

  testWidgets('refreshed shell remains overflow-free at 1366 landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LotteryForumApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('brand-mark')), findsOneWidget);
    expect(find.text('CAIYOU FORUM'), findsWidgets);
    expect(find.byKey(const Key('home-welcome-panel')), findsOneWidget);
    expect(find.byKey(const Key('home-game-pailie-3')), findsOneWidget);
    expect(find.byKey(const Key('home-game-kuaile-8')), findsOneWidget);

    for (final label in ['玩法中心', '积分中心', '版主中心', '个人中心']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });
}
