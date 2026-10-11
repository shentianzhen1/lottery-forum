class OpenRound {
  const OpenRound({required this.roundId, required this.lotteryId, required this.code});

  final String roundId;
  final String lotteryId;
  final String code;
}

class BetResult {
  const BetResult({
    required this.ok,
    required this.message,
    this.code,
    this.betId,
    this.status,
  });

  final bool ok;
  final String message;
  final String? code;
  final String? betId;
  final String? status;
}

abstract class PlayBettingGateway {
  Future<OpenRound?> findOpenRound(String lotteryId);
  Future<BetResult> placeBet(Map<String, Object?> payload);
}

const numberPickPlayId = 'number-pick';
const numberPickRuleVersion = '0.1.0';
const numberPickLotteryId = 'demo-digit';

String messageForBetCode(String? code, String fallback) {
  switch (code) {
    case 'ROUND_CLOSED':
      return '当期已截止，无法投注';
    case 'INVALID_SELECTION':
      return '选号未通过校验';
    case 'INSUFFICIENT_POINTS':
      return '积分不足';
    case 'STAKE_DISABLED':
      return '该玩法尚未开放投注冻结';
    default:
      return fallback;
  }
}
