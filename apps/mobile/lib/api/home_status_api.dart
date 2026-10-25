import '../pages/home_status.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ApiHomeStatusReader implements HomeStatusReader {
  ApiHomeStatusReader(this.client);

  final ApiClient client;

  @override
  Future<HomeStatusSnapshot> load() async {
    HomeCurrentRound? currentRound;
    try {
      final body = await client.getJson(
        '/api/v1/home/rounds/current?lottery_id=fujian-31',
      );
      currentRound = homeCurrentRoundFromApi(body['round']);
    } on ApiException {
      currentRound = null;
    }

    final loggedIn = client.session.token != null;
    if (!loggedIn) {
      return HomeStatusSnapshot(
        currentRound: currentRound,
        loggedIn: false,
      );
    }

    int? currentAcceptedBets;
    try {
      final roundsBody = await client.getJson('/api/v1/rounds?lottery_id=fujian-31');
      final rows = roundsBody['rounds'];
      String? openRoundId;
      if (rows is List) {
        for (final row in rows.reversed) {
          if (row is Map && row['status'] == 'OPEN') {
            openRoundId = '${row['round_id'] ?? ''}';
            if (openRoundId.isNotEmpty) break;
          }
        }
      }
      if (openRoundId == null || openRoundId.isEmpty) {
        currentAcceptedBets = 0;
      } else {
        final betsBody = await client.getJson(
          '/api/v1/bets?round_id=${Uri.encodeQueryComponent(openRoundId)}&status=ACCEPTED',
        );
        final items = betsBody['items'];
        currentAcceptedBets = items is List ? items.length : 0;
      }
    } on ApiException {
      currentAcceptedBets = null;
    }

    return HomeStatusSnapshot(
      currentRound: currentRound,
      loggedIn: true,
      currentAcceptedBets: currentAcceptedBets,
    );
  }
}
