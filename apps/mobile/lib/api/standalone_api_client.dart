import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'session.dart';

class StandaloneApiClient extends ApiClient {
  StandaloneApiClient()
      : super(const ApiConfig(baseUrl: 'standalone://local'), Session());

  int _balance = 1000;
  int _frozen = 0;
  int _betSeq = 1;
  int _boardSeq = 1;
  final List<Map<String, Object?>> _entries = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _bets = <Map<String, Object?>>[];
  final List<Map<String, Object?>> _boards = <Map<String, Object?>>[];

  void _requireLogin() {
    if (session.token == null) {
      throw const ApiException('需要登录', code: 'UNAUTHORIZED');
    }
  }

  @override
  Future<Map<String, Object?>> getJson(String path) async {
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
              'body': '登录、积分、选号、投注、撤单与版主入口均在手机本地模拟。\n关闭 App 后本轮测试数据会重置。',
              'pinned': true,
            },
          ],
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
            for (final bet in _bets)
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
        'play_id': '${body['play_id'] ?? ''}',
        'numbers': numbers,
        'stake': stake,
        'status': 'ACCEPTED',
      };
      _bets.add(row);
      _frozen += stake;
      _entries.add({
        'direction': 'HOLD',
        'amount': stake,
        'reason': '单机投注 $betId',
      });
      return {
        'bet_id': betId,
        'status': 'ACCEPTED',
        'message': '单机投注已受理，10 积分已冻结',
      };
    }

    if (uri.path.startsWith('/api/v1/bets/') && uri.path.endsWith('/cancel')) {
      final parts = uri.pathSegments;
      final betId = parts.length >= 4 ? parts[3] : '';
      Map<String, Object?>? found;
      for (final bet in _bets) {
        if (bet['bet_id'] == betId) {
          found = bet;
          break;
        }
      }
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
      return Map<String, Object?>.from(board);
    }

    throw ApiException('单机模式未实现接口：${uri.path}', code: 'NOT_IMPLEMENTED');
  }
}
