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
}
