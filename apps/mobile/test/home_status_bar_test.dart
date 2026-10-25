import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/home_status.dart';
import 'package:lottery_forum/pages/home_status_bar.dart';

class _Reader implements HomeStatusReader {
  const _Reader(this.snapshot);

  final HomeStatusSnapshot snapshot;

  @override
  Future<HomeStatusSnapshot> load() async => snapshot;
}

void main() {
  testWidgets('shows open round and current accepted bet count', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeStatusBar(
            loggedIn: true,
            reader: const _Reader(
              HomeStatusSnapshot(
                loggedIn: true,
                currentAcceptedBets: 2,
                currentRound: HomeCurrentRound(
                  lotteryId: 'fujian-31',
                  code: '2026282',
                  status: 'OPEN',
                  acceptsBets: true,
                ),
              ),
            ),
            onOpenFujian31: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-current-round-card')), findsOneWidget);
    expect(find.text('2026282'), findsOneWidget);
    expect(find.text('销售中'), findsWidgets);
    expect(find.text('2 笔'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-my-bets-card')));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('logged-out my bets card opens account', (tester) async {
    var accountOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeStatusBar(
            loggedIn: false,
            reader: const _Reader(
              HomeStatusSnapshot(
                loggedIn: false,
                currentRound: HomeCurrentRound(
                  lotteryId: 'fujian-31',
                  code: '2026282',
                  status: 'OPEN',
                  acceptsBets: true,
                ),
              ),
            ),
            onGoToAccount: () => accountOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录后查看'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-my-bets-card')));
    await tester.pump();
    expect(accountOpened, isTrue);
  });
}
