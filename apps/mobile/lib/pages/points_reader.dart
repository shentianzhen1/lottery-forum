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

class PointsLoadException implements Exception {
  const PointsLoadException(this.message);

  final String message;
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

int readPointsField(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw PointsLoadException('积分字段 $key 缺失或不是整数');
}

PointsSnapshot snapshotFromApi({
  required Map<String, Object?> balance,
  required List<Map<String, Object?>> entries,
}) {
  return PointsSnapshot(
    balance: readPointsField(balance, 'balance'),
    frozen: readPointsField(balance, 'frozen'),
    entries: [
      for (final entry in entries)
        '${entry['direction']} ${readPointsField(entry, 'amount')} ${entry['reason']}',
    ],
    connected: true,
  );
}