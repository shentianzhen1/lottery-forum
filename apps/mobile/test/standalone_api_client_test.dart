import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/standalone_api_client.dart';

void main() {
  test('standalone client supports login, points, bet and cancel offline', () async {
    final client = StandaloneApiClient();

    final auth = await client.postJson('/api/v1/auth/register', {
      'username': 'tester',
      'password': '123456',
    });
    client.session.token = auth['token'] as String?;
    client.session.username = auth['username'] as String?;

    var points = await client.getJson('/api/v1/points/balance');
    expect(points['balance'], 1000);
    expect(points['frozen'], 0);

    final rounds = await client.getJson('/api/v1/rounds?lottery_id=fujian-31');
    final round = (rounds['rounds'] as List).first as Map;
    expect(round['status'], 'OPEN');

    final bet = await client.postJson('/api/v1/bets', {
      'round_id': round['round_id'],
      'play_id': 'fujian-31-any-2',
      'rule_version': 'v1',
      'numbers': [1, 2],
    });
    expect(bet['status'], 'ACCEPTED');

    points = await client.getJson('/api/v1/points/balance');
    expect(points['frozen'], 10);

    final betId = bet['bet_id'] as String;
    final cancelled = await client.postJson('/api/v1/bets/$betId/cancel', const {});
    expect(cancelled['status'], 'CANCELLED');

    points = await client.getJson('/api/v1/points/balance');
    expect(points['frozen'], 0);
  });

  test('standalone moderator opening is local and debits test points', () async {
    final client = StandaloneApiClient();
    final auth = await client.postJson('/api/v1/auth/login', {
      'username': 'tester',
      'password': '123456',
    });
    client.session.token = auth['token'] as String?;

    final board = await client.postJson('/api/v1/moderator/boards', {
      'lottery_id': 'fujian-31',
    });
    expect(board['status'], 'OPEN');

    final points = await client.getJson('/api/v1/points/balance');
    expect(points['balance'], 800);
  });
}
