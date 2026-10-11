import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/play_betting.dart';
import 'package:lottery_forum/pages/play_center_page.dart';

class _FakeGateway implements PlayBettingGateway {
  _FakeGateway({required this.openFor, this.result});

  factory _FakeGateway.simple({OpenRound? open, BetResult? result}) {
    return _FakeGateway(
      openFor: {
        numberPickLotteryId: open,
        fujian31LotteryId: open,
      },
      result: result,
    );
  }

  final Map<String, OpenRound?> openFor;
  final BetResult? result;
  Map<String, Object?>? lastPayload;
  final List<String> lotteryQueries = <String>[];

  @override
  Future<OpenRound?> findOpenRound(String lotteryId) async {
    lotteryQueries.add(lotteryId);
    return openFor[lotteryId];
  }

  @override
  Future<BetResult> placeBet(Map<String, Object?> payload) async {
    lastPayload = payload;
    return result ??
        const BetResult(
          ok: true,
          message: '投注已受理，积分已冻结，结算后按结果派奖',
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

  test('fujian play helpers map ids and pick counts', () {
    expect(playIdFor(PlayKind.fujian31Any2), 'fujian-31-any-2');
    expect(playIdFor(PlayKind.fujian31Any5), 'fujian-31-any-5');
    expect(playIdFor(PlayKind.fujian31), 'fujian-31');
    expect(fujianPickCount(PlayKind.fujian31Any3), 3);
    expect(fujianPickCount(PlayKind.fujian31), 7);
    expect(lotteryIdFor(PlayKind.fujian31Any4), 'fujian-31');
  });

  testWidgets('no open round shows locked closed copy', (tester) async {
    await _pump(
      tester,
      PlayCenterPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: _FakeGateway.simple(open: null),
      ),
    );
    expect(find.text('当期已截止，无法投注'), findsOneWidget);
    expect(find.text('参与扣固定积分，不派奖'), findsNothing);
  });

  testWidgets('successful number-pick bet shows accepted message', (tester) async {
    final gateway = _FakeGateway.simple(
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
    expect(find.text('投注已受理，积分已冻结，结算后按结果派奖'), findsOneWidget);
    expect(gateway.lastPayload?['play_id'], 'number-pick');
    expect(gateway.lastPayload?['round_id'], 'r1');
    expect(gateway.lastPayload?['numbers'], [1, 2, 3]);
  });

  testWidgets('insufficient points shows locked copy', (tester) async {
    final gateway = _FakeGateway.simple(
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

  testWidgets('fujian-31 picks seven numbers and posts bets', (tester) async {
    final gateway = _FakeGateway(
      openFor: {
        numberPickLotteryId: null,
        fujian31LotteryId: const OpenRound(
          roundId: 'fj-open',
          lotteryId: 'fujian-31',
          code: 'fj-1',
        ),
      },
    );
    await _pump(
      tester,
      PlayCenterPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: gateway,
      ),
    );
    await tester.tap(find.byKey(const Key('play-game-fujian-31')));
    await tester.pumpAndSettle();
    expect(gateway.lotteryQueries, contains('fujian-31'));
    expect(find.byKey(const Key('fujian-number-grid')), findsOneWidget);
    for (final n in [1, 2, 3, 4, 5, 6, 7]) {
      await tester.tap(find.byKey(Key('fujian-n-$n')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('play-submit-bet')));
    await tester.pumpAndSettle();
    expect(find.text('投注已受理，积分已冻结，结算后按结果派奖'), findsOneWidget);
    expect(gateway.lastPayload?['play_id'], 'fujian-31');
    expect(gateway.lastPayload?['round_id'], 'fj-open');
    expect(gateway.lastPayload?['numbers'], [1, 2, 3, 4, 5, 6, 7]);
  });

  testWidgets('fujian-31-any-3 picks three numbers and posts bets', (tester) async {
    final gateway = _FakeGateway(
      openFor: {
        numberPickLotteryId: null,
        fujian31LotteryId: const OpenRound(
          roundId: 'fj-open',
          lotteryId: 'fujian-31',
          code: 'fj-1',
        ),
      },
    );
    await _pump(
      tester,
      PlayCenterPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: gateway,
      ),
    );
    expect(find.byKey(const Key('play-game-fujian-31-any-2')), findsOneWidget);
    expect(find.byKey(const Key('play-game-fujian-31-any-5')), findsOneWidget);
    await tester.tap(find.byKey(const Key('play-game-fujian-31-any-3')));
    await tester.pumpAndSettle();
    expect(find.text('福建31任选3'), findsWidgets);
    expect(find.textContaining('已选 0/3'), findsOneWidget);
    for (final n in [1, 2, 3]) {
      await tester.tap(find.byKey(Key('fujian-n-$n')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('已选 3/3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('play-submit-bet')));
    await tester.pumpAndSettle();
    expect(find.text('投注已受理，积分已冻结，结算后按结果派奖'), findsOneWidget);
    expect(gateway.lastPayload?['play_id'], 'fujian-31-any-3');
    expect(gateway.lastPayload?['numbers'], [1, 2, 3]);
  });
}
