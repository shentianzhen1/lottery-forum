import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/main.dart';

void main() {
  for (final size in [const Size(854, 480), const Size(800, 360)]) {
    testWidgets('scaled Android landscape adapts at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const LotteryForumApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('landscape-required')), findsNothing);
      expect(find.byKey(const Key('home-landscape-columns')), findsOneWidget);
      expect(find.byKey(const Key('primary-nav')), findsOneWidget);
      expect(find.byKey(const Key('nav-item-4')), findsOneWidget);
      expect(find.text('论坛'), findsNothing);
      expect(find.byKey(const Key('home-side-panel')), findsNothing);
      if (size.height < 520) {
        expect(find.byKey(const Key('workspace-title')), findsNothing);
      }
    });
  }

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
    expect(find.byKey(const Key('home-side-panel')), findsNothing);

    await tester.drag(find.byKey(const Key('home-main-scroll')), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('热门彩种'), findsOneWidget);
    expect(find.text('(门)'), findsNothing);
    expect(find.byKey(const Key('home-game-fujian-31-badge')), findsOneWidget);
    expect(find.byKey(const Key('home-game-fucai-3d-badge')), findsOneWidget);
    expect(find.byKey(const Key('home-game-pailie-5-badge')), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('P5'), findsOneWidget);

    final fucaiCard = find.byKey(const Key('home-game-fucai-3d'));
    final fujianCard = find.byKey(const Key('home-game-fujian-31'));
    expect(find.descendant(of: fucaiCard, matching: find.byType(Icon)), findsNothing);
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
    expect(find.byKey(const Key('home-game-pailie-5')), findsOneWidget);
    expect(find.byKey(const Key('home-game-fucai-3d')), findsOneWidget);

    for (final label in ['玩法中心', '积分中心', '版主中心', '个人中心']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });
}
