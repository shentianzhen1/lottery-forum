import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/standalone_api_client.dart';

Future<StandaloneApiClient> _loggedInClient() async {
  final client = StandaloneApiClient();
  final auth = await client.postJson('/api/v1/auth/login', {
    'username': 'tester',
    'password': '123456',
  });
  client.session.token = auth['token'] as String?;
  client.session.username = auth['username'] as String?;
  return client;
}

Future<String> _placeFujianBet(StandaloneApiClient client) async {
  final rounds = await client.getJson('/api/v1/rounds?lottery_id=fujian-31');
  final round = (rounds['rounds'] as List).first as Map;
  final bet = await client.postJson('/api/v1/bets', {
    'round_id': round['round_id'],
    'play_id': 'fujian-31-any-2',
    'rule_version': 'v1',
    'numbers': [1, 2],
  });
  return bet['bet_id'] as String;
}

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

  test('standalone WIN settlement releases hold and credits profit', () async {
    final client = await _loggedInClient();
    final betId = await _placeFujianBet(client);

    await client.simulateSettlement(betId, 'WIN');

    final points = await client.getJson('/api/v1/points/balance');
    expect(points['balance'], 1010);
    expect(points['frozen'], 0);

    final bets = await client.getJson('/api/v1/bets');
    final row = (bets['items'] as List).first as Map;
    expect(row['status'], 'SETTLED');
    expect(row['round_code'], 'TEST-001');
    expect(row['settlement_result'], 'WIN');
    expect(row['settlement_finalized'], isTrue);
    expect(row['settlement_delta'], 10);
    expect(row['settlement_return'], 20);
    expect('${row['created_at']}', isNotEmpty);
    expect('${row['settlement_recorded_at']}', isNotEmpty);
  });

  test('standalone LOSS and VOID settlement match point semantics', () async {
    final lossClient = await _loggedInClient();
    final lossBetId = await _placeFujianBet(lossClient);
    await lossClient.simulateSettlement(lossBetId, 'LOSS');
    final lossPoints = await lossClient.getJson('/api/v1/points/balance');
    expect(lossPoints['balance'], 990);
    expect(lossPoints['frozen'], 0);
    final lossRow = ((await lossClient.getJson('/api/v1/bets'))['items'] as List).first as Map;
    expect(lossRow['settlement_delta'], -10);
    expect(lossRow['settlement_return'], 0);

    final voidClient = await _loggedInClient();
    final voidBetId = await _placeFujianBet(voidClient);
    await voidClient.simulateSettlement(voidBetId, 'VOID');
    final voidPoints = await voidClient.getJson('/api/v1/points/balance');
    expect(voidPoints['balance'], 1000);
    expect(voidPoints['frozen'], 0);
    final voidRow = ((await voidClient.getJson('/api/v1/bets'))['items'] as List).first as Map;
    expect(voidRow['settlement_delta'], 0);
    expect(voidRow['settlement_return'], 10);
  });

  test('standalone moderator opening is local and debits test points', () async {
    final client = await _loggedInClient();

    final board = await client.postJson('/api/v1/moderator/boards', {
      'lottery_id': 'fujian-31',
    });
    expect(board['status'], 'OPEN');

    final points = await client.getJson('/api/v1/points/balance');
    expect(points['balance'], 800);
  });
}
