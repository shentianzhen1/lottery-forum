import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/bet_history.dart';
import 'package:lottery_forum/pages/bet_history_dialog.dart';

class _Reader implements BetHistoryReader {
  const _Reader(this.items);
  final List<BetHistoryItem> items;
  @override
  Future<List<BetHistoryItem>> load() async => items;
}

void main() {
  test('bet history parser keeps settlement and round summary', () {
    final item = betHistoryItemFromApi({
      'bet_id': 'b1',
      'round_id': 'r1',
      'round_code': '2026288',
      'play_id': 'fujian-31-any-3',
      'numbers': [1, 2, 3],
      'stake': 10,
      'status': 'SETTLED',
      'created_at': '2026-10-25 12:34:56',
      'settlement_result': 'WIN',
      'settlement_finalized': true,
      'settlement_delta': 10,
      'settlement_return': 20,
      'settlement_recorded_at': '2026-10-25 13:00:00',
    });

    expect(item.statusLabel, '已结算');
    expect(item.displayStatusLabel, '中奖');
    expect(item.numbersLabel, '1 2 3');
    expect(item.timeLabel, '2026-10-25 12:34');
    expect(item.roundCode, '2026288');
    expect(item.settlementSummaryLabel, '净积分 +10 · 连本带利 20');
    expect(item.active, isFalse);
  });

  test('recorded result does not pretend payout is finalized', () {
    final item = betHistoryItemFromApi({
      'bet_id': 'pending',
      'round_id': 'r2',
      'play_id': 'number-pick',
      'numbers': [1, 2, 3],
      'stake': 10,
      'status': 'ACCEPTED',
      'created_at': '2026-10-25 12:34:56',
      'settlement_result': 'WIN',
      'settlement_finalized': false,
      'settlement_delta': null,
      'settlement_return': null,
    });

    expect(item.displayStatusLabel, '中奖 · 待入账');
    expect(item.settlementSummaryLabel, '结果已记录，等待结算入账');
    expect(item.active, isTrue);
  });

  testWidgets('history dialog filters active and finished bets and shows settlement', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BetHistoryDialog(
            reader: _Reader([
              BetHistoryItem(
                betId: 'active',
                roundId: 'r1',
                roundCode: 'TEST-001',
                playId: 'fujian-31',
                numbers: [1, 2, 3, 4, 5, 6, 7],
                stake: 10,
                status: 'ACCEPTED',
                createdAt: '2026-10-25 12:00:00',
              ),
              BetHistoryItem(
                betId: 'settled',
                roundId: 'r-settled',
                roundCode: '2026288',
                playId: 'number-pick',
                numbers: [1, 2, 3],
                stake: 10,
                status: 'SETTLED',
                createdAt: '2026-10-24 13:00:00',
                settlementResult: 'WIN',
                settlementFinalized: true,
                settlementDelta: 10,
                settlementReturn: 20,
              ),
              BetHistoryItem(
                betId: 'cancelled',
                roundId: 'r0',
                playId: 'number-pick',
                numbers: [1, 2, 3],
                stake: 10,
                status: 'CANCELLED',
                createdAt: '2026-10-24 12:00:00',
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bet-history-active')), findsOneWidget);
    expect(find.byKey(const Key('bet-history-settled')), findsOneWidget);
    expect(find.byKey(const Key('bet-history-cancelled')), findsOneWidget);
    expect(find.text('净积分 +10 · 连本带利 20'), findsOneWidget);
    expect(find.textContaining('期号 2026288'), findsOneWidget);

    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bet-history-active')), findsOneWidget);
    expect(find.byKey(const Key('bet-history-settled')), findsNothing);
    expect(find.byKey(const Key('bet-history-cancelled')), findsNothing);

    await tester.tap(find.text('已结束'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bet-history-active')), findsNothing);
    expect(find.byKey(const Key('bet-history-settled')), findsOneWidget);
    expect(find.byKey(const Key('bet-history-cancelled')), findsOneWidget);
  });
}
