class BetHistoryItem {
  const BetHistoryItem({
    required this.betId,
    required this.roundId,
    required this.playId,
    required this.numbers,
    required this.stake,
    required this.status,
    required this.createdAt,
    this.roundCode = '',
    this.settlementResult,
    this.settlementFinalized = false,
    this.settlementDelta,
    this.settlementReturn,
    this.settlementRecordedAt,
  });

  final String betId;
  final String roundId;
  final String roundCode;
  final String playId;
  final List<int> numbers;
  final int stake;
  final String status;
  final String createdAt;
  final String? settlementResult;
  final bool settlementFinalized;
  final int? settlementDelta;
  final int? settlementReturn;
  final String? settlementRecordedAt;

  String get numbersLabel => numbers.isEmpty ? '—' : numbers.join(' ');

  String get statusLabel {
    switch (status) {
      case 'ACCEPTED':
        return '已受理';
      case 'CANCELLED':
        return '已取消';
      case 'LOCKED':
        return '已锁定';
      case 'SETTLED':
        return '已结算';
      case 'REJECTED':
        return '已拒绝';
      case 'REFUNDED':
        return '已退回';
      case 'CREATED':
        return '已创建';
      default:
        return status;
    }
  }

  String? get resultLabel {
    switch (settlementResult) {
      case 'WIN':
        return '中奖';
      case 'LOSS':
        return '未中';
      case 'VOID':
        return '退回';
      default:
        return null;
    }
  }

  String get displayStatusLabel {
    final result = resultLabel;
    if (result == null) return statusLabel;
    return settlementFinalized ? result : '$result · 待入账';
  }

  String? get settlementSummaryLabel {
    final result = settlementResult;
    if (result == null) return null;
    if (!settlementFinalized) return '结果已记录，等待结算入账';
    final delta = settlementDelta;
    final returned = settlementReturn;
    if (result == 'WIN') {
      final deltaText = delta == null ? '—' : '+$delta';
      final returnText = returned == null ? '—' : '$returned';
      return '净积分 $deltaText · 连本带利 $returnText';
    }
    if (result == 'LOSS') {
      final deltaText = delta == null ? '—' : '$delta';
      return '净积分 $deltaText';
    }
    if (result == 'VOID') {
      final returnText = returned == null ? '$stake' : '$returned';
      return '净积分 0 · 解冻 $returnText';
    }
    return null;
  }

  bool get active => status == 'ACCEPTED' || status == 'LOCKED' || status == 'CREATED';

  String get timeLabel {
    final value = createdAt.trim();
    if (value.isEmpty) return '时间未记录';
    return value.length > 16 ? value.substring(0, 16) : value;
  }
}

abstract class BetHistoryReader {
  Future<List<BetHistoryItem>> load();
}

BetHistoryItem betHistoryItemFromApi(Map<String, Object?> row) {
  final rawNumbers = row['numbers'];
  final numbers = <int>[];
  if (rawNumbers is List) {
    for (final value in rawNumbers) {
      if (value is int) {
        numbers.add(value);
      } else if (value is num) {
        numbers.add(value.toInt());
      } else {
        final parsed = int.tryParse('$value');
        if (parsed != null) numbers.add(parsed);
      }
    }
  }
  final rawStake = row['stake'];
  final stake = rawStake is int
      ? rawStake
      : rawStake is num
          ? rawStake.toInt()
          : int.tryParse('${rawStake ?? 0}') ?? 0;
  final rawDelta = row['settlement_delta'];
  final settlementDelta = rawDelta == null
      ? null
      : rawDelta is int
          ? rawDelta
          : rawDelta is num
              ? rawDelta.toInt()
              : int.tryParse('$rawDelta');
  final rawReturn = row['settlement_return'];
  final settlementReturn = rawReturn == null
      ? null
      : rawReturn is int
          ? rawReturn
          : rawReturn is num
              ? rawReturn.toInt()
              : int.tryParse('$rawReturn');
  final rawResult = row['settlement_result'];
  final rawRecordedAt = row['settlement_recorded_at'];
  return BetHistoryItem(
    betId: '${row['bet_id'] ?? ''}',
    roundId: '${row['round_id'] ?? ''}',
    roundCode: '${row['round_code'] ?? ''}',
    playId: '${row['play_id'] ?? ''}',
    numbers: numbers,
    stake: stake,
    status: '${row['status'] ?? ''}',
    createdAt: '${row['created_at'] ?? ''}',
    settlementResult: rawResult == null ? null : '$rawResult',
    settlementFinalized: row['settlement_finalized'] == true,
    settlementDelta: settlementDelta,
    settlementReturn: settlementReturn,
    settlementRecordedAt: rawRecordedAt == null ? null : '$rawRecordedAt',
  );
}
