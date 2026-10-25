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
  test('bet history parser keeps status, numbers and creation time', () {
    final item = betHistoryItemFromApi({
      'bet_id': 'b1',
      'round_id': 'r1',
      'play_id': 'fujian-31-any-3',
      'numbers': [1, 2, 3],
      'stake': 10,
      'status': 'CANCELLED',
      'created_at': '2026-10-25 12:34:56',
    });

    expect(item.statusLabel, '已取消');
    expect(item.numbersLabel, '1 2 3');
    expect(item.timeLabel, '2026-10-25 12:34');
    expect(item.active, isFalse);
  });

  testWidgets('history dialog filters active and finished bets', (tester) async {
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
                playId: 'fujian-31',
                numbers: [1, 2, 3, 4, 5, 6, 7],
                stake: 10,
                status: 'ACCEPTED',
                createdAt: '2026-10-25 12:00:00',
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
    expect(find.byKey(const Key('bet-history-cancelled')), findsOneWidget);

    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bet-history-active')), findsOneWidget);
    expect(find.byKey(const Key('bet-history-cancelled')), findsNothing);

    await tester.tap(find.text('已结束'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bet-history-active')), findsNothing);
    expect(find.byKey(const Key('bet-history-cancelled')), findsOneWidget);
  });
}
