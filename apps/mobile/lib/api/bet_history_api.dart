import '../pages/bet_history.dart';
import 'api_client.dart';

class ApiBetHistoryReader implements BetHistoryReader {
  ApiBetHistoryReader(this.client);

  final ApiClient client;

  @override
  Future<List<BetHistoryItem>> load() async {
    final body = await client.getJson('/api/v1/bets');
    final rows = body['items'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map) betHistoryItemFromApi(Map<String, Object?>.from(row)),
    ];
  }
}
