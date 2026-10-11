import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/play_betting.dart';
import 'package:lottery_forum/pages/play_center_page.dart';

class _FakeGateway implements PlayBettingGateway {
  _FakeGateway({this.open, this.result});

  final OpenRound? open;
  final BetResult? result;
  Map<String, Object?>? lastPayload;

  @override
  Future<OpenRound?> findOpenRound(String lotteryId) async => open;

  @override
  Future<BetResult> placeBet(Map<String, Object?> payload) async {
    lastPayload = payload;
    return result ??
        const BetResult(
          ok: true,
          message: '投注已受理（积分已冻结占位，暂不派奖）',
          status: 'ACCEPTED',
          betId: 'bet-1',
        );
  }
}

Future<void> _pump(WidgetTester tester, PlayCenterPage page) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  test('maps bet error codes to locked Chinese copy', () {
    expect(messageForBetCode('ROUND_CLOSED', 'x'), '当期已截止，无法投注');
    expect(messageForBetCode('INVALID_SELECTION', 'x'), '选号未通过校验');
    expect(messageForBetCode('INSUFFICIENT_POINTS', 'x'), '积分不足');
  });

  testWidgets('no open round shows locked closed copy', (tester) async {
    await _pump(
      tester,
      PlayCenterPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: _FakeGateway(open: null),
      ),
    );
    expect(find.text('当期已截止，无法投注'), findsOneWidget);
    expect(find.text('参与扣固定积分，不派奖'), findsNothing);
  });

  testWidgets('successful bet shows accepted message', (tester) async {
    final gateway = _FakeGateway(
      open: const OpenRound(roundId: 'r1', lotteryId: 'demo-digit', code: 'demo'),
    );
    await _pump(
      tester,
      PlayCenterPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: gateway,
      ),
    );
    await tester.tap(find.byKey(const Key('play-submit-bet')));
    await tester.pumpAndSettle();
    expect(find.text('投注已受理（积分已冻结占位，暂不派奖）'), findsOneWidget);
    expect(gateway.lastPayload?['play_id'], 'number-pick');
    expect(gateway.lastPayload?['round_id'], 'r1');
    expect(gateway.lastPayload?['numbers'], [1, 2, 3]);
    expect(find.text('参与扣固定积分，不派奖'), findsNothing);
  });

  testWidgets('insufficient points shows locked copy', (tester) async {
    final gateway = _FakeGateway(
      open: const OpenRound(roundId: 'r1', lotteryId: 'demo-digit', code: 'demo'),
      result: const BetResult(
        ok: false,
        code: 'INSUFFICIENT_POINTS',
        message: '积分不足',
      ),
    );
    await _pump(
      tester,
      PlayCenterPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: gateway,
      ),
    );
    await tester.tap(find.byKey(const Key('play-submit-bet')));
    await tester.pumpAndSettle();
    expect(find.text('积分不足'), findsOneWidget);
  });
}
