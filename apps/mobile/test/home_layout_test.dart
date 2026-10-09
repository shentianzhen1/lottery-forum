import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/main.dart';

void main() {
  testWidgets('16:9 landscape home keeps three regions', (tester) async {
    await _pumpAt(tester, const Size(1920, 1080));
    expect(find.byKey(const Key('home-landscape-columns')), findsOneWidget);
    expect(find.text('热门玩法'), findsOneWidget);
    expect(find.text('申请版主'), findsOneWidget);
    expect(find.byKey(const Key('points-placeholder')), findsOneWidget);
    expect(find.text('请使用横屏查看首页'), findsNothing);
  });

  testWidgets('16:10 landscape home uses the same skeleton', (tester) async {
    await _pumpAt(tester, const Size(2560, 1600));
    expect(find.byKey(const Key('home-landscape-columns')), findsOneWidget);
    expect(find.text('数字选号'), findsOneWidget);
    expect(find.text('版主中心'), findsOneWidget);
  });

  testWidgets('narrow width does not pretend to be the landscape home', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(390, 844));
    expect(find.byKey(const Key('landscape-required')), findsOneWidget);
    expect(find.byKey(const Key('home-landscape-columns')), findsNothing);
  });

  testWidgets('selected destination survives rebuild', (tester) async {
    await _pumpAt(tester, const Size(1920, 1080));
    await tester.tap(find.text('版主中心'));
    await tester.pumpAndSettle();
    expect(find.text('审核流程未实现'), findsNothing);
    expect(find.text('申请版主、审核状态和权限记录尚未实现。'), findsOneWidget);
  });
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const LotteryForumApp());
  await tester.pumpAndSettle();
}
