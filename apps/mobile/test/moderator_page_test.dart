import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/api_exception.dart';
import 'package:lottery_forum/pages/moderator_page.dart';

class _FakeGateway implements ModeratorGateway {
  _FakeGateway({
    this.boards = const [],
    this.openError,
  });

  List<ModeratorBoard> boards;
  final ApiException? openError;
  int openCalls = 0;

  @override
  Future<int> loadThreshold() async => 10000;

  @override
  Future<List<ModeratorBoard>> loadMyBoards() async => boards;

  @override
  Future<ModeratorBoard> openBoard(String lotteryId) async {
    openCalls += 1;
    final error = openError;
    if (error != null) throw error;
    final board = ModeratorBoard(
      boardId: 'board-1',
      lotteryId: lotteryId,
      status: 'open',
    );
    boards = [board];
    return board;
  }
}

Future<void> _pump(WidgetTester tester, ModeratorPage page) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('logged-out moderator page asks for account', (tester) async {
    await _pump(
      tester,
      ModeratorPage(
        landscapeReady: true,
        loggedIn: false,
        gateway: _FakeGateway(),
      ),
    );
    expect(find.byKey(const Key('moderator-login-hint')), findsOneWidget);
    expect(find.text('申请审核'), findsNothing);
    expect(find.textContaining('赔付'), findsNothing);
  });

  testWidgets('logged-in page shows locked open copy and open button', (tester) async {
    await _pump(
      tester,
      ModeratorPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: _FakeGateway(),
      ),
    );
    expect(find.byKey(const Key('moderator-open-copy')), findsOneWidget);
    expect(
      find.text('达标即可开通（默认门槛 10000，开通时冻结），无需审核'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('moderator-open-button')), findsOneWidget);
    expect(find.text('申请审核'), findsNothing);
    expect(find.textContaining('赔付'), findsNothing);
  });

  testWidgets('insufficient points shows 积分不足', (tester) async {
    final gateway = _FakeGateway(
      openError: const ApiException('可用积分未达到版主门槛', code: 'INSUFFICIENT_POINTS'),
    );
    await _pump(
      tester,
      ModeratorPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: gateway,
      ),
    );
    await tester.tap(find.byKey(const Key('moderator-open-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moderator-insufficient')), findsOneWidget);
    expect(find.text('积分不足'), findsOneWidget);
    expect(gateway.openCalls, 1);
  });

  testWidgets('already opened board shows status', (tester) async {
    await _pump(
      tester,
      ModeratorPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: _FakeGateway(
          boards: const [
            ModeratorBoard(boardId: 'b1', lotteryId: 'fujian-31', status: 'open'),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('moderator-opened-status')), findsOneWidget);
    expect(find.textContaining('已开通'), findsWidgets);
    expect(find.byKey(const Key('moderator-open-button')), findsNothing);
  });

  testWidgets('successful open shows opened status', (tester) async {
    final gateway = _FakeGateway();
    await _pump(
      tester,
      ModeratorPage(
        landscapeReady: true,
        loggedIn: true,
        gateway: gateway,
      ),
    );
    await tester.tap(find.byKey(const Key('moderator-open-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moderator-opened-status')), findsOneWidget);
    expect(find.byKey(const Key('moderator-open-success')), findsOneWidget);
    expect(gateway.openCalls, 1);
  });
}
