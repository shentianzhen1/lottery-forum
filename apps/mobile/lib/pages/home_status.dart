class HomeCurrentRound {
  const HomeCurrentRound({
    required this.lotteryId,
    required this.code,
    required this.status,
    required this.acceptsBets,
  });

  final String lotteryId;
  final String code;
  final String status;
  final bool acceptsBets;

  String get statusLabel {
    switch (status) {
      case 'OPEN':
        return '销售中';
      case 'CLOSED':
        return '已截止';
      case 'DRAWN':
        return '已开奖';
      case 'SETTLING':
        return '结算中';
      case 'UPCOMING':
        return '即将开放';
      case 'SETTLED':
        return '已结算';
      default:
        return status.isEmpty ? '暂无状态' : status;
    }
  }
}

class HomeStatusSnapshot {
  const HomeStatusSnapshot({
    required this.currentRound,
    required this.loggedIn,
    this.currentAcceptedBets,
  });

  final HomeCurrentRound? currentRound;
  final bool loggedIn;
  final int? currentAcceptedBets;
}

abstract class HomeStatusReader {
  Future<HomeStatusSnapshot> load();
}

class EmptyHomeStatusReader implements HomeStatusReader {
  const EmptyHomeStatusReader({this.loggedIn = false});

  final bool loggedIn;

  @override
  Future<HomeStatusSnapshot> load() async {
    return HomeStatusSnapshot(
      currentRound: null,
      loggedIn: loggedIn,
      currentAcceptedBets: loggedIn ? 0 : null,
    );
  }
}

HomeCurrentRound? homeCurrentRoundFromApi(Object? value) {
  if (value is! Map) return null;
  final row = Map<String, Object?>.from(value);
  return HomeCurrentRound(
    lotteryId: '${row['lottery_id'] ?? ''}',
    code: '${row['code'] ?? ''}',
    status: '${row['status'] ?? ''}',
    acceptsBets: row['accepts_bets'] == true,
  );
}
