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

PointsSnapshot snapshotFromApi({
  required Map<String, Object?> balance,
  required List<Map<String, Object?>> entries,
}) {
  return PointsSnapshot(
    balance: balance['balance'] as int,
    frozen: balance['frozen'] as int,
    entries: [
      for (final entry in entries) '${entry['direction']} ${entry['amount']} ${entry['reason']}',
    ],
    connected: true,
  );
}
