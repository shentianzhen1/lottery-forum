import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/play_betting.dart';
import 'package:lottery_forum/pages/play_center_page.dart';

class _FakeGateway implements PlayBettingGateway {
  _FakeGateway({
    required this.openFor,
    this.result,
    this.cancelResult,
    List<AcceptedBet>? initialAccepted,
  }) : accepted = List<AcceptedBet>.from(initialAccepted ?? const []);

  factory _FakeGateway.simple({
    OpenRound? open,
    BetResult? result,
    BetResult? cancelResult,
    List<AcceptedBet>? initialAccepted,
  }) {
    return _FakeGateway(
      openFor: {
        numberPickLotteryId: open,
        fujian31LotteryId: open,
      },
      result: result,
      cancelResult: cancelResult,
      initialAccepted: initialAccepted,
    );
  }

  final Map<String, OpenRound?> openFor;
  final BetResult? result;
  BetResult? cancelResult;
  Map<String, Object?>? lastPayload;
  final List<String> lotteryQueries = <String>[];
  final List<AcceptedBet> accepted;
  final List<String> cancelCalls = <String>[];
  final List<String> listQueries = <String>[];

  @override
  Future<OpenRound?> findOpenRound(String lotteryId) async {
    lotteryQueries.add(lotteryId);
    return openFor[lotteryId];
  }

  @override
  Future<BetResult> placeBet(Map<String, Object?> payload) async {
    lastPayload = payload;
    final bet = result ??
        const BetResult(
          ok: true,
          message: '投注已受理，积分已冻结，结算后按结果派奖',
          status: 'ACCEPTED',
          betId: 'bet-1',
        );
    if (bet.ok && bet.betId != null) {
      final numbers = <int>[];
      final raw = payload['numbers'];
      if (raw is List) {
        for (final n in raw) {
          if (n is int) numbers.add(n);
        }
      }
      accepted.insert(
        0,
        AcceptedBet(
          betId: bet.betId!,
          playId: '${payload['play_id'] ?? ''}',
          numbers: numbers,
          stake: 10,
          status: 'ACCEPTED',
        ),
      );
    }
    return bet;
  }

  @override
  Future<List<AcceptedBet>> listAcceptedBets(String roundId) async {
    listQueries.add(roundId);
    return List<AcceptedBet>.from(accepted);
  }

  @override
  Future<BetResult> cancelBet(String betId) async {
    cancelCalls.add(betId);
    final outcome = cancelResult ??
        BetResult(
          ok: true,
          message: '投注已取消，积分已解冻',
          betId: betId,
          status: 'CANCELLED',
        );
    if (outcome.ok) {
      accepted.removeWhere((b) => b.betId == betId);
    }
    return outcome;
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
    expect(messageForBetCode('BET_NOT_CANCELLABLE', 'x'), '当前投注无法取消');
    expect(messageForBetCode('BET_NOT_FOUND', 'x'), '投注不存在');
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
    expect(find.text('销售中才可取消本期投注'), findsOneWidget);
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
    expect(find.byKey(const Key('play-cancel-last-bet')), findsOneWidget);
    expect(find.byKey(const Key('play-cancellable-item-bet-1')), findsOneWidget);
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

  testWidgets('cancellable list shows accepted bets for open round', (tester) async {
    final gateway = _FakeGateway.simple(
      open: const OpenRound(roundId: 'r1', lotteryId: 'demo-digit', code: 'demo'),
      initialAccepted: const [
        AcceptedBet(
          betId: 'bet-a',
          playId: 'number-pick',
          numbers: [1, 2, 3],
          stake: 10,
          status: 'ACCEPTED',
        ),
      ],
    );
    await _pump(
      tester,
      PlayCenterPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: gateway,
      ),
    );
    expect(gateway.listQueries, contains('r1'));
    expect(find.byKey(const Key('play-cancellable-list')), findsOneWidget);
    expect(find.byKey(const Key('play-cancellable-item-bet-a')), findsOneWidget);
    expect(find.textContaining('选号 1 2 3'), findsOneWidget);
    expect(find.textContaining('注额 10'), findsOneWidget);
  });

  testWidgets('cancel from result bar shows success copy and refreshes list',
      (tester) async {
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
    expect(find.byKey(const Key('play-cancellable-item-bet-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('play-cancel-last-bet')));
    await tester.pumpAndSettle();
    expect(gateway.cancelCalls, ['bet-1']);
    expect(find.text('投注已取消，积分已解冻'), findsOneWidget);
    expect(find.byKey(const Key('play-cancellable-item-bet-1')), findsNothing);
    expect(find.byKey(const Key('play-cancellable-empty')), findsOneWidget);
    expect(find.byKey(const Key('play-cancel-last-bet')), findsNothing);
  });

  testWidgets('cancel from list shows not-cancellable copy', (tester) async {
    final gateway = _FakeGateway.simple(
      open: const OpenRound(roundId: 'r1', lotteryId: 'demo-digit', code: 'demo'),
      initialAccepted: const [
        AcceptedBet(
          betId: 'bet-x',
          playId: 'number-pick',
          numbers: [4, 5, 6],
          stake: 10,
          status: 'ACCEPTED',
        ),
      ],
      cancelResult: const BetResult(
        ok: false,
        code: 'BET_NOT_CANCELLABLE',
        message: '当前投注无法取消',
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
    await tester.tap(find.byKey(const Key('play-cancel-bet-bet-x')));
    await tester.pumpAndSettle();
    expect(gateway.cancelCalls, ['bet-x']);
    expect(find.text('当前投注无法取消'), findsOneWidget);
    expect(find.byKey(const Key('play-cancellable-item-bet-x')), findsOneWidget);
  });
}
