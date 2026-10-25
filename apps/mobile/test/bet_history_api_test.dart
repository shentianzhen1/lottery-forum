import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/api_client.dart';
import 'package:lottery_forum/api/api_config.dart';
import 'package:lottery_forum/api/bet_history_api.dart';
import 'package:lottery_forum/api/session.dart';

class _FakeClient extends ApiClient {
  _FakeClient() : super(const ApiConfig(baseUrl: 'http://example.test'), Session());

  String? requestedPath;

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    requestedPath = path;
    return {
      'items': [
        {
          'bet_id': 'b1',
          'round_id': 'r1',
          'round_code': '2026288',
          'play_id': 'fujian-31-any-2',
          'numbers': [7, 8],
          'stake': 10,
          'status': 'SETTLED',
          'created_at': '2026-10-25 12:00:00',
          'settlement_result': 'LOSS',
          'settlement_finalized': true,
          'settlement_delta': -10,
          'settlement_return': 0,
        },
      ],
    };
  }
}

void main() {
  test('bet history reader loads current account settlement summary', () async {
    final client = _FakeClient();
    final items = await ApiBetHistoryReader(client).load();

    expect(client.requestedPath, '/api/v1/bets');
    expect(items, hasLength(1));
    expect(items.single.playId, 'fujian-31-any-2');
    expect(items.single.roundCode, '2026288');
    expect(items.single.displayStatusLabel, '未中');
    expect(items.single.settlementDelta, -10);
    expect(items.single.settlementReturn, 0);
    expect(items.single.numbers, [7, 8]);
  });
}
