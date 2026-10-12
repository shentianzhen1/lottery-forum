import '../pages/play_betting.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ApiPlayBettingGateway implements PlayBettingGateway {
  ApiPlayBettingGateway(this.client);

  final ApiClient client;

  @override
  Future<OpenRound?> findOpenRound(String lotteryId) async {
    final body = await client.getJson('/api/v1/rounds?lottery_id=$lotteryId');
    final rows = body['rounds'];
    if (rows is! List) return null;
    for (final row in rows) {
      if (row is! Map) continue;
      if (row['status']?.toString() != 'OPEN') continue;
      return OpenRound(
        roundId: '${row['round_id']}',
        lotteryId: '${row['lottery_id']}',
        code: '${row['code'] ?? ''}',
      );
    }
    return null;
  }

  @override
  Future<BetResult> placeBet(Map<String, Object?> payload) async {
    try {
      final body = await client.postJson('/api/v1/bets', payload);
      return BetResult(
        ok: true,
        message: body['message']?.toString() ?? '投注已受理，积分已冻结，结算后按结果派奖',
        betId: body['bet_id']?.toString(),
        status: body['status']?.toString(),
      );
    } on ApiException catch (error) {
      return BetResult(
        ok: false,
        code: error.code,
        message: messageForBetCode(error.code, error.message),
      );
    }
  }

  @override
  Future<List<AcceptedBet>> listAcceptedBets(String roundId) async {
    final body = await client.getJson(
      '/api/v1/bets?round_id=${Uri.encodeQueryComponent(roundId)}&status=ACCEPTED',
    );
    final rows = body['items'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map) _parseAcceptedBet(Map<String, Object?>.from(row)),
    ];
  }

  @override
  Future<BetResult> cancelBet(String betId) async {
    try {
      final body = await client.postJson('/api/v1/bets/$betId/cancel', const {});
      return BetResult(
        ok: true,
        message: body['message']?.toString() ?? '投注已取消，积分已解冻',
        betId: body['bet_id']?.toString() ?? betId,
        status: body['status']?.toString() ?? 'CANCELLED',
      );
    } on ApiException catch (error) {
      return BetResult(
        ok: false,
        code: error.code,
        message: messageForBetCode(error.code, error.message),
      );
    }
  }

  AcceptedBet _parseAcceptedBet(Map<String, Object?> row) {
    final rawNumbers = row['numbers'];
    final numbers = <int>[];
    if (rawNumbers is List) {
      for (final n in rawNumbers) {
        if (n is int) {
          numbers.add(n);
        } else if (n is num) {
          numbers.add(n.toInt());
        } else {
          final parsed = int.tryParse('$n');
          if (parsed != null) numbers.add(parsed);
        }
      }
    }
    final stakeRaw = row['stake'];
    final stake = stakeRaw is int
        ? stakeRaw
        : stakeRaw is num
            ? stakeRaw.toInt()
            : int.tryParse('${stakeRaw ?? 0}') ?? 0;
    return AcceptedBet(
      betId: '${row['bet_id']}',
      playId: '${row['play_id'] ?? ''}',
      numbers: numbers,
      stake: stake,
      status: '${row['status'] ?? 'ACCEPTED'}',
    );
  }
}
