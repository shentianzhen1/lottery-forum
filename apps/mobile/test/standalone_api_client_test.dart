import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lottery_forum/api/play_betting_api.dart';
import 'package:lottery_forum/pages/play_betting.dart';
import 'package:lottery_forum/pages/play_center_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/standalone_api_client.dart';
import 'package:lottery_forum/api/standalone_state_store.dart';

class _MemoryStore implements StandaloneStateStore {
  String? raw;

  @override
  Future<Map<String, Object?>?> load() async {
    if (raw == null) return null;
    return Map<String, Object?>.from(jsonDecode(raw!) as Map);
  }

  @override
  Future<void> save(Map<String, Object?> state) async {
    raw = jsonEncode(state);
  }

  @override
  Future<void> clear() async {
    raw = null;
  }
}

Future<StandaloneApiClient> _loggedInClient({_MemoryStore? store}) async {
  final client = StandaloneApiClient(store: store ?? _MemoryStore());
  final auth = await client.postJson('/api/v1/auth/login', {
    'username': 'tester',
    'password': '123456',
  });
  await client.updateSession(
    token: auth['token'] as String?,
    username: auth['username'] as String?,
  );
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
  testWidgets('short landscape can place a 31选7 standalone bet', (tester) async {
    tester.view.physicalSize = const Size(512, 230);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = await _loggedInClient();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayCenterPage(
          landscapeReady: true,
          loggedIn: true,
          initialKind: PlayKind.fujian31,
          gateway: ApiPlayBettingGateway(client),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    for (var n = 1; n <= 7; n++) {
      final number = find.byKey(Key('fujian-n-$n'));
      await tester.ensureVisible(number);
      await tester.pumpAndSettle();
      await tester.tap(number);
      await tester.pumpAndSettle();
    }
    final submit = find.byKey(const Key('play-submit-bet')).hitTestable();
    expect(submit, findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final bets = await ApiPlayBettingGateway(client)
        .listAcceptedBets('standalone-fujian-31-round');
    expect(bets.single.numbersLabel, '1 2 3 4 5 6 7');
    expect(bets.single.stake, 10);
    expect(tester.takeException(), isNull);
  });

  test('standalone client supports login, points, bet and cancel offline', () async {
    final client = StandaloneApiClient(store: _MemoryStore());

    final auth = await client.postJson('/api/v1/auth/register', {
      'username': 'tester',
      'password': '123456',
    });
    await client.updateSession(
      token: auth['token'] as String?,
      username: auth['username'] as String?,
    );

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

  test('standalone state survives client recreation', () async {
    final store = _MemoryStore();
    final first = await _loggedInClient(store: store);
    final betId = await _placeFujianBet(first);
    await first.postJson('/api/v1/moderator/boards', {'lottery_id': 'fujian-31'});

    final restored = StandaloneApiClient(store: store);
    await restored.initialize();

    expect(restored.session.username, 'tester');
    expect(restored.session.token, 'standalone-token-tester');
    final points = await restored.getJson('/api/v1/points/balance');
    expect(points['balance'], 800);
    expect(points['frozen'], 10);
    final bets = await restored.getJson('/api/v1/bets');
    expect((bets['items'] as List).length, 1);
    expect(((bets['items'] as List).first as Map)['bet_id'], betId);
    final boards = await restored.getJson('/api/v1/moderator/boards/me');
    expect((boards['boards'] as List).length, 1);

    await restored.simulateSettlement(betId, 'WIN');
    final afterSettlement = StandaloneApiClient(store: store);
    await afterSettlement.initialize();
    final settledPoints = await afterSettlement.getJson('/api/v1/points/balance');
    expect(settledPoints['balance'], 810);
    expect(settledPoints['frozen'], 0);
    final settled = await afterSettlement.getJson('/api/v1/bets');
    final settledRow = (settled['items'] as List).first as Map;
    expect(settledRow['settlement_result'], 'WIN');
    expect(settledRow['settlement_delta'], 10);

    await afterSettlement.clearSession();
    final loggedOut = StandaloneApiClient(store: store);
    await loggedOut.initialize();
    expect(loggedOut.session.token, isNull);
    expect(loggedOut.session.username, isNull);
  });

  test('standalone reset clears persisted test data and restores defaults', () async {
    final store = _MemoryStore();
    final client = await _loggedInClient(store: store);
    final betId = await _placeFujianBet(client);
    await client.simulateSettlement(betId, 'LOSS');
    await client.postJson('/api/v1/moderator/boards', {'lottery_id': 'fujian-31'});
    expect(client.supportsLocalReset, isTrue);
    expect(store.raw, isNotNull);

    await client.resetLocalData();
    expect(client.session.token, isNull);
    expect(client.session.username, isNull);
    expect(store.raw, isNull);

    final fresh = StandaloneApiClient(store: store);
    await fresh.initialize();
    final auth = await fresh.postJson('/api/v1/auth/login', {
      'username': 'tester',
      'password': '123456',
    });
    await fresh.updateSession(
      token: auth['token'] as String?,
      username: auth['username'] as String?,
    );
    final points = await fresh.getJson('/api/v1/points/balance');
    expect(points['balance'], 1000);
    expect(points['frozen'], 0);
    expect(((await fresh.getJson('/api/v1/bets'))['items'] as List), isEmpty);
    expect(((await fresh.getJson('/api/v1/moderator/boards/me'))['boards'] as List), isEmpty);
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

  test('standalone forum exposes clearly labelled demo content', () async {
    final client = StandaloneApiClient(store: _MemoryStore());
    final home = await client.getJson('/api/v1/forum/home');
    final threads = home['latest_threads'] as List;

    expect(threads, isNotEmpty);
    expect(
      threads.every((thread) => (thread as Map)['tags'].contains('演示内容')),
      isTrue,
    );

    final search = await client.getJson('/api/v1/forum/threads?q=选号思路');
    expect((search['threads'] as List), isNotEmpty);
    final detail = await client.getJson('/api/v1/forum/threads/DEMO-THREAD-1');
    expect(detail['author_username'], '演示账号');
  });

  test('standalone forum posts and replies survive client recreation', () async {
    final store = _MemoryStore();
    final client = await _loggedInClient(store: store);
    final thread = await client.postJson('/api/v1/forum/threads', {
      'board_id': 'general',
      'title': '我的本机测试帖',
      'body': '这是一条由测试用户发布的本机内容。',
      'tags': ['本机测试'],
    });
    await client.postJson(
      '/api/v1/forum/threads/${thread['id']}/replies',
      {'body': '本机回复'},
    );

    final restored = StandaloneApiClient(store: store);
    await restored.initialize();
    final detail = await restored.getJson(
      '/api/v1/forum/threads/${thread['id']}',
    );
    expect(detail['title'], '我的本机测试帖');
    expect(detail['reply_count'], 1);
    expect((detail['replies'] as List).length, 1);
  });
}
