class PointsSnapshot {
  const PointsSnapshot({
    required this.balance,
    required this.frozen,
    required this.entries,
    required this.connected,
  });

  final int balance;
  final int frozen;
  final List<String> entries;
  final bool connected;

  int get available => balance - frozen;
}

abstract class PointsReader {
  Future<PointsSnapshot> load();
}

class DisconnectedPointsReader implements PointsReader {
  const DisconnectedPointsReader();

  @override
  Future<PointsSnapshot> load() async {
    return const PointsSnapshot(balance: 0, frozen: 0, entries: [], connected: false);
  }
}
