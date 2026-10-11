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
  });

  final String id;
  final String title;
  final String body;
  final bool pinned;

  String get summary {
    final lines = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(2);
    return lines.join(' ');
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
}

class EmptyHomeFeed implements HomeFeed {
  const EmptyHomeFeed();

  @override
  Future<HomeFeedData> load() async {
    return const HomeFeedData(banners: [], announcements: []);
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
  );
}
