import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/points_center_page.dart';
import 'package:lottery_forum/pages/points_reader.dart';

class _FakeReader implements PointsReader {
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
  testWidgets('connected points center shows available balance', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PointsCenterPage(landscapeReady: true, reader: _FakeReader())),
    );
    await tester.pumpAndSettle();
    expect(find.text('账面余额 50'), findsOneWidget);
    expect(find.text('冻结 20'), findsWidgets);
    expect(find.text('可用余额 30'), findsOneWidget);
    expect(find.text('接口尚未接入此页'), findsNothing);
  });

  test('api payload maps frozen balance to available points', () {
    final snapshot = snapshotFromApi(
      balance: {'balance': 50, 'frozen': 20, 'available': 30},
      entries: [
        {'direction': 'credit', 'amount': 50, 'reason': 'opening_grant'},
      ],
    );
    expect(snapshot.available, 30);
    expect(snapshot.entries, ['credit 50 opening_grant']);
  });
}
