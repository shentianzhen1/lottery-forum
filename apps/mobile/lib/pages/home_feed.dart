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

class HomeRecentDraw {
  const HomeRecentDraw({
    required this.lotteryId,
    required this.code,
    required this.drawDate,
    required this.mainNumbers,
    required this.extraNumbers,
  });

  final String lotteryId;
  final String code;
  final String drawDate;
  final List<int> mainNumbers;
  final List<int> extraNumbers;
}

class HomeFeedData {
  const HomeFeedData({
    required this.banners,
    required this.announcements,
    this.recentDraws = const [],
  });

  final List<HomeBanner> banners;
  final List<HomeAnnouncement> announcements;
  final List<HomeRecentDraw> recentDraws;
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

HomeRecentDraw recentDrawFromApi(Map<String, Object?> row) {
  List<int> numbers(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is int && item is! bool) item,
    ];
  }

  return HomeRecentDraw(
    lotteryId: '${row['lottery_id'] ?? ''}',
    code: '${row['normalized_code'] ?? ''}',
    drawDate: '${row['draw_date'] ?? ''}',
    mainNumbers: numbers(row['main_numbers']),
    extraNumbers: numbers(row['extra_numbers']),
  );
}
