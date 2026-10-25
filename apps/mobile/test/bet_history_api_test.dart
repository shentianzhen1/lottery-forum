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
          'play_id': 'fujian-31-any-2',
          'numbers': [7, 8],
          'stake': 10,
          'status': 'SETTLED',
          'created_at': '2026-10-25 12:00:00',
        },
      ],
    };
  }
}

void main() {
  test('bet history reader loads current account bet list', () async {
    final client = _FakeClient();
    final items = await ApiBetHistoryReader(client).load();

    expect(client.requestedPath, '/api/v1/bets');
    expect(items, hasLength(1));
    expect(items.single.playId, 'fujian-31-any-2');
    expect(items.single.statusLabel, '已结算');
    expect(items.single.numbers, [7, 8]);
  });
}
