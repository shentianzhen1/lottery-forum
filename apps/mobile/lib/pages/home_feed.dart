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

  String get publishedAtLabel => formatPublishedAt(publishedAt);
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 纯函数：按传入 DateTime 的字段格式化为 `yyyy-MM-dd HH:mm`。
String formatDateTimeMinute(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)} '
      '${_two(value.hour)}:${_two(value.minute)}';
}

/// 把 UTC ISO 字符串转本地时间再格式化；解析失败返回空串。
String formatPublishedAt(String iso, {DateTime Function(DateTime utc)? toLocal}) {
  if (iso.isEmpty) return '';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  final local = toLocal != null ? toLocal(parsed.toUtc()) : parsed.toLocal();
  return formatDateTimeMinute(local);
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
