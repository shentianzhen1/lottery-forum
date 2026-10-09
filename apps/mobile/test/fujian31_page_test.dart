import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/fujian31_page.dart';

void main() {
  testWidgets('landscape Fujian page keeps numbers and result apart', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Fujian31Page(landscapeReady: true)),
    );
    expect(find.byKey(const Key('fujian-landscape-columns')), findsOneWidget);
    expect(find.byKey(const Key('fujian-number-31')), findsOneWidget);
    expect(find.text('已选 1 2 3 7 8 9 31'), findsOneWidget);
    expect(find.text('21 对'), findsOneWidget);
    expect(find.text('不扣分，不开奖，不派奖。'), findsOneWidget);
  });

  testWidgets('narrow Fujian page does not pretend to be landscape', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Fujian31Page(landscapeReady: false)),
    );
    expect(find.byKey(const Key('fujian-landscape-required')), findsOneWidget);
    expect(find.byKey(const Key('fujian-landscape-columns')), findsNothing);
  });
}
