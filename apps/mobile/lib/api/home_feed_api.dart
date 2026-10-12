import '../pages/home_feed.dart';
import 'api_client.dart';
import 'api_exception.dart';

class ApiHomeFeed implements HomeFeed {
  ApiHomeFeed(this.client);

  final ApiClient client;

  @override
  Future<HomeFeedData> load() async {
    try {
      final bannersBody = await client.getJson('/api/v1/home/banners');
      final announcementsBody = await client.getJson('/api/v1/home/announcements');
      final bannerRows = bannersBody['banners'];
      final announcementRows = announcementsBody['announcements'];
      return HomeFeedData(
        banners: [
          for (final row in bannerRows is List ? bannerRows : const [])
            if (row is Map) bannerFromApi(Map<String, Object?>.from(row)),
        ],
        announcements: [
          for (final row in announcementRows is List ? announcementRows : const [])
            if (row is Map) announcementFromApi(Map<String, Object?>.from(row)),
        ],
      );
    } on ApiException {
      rethrow;
    }
  }

  @override
  Future<HomeAnnouncement> loadAnnouncement(String id) async {
    try {
      final body = await client.getJson('/api/v1/home/announcements/$id');
      return announcementFromApi(body);
    } on ApiException catch (error) {
      throw AnnouncementLoadException(
        messageForAnnouncementCode(error.code, error.message),
      );
    }
  }
}
