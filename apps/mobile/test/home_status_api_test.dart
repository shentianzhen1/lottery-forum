import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/api_client.dart';
import 'package:lottery_forum/api/api_config.dart';
import 'package:lottery_forum/api/home_status_api.dart';
import 'package:lottery_forum/api/session.dart';

class _FakeClient extends ApiClient {
  _FakeClient({required bool loggedIn})
      : super(const ApiConfig(baseUrl: 'http://example.test'), Session()) {
    if (loggedIn) session.token = 'token';
  }

  final List<String> paths = [];

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    paths.add(path);
    if (path.startsWith('/api/v1/home/rounds/current')) {
      return {
        'round': {
          'lottery_id': 'fujian-31',
          'code': '2026282',
          'status': 'OPEN',
          'accepts_bets': true,
        },
      };
    }
    if (path == '/api/v1/rounds?lottery_id=fujian-31') {
      return {
        'rounds': [
          {
            'round_id': 'r-old',
            'lottery_id': 'fujian-31',
            'code': '2026281',
            'status': 'CLOSED',
          },
          {
            'round_id': 'r-current',
            'lottery_id': 'fujian-31',
            'code': '2026282',
            'status': 'OPEN',
          },
        ],
      };
    }
    if (path == '/api/v1/bets?round_id=r-current&status=ACCEPTED') {
      return {
        'items': [
          {'bet_id': 'b1'},
          {'bet_id': 'b2'},
        ],
      };
    }
    throw StateError('unexpected path: $path');
  }
}

void main() {
  test('logged-out home status only reads public round state', () async {
    final client = _FakeClient(loggedIn: false);
    final snapshot = await ApiHomeStatusReader(client).load();

    expect(snapshot.currentRound?.code, '2026282');
    expect(snapshot.currentRound?.statusLabel, '销售中');
    expect(snapshot.loggedIn, isFalse);
    expect(snapshot.currentAcceptedBets, isNull);
    expect(client.paths, hasLength(1));
  });

  test('logged-in home status counts accepted bets for current open round', () async {
    final client = _FakeClient(loggedIn: true);
    final snapshot = await ApiHomeStatusReader(client).load();

    expect(snapshot.loggedIn, isTrue);
    expect(snapshot.currentRound?.acceptsBets, isTrue);
    expect(snapshot.currentAcceptedBets, 2);
    expect(
      client.paths,
      contains('/api/v1/bets?round_id=r-current&status=ACCEPTED'),
    );
  });
}
