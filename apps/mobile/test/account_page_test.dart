import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/api_client.dart';
import 'package:lottery_forum/api/api_config.dart';
import 'package:lottery_forum/api/session.dart';
import 'package:lottery_forum/pages/account_page.dart';

ApiClient _client({String? token, String? username}) {
  final session = Session()
    ..token = token
    ..username = username;
  return ApiClient(const ApiConfig(baseUrl: 'http://example.test'), session);
}

Future<void> _pump(
  WidgetTester tester,
  AccountPage page, {
  Size size = const Size(1920, 1080),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: page),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('narrow width blocks the whole account page', (tester) async {
    await _pump(
      tester,
      AccountPage(
        landscapeReady: false,
        client: _client(),
        onChanged: () {},
      ),
      size: const Size(800, 600),
    );
    expect(find.byKey(const Key('account-landscape-required')), findsOneWidget);
    expect(find.text('请使用横屏查看个人中心'), findsOneWidget);
    expect(find.byKey(const Key('login-form')), findsNothing);
    expect(find.widgetWithText(FilledButton, '注册'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '登录'), findsNothing);
  });

  testWidgets('landscape shows login form when logged out', (tester) async {
    await _pump(
      tester,
      AccountPage(
        landscapeReady: true,
        client: _client(),
        onChanged: () {},
      ),
    );
    expect(find.byKey(const Key('login-form')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '注册'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '登录'), findsOneWidget);
    expect(find.byKey(const Key('account-landscape-required')), findsNothing);
  });

  testWidgets('landscape shows logged-in state without login form', (tester) async {
    await _pump(
      tester,
      AccountPage(
        landscapeReady: true,
        client: _client(token: 'tok', username: 'alice'),
        onChanged: () {},
      ),
    );
    expect(find.byKey(const Key('logged-in')), findsOneWidget);
    expect(find.text('已登录 alice'), findsOneWidget);
    expect(find.text('退出'), findsOneWidget);
    expect(find.byKey(const Key('login-form')), findsNothing);
    expect(find.byKey(const Key('account-landscape-required')), findsNothing);
  });

  testWidgets('narrow width hides logged-in content too', (tester) async {
    await _pump(
      tester,
      AccountPage(
        landscapeReady: false,
        client: _client(token: 'tok', username: 'alice'),
        onChanged: () {},
      ),
      size: const Size(800, 600),
    );
    expect(find.byKey(const Key('account-landscape-required')), findsOneWidget);
    expect(find.byKey(const Key('logged-in')), findsNothing);
    expect(find.text('退出'), findsNothing);
  });
}
