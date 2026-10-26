import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'session.dart';
import 'standalone_state_store.dart';

class StandaloneApiClient extends ApiClient {
  StandaloneApiClient({StandaloneStateStore? store})
      : _store = store ?? SharedPreferencesStandaloneStateStore(),
        super(const ApiConfig(baseUrl: 'standalone://local'), Session());

  final StandaloneStateStore _store;

  int _balance = 1000;
  int _frozen = 0;
  int _betSeq = 1;
  int _boardSeq = 1;
  final List<Map<String, Object?>> _entries = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _bets = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _boards = <Map<String, Object?>>[];

  bool _initialized = false;
  Future<void>? _initializing;

  @override
  bool get supportsLocalReset => true;

  Future<void> initialize() async {
    if (_initialized) return;
    final active = _initializing;
    if (active != null) return active;
    final future = _restore();
    _initializing = future;
    await future;
  }

  Future<void> _restore() async {
    try {
      final state = await _store.load();
      if (state == null || state['version'] != 1) return;
      _balance = _intValue(state['balance'], 1000);
      _frozen = _intValue(state['frozen'], 0);
      _betSeq = _intValue(state['bet_seq'], 1);
      _boardSeq = _intValue(state['board_seq'], 1);
      _replaceRows(_entries, state['entries']);
      _replaceRows(_bets, state['bets']);
      _replaceRows(_boards, state['boards']);
      session.token = state['token']?.toString();
      session.username = state['username']?.toString();
      if (session.token?.isEmpty ?? true) session.token = null;
      if (session.username?.isEmpty ?? true) session.username = null;
    } catch (_) {
      // Corrupt or unavailable local test storage must never stop the app from
      // starting; fall back to a fresh in-memory test state instead.
    } finally {
      _initialized = true;
      _initializing = null;
    }
  }

  Future<void> _persist() async {
    await _store.save({
      'version': 1,
      'balance': _balance,
      'frozen': _frozen,
      'bet_seq': _betSeq,
      'board_seq': _boardSeq,
      'entries': _entries,
      'bets': _bets,
      'boards': _boards,
      'token': session.token,
      'username': session.username,
    });
  }

  @override
  Future<void> updateSession({String? token, String? username}) async {
    await initialize();
    await super.updateSession(token: token, username: username);
    await _persist();
  }

  @override
  Future<void> clearSession() async {
    await initialize();
    await super.clearSession();
    await _persist();
  }

  @override
  Future<void> resetLocalData() async {
    await initialize();
    _balance = 1000;
    _frozen = 0;
    _betSeq = 1;
    _boardSeq = 1;
    _entries.clear();
    _bets.clear();
    _boards.clear();
    session.token = null;
    session.username = null;
    await _store.clear();
  }

  void _requireLogin() {
    if (session.token == null) {
      throw const ApiException('需要登录', code: 'UNAUTHORIZED');
    }
  }

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    await initialize();
    final uri = Uri.parse(path);
    switch (uri.path) {
      case '/api/v1/home/banners':
        return {
          'banners': [
            {
              'id': 'standalone-welcome',
              'title': '单机测试模式',
              'subtitle': '无需电脑或服务器，数据仅用于本机测试',
            },
          ],
        };
      case '/api/v1/home/announcements':
        return {
          'announcements': [
            {
              'id': 'standalone-note',
              'title': '当前为单机测试包',
              'body': '登录、积分、选号、投注、撤单、模拟结算与版主入口均在手机本地完成。\n关闭并重新打开 App 后测试数据仍会保留；可在个人中心重置单机测试数据。',
              'pinned': true,
            },
          ],
        };
      case '/api/v1/home/draws/recent':
        return {'items': <Map<String, Object?>>[]};
      case '/api/v1/home/rounds/current':
        return {
          'round': {
            'lottery_id': uri.queryParameters['lottery_id'] ?? 'fujian-31',
            'code': 'TEST-001',
            'status': 'OPEN',
            'accepts_bets': true,
          },
        };
      case '/api/v1/points/balance':
        _requireLogin();
        return {'balance': _balance, 'frozen': _frozen};
      case '/api/v1/points/entries':
        _requireLogin();
        return {'entries': List<Map<String, Object?>>.from(_entries.reversed)};
      case '/api/v1/rounds':
        _requireLogin();
        final lotteryId = uri.queryParameters['lottery_id'] ?? 'demo-digit';
        return {
          'rounds': [
            {
              'round_id': 'standalone-$lotteryId-round',
              'lottery_id': lotteryId,
              'code': 'TEST-001',
              'status': 'OPEN',
            },
          ],
        };
      case '/api/v1/bets':
        _requireLogin();
        final roundId = uri.queryParameters['round_id'];
        final status = uri.queryParameters['status'];
        return {
          'items': [
            for (final bet in _bets.reversed)
              if ((roundId == null || bet['round_id'] == roundId) &&
                  (status == null || bet['status'] == status))
                Map<String, Object?>.from(bet),
          ],
        };
      case '/api/v1/moderator/settings':
        _requireLogin();
        return {'threshold': 200};
      case '/api/v1/moderator/boards/me':
        _requireLogin();
        return {'boards': List<Map<String, Object?>>.from(_boards)};
      default:
        throw ApiException('单机模式未实现接口：${uri.path}', code: 'NOT_IMPLEMENTED');
    }
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    await initialize();
    final uri = Uri.parse(path);

    if (uri.path == '/api/v1/auth/login' || uri.path == '/api/v1/auth/register') {
      final username = '${body['username'] ?? ''}'.trim();
      final password = '${body['password'] ?? ''}';
      if (username.isEmpty || password.isEmpty) {
        throw const ApiException('用户名和密码不能为空', code: 'INVALID_CREDENTIALS');
      }
      final token = 'standalone-token-$username';
      return {'token': token, 'username': username};
    }

    _requireLogin();

    if (uri.path == '/api/v1/bets') {
      const stake = 10;
      if (_balance - _frozen < stake) {
        throw const ApiException('积分不足', code: 'INSUFFICIENT_POINTS');
      }
      final betId = 'LOCAL-BET-${_betSeq++}';
      final rawNumbers = body['numbers'];
      final numbers = rawNumbers is List
          ? rawNumbers.map((value) => int.tryParse('$value') ?? 0).toList()
          : <int>[];
      final row = <String, Object?>{
        'bet_id': betId,
        'round_id': '${body['round_id'] ?? ''}',
        'round_code': 'TEST-001',
        'play_id': '${body['play_id'] ?? ''}',
        'numbers': numbers,
        'stake': stake,
        'status': 'ACCEPTED',
        'created_at': DateTime.now().toIso8601String(),
        'settlement_result': null,
        'settlement_finalized': false,
        'settlement_delta': null,
        'settlement_return': null,
        'settlement_recorded_at': null,
      };
      _bets.add(row);
      _frozen += stake;
      _entries.add({
        'direction': 'HOLD',
        'amount': stake,
        'reason': '单机投注 $betId',
      });
      await _persist();
      return {
        'bet_id': betId,
        'status': 'ACCEPTED',
        'message': '单机投注已受理，10 积分已冻结',
      };
    }

    if (uri.path.startsWith('/api/v1/bets/') && uri.path.endsWith('/cancel')) {
      final parts = uri.pathSegments;
      final betId = parts.length >= 4 ? parts[3] : '';
      final found = _findBet(betId);
      if (found == null || found['status'] != 'ACCEPTED') {
        throw const ApiException('投注不可撤销', code: 'BET_NOT_CANCELLABLE');
      }
      final stake = found['stake'] as int? ?? 0;
      found['status'] = 'CANCELLED';
      _frozen -= stake;
      _entries.add({
        'direction': 'RELEASE',
        'amount': stake,
        'reason': '单机撤单 $betId',
      });
      await _persist();
      return {
        'bet_id': betId,
        'status': 'CANCELLED',
        'message': '单机投注已取消，积分已解冻',
      };
    }

    if (uri.path == '/api/v1/moderator/boards') {
      const threshold = 200;
      if (_balance - _frozen < threshold) {
        throw const ApiException('积分不足', code: 'INSUFFICIENT_POINTS');
      }
      final lotteryId = '${body['lottery_id'] ?? 'fujian-31'}';
      for (final board in _boards) {
        if (board['lottery_id'] == lotteryId) {
          return Map<String, Object?>.from(board);
        }
      }
      final board = <String, Object?>{
        'board_id': 'LOCAL-BOARD-${_boardSeq++}',
        'lottery_id': lotteryId,
        'status': 'OPEN',
      };
      _boards.add(board);
      _balance -= threshold;
      _entries.add({
        'direction': 'DEBIT',
        'amount': threshold,
        'reason': '单机版主开通',
      });
      await _persist();
      return Map<String, Object?>.from(board);
    }

    throw ApiException('单机模式未实现接口：${uri.path}', code: 'NOT_IMPLEMENTED');
  }

  Future<void> simulateSettlement(String betId, String result) async {
    await initialize();
    _requireLogin();
    if (result != 'WIN' && result != 'LOSS' && result != 'VOID') {
      throw const ApiException('模拟结算结果无效', code: 'INVALID_RESULT');
    }
    final bet = _findBet(betId);
    if (bet == null) {
      throw const ApiException('投注不存在', code: 'BET_NOT_FOUND');
    }
    if (bet['status'] != 'ACCEPTED' || bet['settlement_result'] != null) {
      throw const ApiException('当前投注不可模拟结算', code: 'BET_NOT_SETTLEABLE');
    }

    final stake = bet['stake'] as int? ?? 0;
    final now = DateTime.now().toIso8601String();
    var delta = 0;
    var returned = stake;

    _frozen -= stake;
    _entries.add({
      'direction': 'RELEASE',
      'amount': stake,
      'reason': '单机结算解冻 $betId',
    });

    if (result == 'WIN') {
      delta = stake;
      returned = stake * 2;
      _balance += stake;
      _entries.add({
        'direction': 'CREDIT',
        'amount': stake,
        'reason': '单机中奖盈利 $betId',
      });
    } else if (result == 'LOSS') {
      delta = -stake;
      returned = 0;
      _balance -= stake;
      _entries.add({
        'direction': 'DEBIT',
        'amount': stake,
        'reason': '单机未中扣除 $betId',
      });
    }

    bet['status'] = 'SETTLED';
    bet['settlement_result'] = result;
    bet['settlement_finalized'] = true;
    bet['settlement_delta'] = delta;
    bet['settlement_return'] = returned;
    bet['settlement_recorded_at'] = now;
    await _persist();
  }

  Map<String, Object?>? _findBet(String betId) {
    for (final bet in _bets) {
      if (bet['bet_id'] == betId) return bet;
    }
    return null;
  }
}

int _intValue(Object? value, int fallback) {
  if (value is int) return value;
  return int.tryParse('$value') ?? fallback;
}

void _replaceRows(List<Map<String, Object?>> target, Object? raw) {
  target.clear();
  if (raw is! List) return;
  for (final row in raw) {
    if (row is Map) target.add(Map<String, Object?>.from(row));
  }
}
