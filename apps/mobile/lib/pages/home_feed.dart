class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class HomeAnnouncement {
  const HomeAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    this.publishedAt = '',
  });

  final String id;
  final String title;
  final String body;
  final bool pinned;
  final String publishedAt;

  String get summary {
    final lines = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(2);
    return lines.join(' ');
  }

  String get publishedAtLabel {
    if (publishedAt.isEmpty) return '';
    return publishedAt.replaceFirst('T', ' ').replaceFirst(RegExp(r'Z$'), '');
  }
}

class HomeFeedData {
  const HomeFeedData({
    required this.banners,
    required this.announcements,
  });

  final List<HomeBanner> banners;
  final List<HomeAnnouncement> announcements;
}

abstract class HomeFeed {
  Future<HomeFeedData> load();
  Future<HomeAnnouncement> loadAnnouncement(String id);
}

class EmptyHomeFeed implements HomeFeed {
  const EmptyHomeFeed();

  @override
  Future<HomeFeedData> load() async {
    return const HomeFeedData(banners: [], announcements: []);
  }

  @override
  Future<HomeAnnouncement> loadAnnouncement(String id) async {
    throw const AnnouncementLoadException('公告不存在');
  }
}

class AnnouncementLoadException implements Exception {
  const AnnouncementLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

String messageForAnnouncementCode(String? code, String fallback) {
  switch (code) {
    case 'ANNOUNCEMENT_NOT_FOUND':
      return '公告不存在';
    default:
      return fallback.isEmpty ? '读取失败' : fallback;
  }
}

HomeBanner bannerFromApi(Map<String, Object?> row) {
  return HomeBanner(
    id: '${row['id']}',
    title: '${row['title'] ?? ''}',
    subtitle: '${row['subtitle'] ?? ''}',
  );
}

HomeAnnouncement announcementFromApi(Map<String, Object?> row) {
  return HomeAnnouncement(
    id: '${row['id']}',
    title: '${row['title'] ?? ''}',
    body: '${row['body'] ?? ''}',
    pinned: row['pinned'] == true,
    publishedAt: '${row['published_at'] ?? ''}',
  );
}
