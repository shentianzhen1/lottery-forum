import '../pages/home_feed.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ApiHomeFeed implements HomeFeed {
  ApiHomeFeed(this.client);

  final ApiClient client;

  @override
  Future<HomeFeedData> load() async {
    final bannersBody = await client.getJson('/api/v1/home/banners');
    final announcementsBody = await client.getJson('/api/v1/home/announcements');
    final bannerRows = bannersBody['banners'];
    final announcementRows = announcementsBody['announcements'];

    List<HomeRecentDraw> recentDraws = const [];
    try {
      final drawsBody = await client.getJson(
        '/api/v1/home/draws/recent?lottery_id=fujian-31&limit=3',
      );
      final drawRows = drawsBody['items'];
      recentDraws = [
        for (final row in drawRows is List ? drawRows : const [])
          if (row is Map) recentDrawFromApi(Map<String, Object?>.from(row)),
      ];
    } on ApiException {
      // Home content remains useful when the optional recent-draw feed is unavailable.
      recentDraws = const [];
    }

    return HomeFeedData(
      banners: [
        for (final row in bannerRows is List ? bannerRows : const [])
          if (row is Map) bannerFromApi(Map<String, Object?>.from(row)),
      ],
      announcements: [
        for (final row in announcementRows is List ? announcementRows : const [])
          if (row is Map) announcementFromApi(Map<String, Object?>.from(row)),
      ],
      recentDraws: recentDraws,
    );
  }
}
