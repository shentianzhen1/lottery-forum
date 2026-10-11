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

enum PlayKind {
  numberPick,
  fujian31Any2,
  fujian31Any3,
  fujian31Any4,
  fujian31Any5,
  fujian31,
}

const numberPickPlayId = 'number-pick';
const numberPickRuleVersion = '0.1.0';
const numberPickLotteryId = 'demo-digit';

const fujian31RuleVersion = '0.1.0';
const fujian31LotteryId = 'fujian-31';
const fujian31PlayId = 'fujian-31';
const fujian31Any2PlayId = 'fujian-31-any-2';
const fujian31Any3PlayId = 'fujian-31-any-3';
const fujian31Any4PlayId = 'fujian-31-any-4';
const fujian31Any5PlayId = 'fujian-31-any-5';

bool isFujianKind(PlayKind kind) => kind != PlayKind.numberPick;

int fujianPickCount(PlayKind kind) {
  switch (kind) {
    case PlayKind.fujian31Any2:
      return 2;
    case PlayKind.fujian31Any3:
      return 3;
    case PlayKind.fujian31Any4:
      return 4;
    case PlayKind.fujian31Any5:
      return 5;
    case PlayKind.fujian31:
      return 7;
    case PlayKind.numberPick:
      throw ArgumentError('numberPick is not a fujian play');
  }
}

String playIdFor(PlayKind kind) {
  switch (kind) {
    case PlayKind.numberPick:
      return numberPickPlayId;
    case PlayKind.fujian31Any2:
      return fujian31Any2PlayId;
    case PlayKind.fujian31Any3:
      return fujian31Any3PlayId;
    case PlayKind.fujian31Any4:
      return fujian31Any4PlayId;
    case PlayKind.fujian31Any5:
      return fujian31Any5PlayId;
    case PlayKind.fujian31:
      return fujian31PlayId;
  }
}

String lotteryIdFor(PlayKind kind) =>
    isFujianKind(kind) ? fujian31LotteryId : numberPickLotteryId;

String ruleVersionFor(PlayKind kind) =>
    isFujianKind(kind) ? fujian31RuleVersion : numberPickRuleVersion;

String titleFor(PlayKind kind) {
  switch (kind) {
    case PlayKind.numberPick:
      return '数字选号';
    case PlayKind.fujian31Any2:
      return '福建31任选2';
    case PlayKind.fujian31Any3:
      return '福建31任选3';
    case PlayKind.fujian31Any4:
      return '福建31任选4';
    case PlayKind.fujian31Any5:
      return '福建31任选5';
    case PlayKind.fujian31:
      return '福建31选7';
  }
}

String subtitleFor(PlayKind kind) {
  if (kind == PlayKind.numberPick) {
    return '选择 3 个不重复数字，投注冻结占位';
  }
  final count = fujianPickCount(kind);
  return '选择 $count 个 1 到 31 的号码，投注冻结占位';
}

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
