class BetHistoryItem {
  const BetHistoryItem({
    required this.betId,
    required this.roundId,
    required this.playId,
    required this.numbers,
    required this.stake,
    required this.status,
    required this.createdAt,
  });

  final String betId;
  final String roundId;
  final String playId;
  final List<int> numbers;
  final int stake;
  final String status;
  final String createdAt;

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
  return BetHistoryItem(
    betId: '${row['bet_id'] ?? ''}',
    roundId: '${row['round_id'] ?? ''}',
    playId: '${row['play_id'] ?? ''}',
    numbers: numbers,
    stake: stake,
    status: '${row['status'] ?? ''}',
    createdAt: '${row['created_at'] ?? ''}',
  );
}
