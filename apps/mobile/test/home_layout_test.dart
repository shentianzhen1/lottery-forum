import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/main.dart';
import 'package:lottery_forum/pages/home_page.dart';
import 'package:lottery_forum/pages/points_reader.dart';

class _FakeHomePointsReader implements PointsReader {
  @override
  Future<PointsSnapshot> load() async {
    return const PointsSnapshot(
      balance: 50,
      frozen: 20,
      entries: ['冻结 20'],
      connected: true,
    );
  }
}

void main() {
  testWidgets('16:9 landscape home keeps three regions', (tester) async {
    await _pumpAt(tester, const Size(1920, 1080));
    expect(find.byKey(const Key('home-landscape-columns')), findsOneWidget);
    expect(find.text('热门玩法'), findsOneWidget);
    expect(find.byKey(const Key('announcement-board')), findsOneWidget);
    expect(find.text('平台公告'), findsOneWidget);
    expect(find.text('暂无公告'), findsOneWidget);
    expect(find.text('开通版主'), findsOneWidget);
    expect(find.text('达标即可开通（默认门槛 10000，开通时冻结），无需审核'), findsOneWidget);
    expect(find.text('审核流程未实现'), findsNothing);
    expect(find.text('账本未实现'), findsNothing);
    expect(find.byKey(const Key('open-moderator')), findsOneWidget);
    expect(find.byKey(const Key('home-points-login-hint')), findsOneWidget);
    expect(find.text('去个人中心登录'), findsOneWidget);
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
    await tester.tap(find.text('积分中心'));
    await tester.pumpAndSettle();
    expect(find.text('审核流程未实现'), findsNothing);
    expect(find.byKey(const Key('points-load-error')), findsOneWidget);
    expect(find.text('需要登录'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('play center uses separate input and result panels', (tester) async {
    await _pumpAt(tester, const Size(1920, 1080));
    await tester.tap(find.text('玩法中心'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('play-landscape-columns')), findsOneWidget);
    expect(find.byKey(const Key('play-result-panel')), findsOneWidget);
    expect(find.text('参与扣固定积分，不派奖'), findsOneWidget);
  });

  testWidgets('logged-in home points card shows book balance', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          landscapeReady: true,
          loggedIn: true,
          reader: _FakeHomePointsReader(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('账本未实现'), findsNothing);
    expect(find.byKey(const Key('home-points-login-hint')), findsNothing);
    expect(find.byKey(const Key('home-points-balance')), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('账面余额'), findsOneWidget);
  });

  testWidgets('home points login hint opens account callback', (tester) async {
    var opened = false;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          landscapeReady: true,
          loggedIn: false,
          onGoToAccount: () => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-points-login-hint')));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
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
