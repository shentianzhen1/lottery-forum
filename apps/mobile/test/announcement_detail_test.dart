import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/announcement_detail_page.dart';
import 'package:lottery_forum/pages/home_feed.dart';
import 'package:lottery_forum/pages/home_page.dart';
import 'package:lottery_forum/shell/app_shell.dart';

class _FakeHomeFeed implements HomeFeed {
  _FakeHomeFeed({
    required this.data,
    this.detail,
    this.detailError,
  });

  final HomeFeedData data;
  final HomeAnnouncement? detail;
  final Object? detailError;
  final List<String> detailQueries = <String>[];

  @override
  Future<HomeFeedData> load() async => data;

  @override
  Future<HomeAnnouncement> loadAnnouncement(String id) async {
    detailQueries.add(id);
    if (detailError != null) {
      throw detailError!;
    }
    return detail ??
        HomeAnnouncement(
          id: id,
          title: '详情标题',
          body: '详情正文全文',
          pinned: true,
          publishedAt: '2026-10-12T12:00:00Z',
        );
  }
}

Future<void> _pumpDetail(
  WidgetTester tester,
  AnnouncementDetailPage page, {
  Size size = const Size(1920, 1080),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  test('maps announcement not found to Chinese copy', () {
    expect(messageForAnnouncementCode('ANNOUNCEMENT_NOT_FOUND', 'x'), '公告不存在');
  });

  test('formatDateTimeMinute pads to yyyy-MM-dd HH:mm', () {
    expect(formatDateTimeMinute(DateTime(2026, 1, 2, 3, 4, 59)), '2026-01-02 03:04');
    expect(formatDateTimeMinute(DateTime(2026, 10, 12, 23, 5)), '2026-10-12 23:05');
  });

  test('formatPublishedAt converts UTC to local via fixed offset (+8)', () {
    DateTime plus8(DateTime utc) {
      final shifted = utc.add(const Duration(hours: 8));
      return DateTime(shifted.year, shifted.month, shifted.day, shifted.hour, shifted.minute);
    }

    expect(formatPublishedAt('2026-10-12T04:05:00Z', toLocal: plus8), '2026-10-12 12:05');
    expect(formatPublishedAt('2026-10-12T20:30:00Z', toLocal: plus8), '2026-10-13 04:30');
    expect(formatPublishedAt(''), '');
    expect(formatPublishedAt('not-a-date'), '');
  });

  test('formatPublishedAt default path uses DateTime.toLocal', () {
    const iso = '2026-10-12T04:05:00Z';
    final expected = formatDateTimeMinute(DateTime.parse(iso).toLocal());
    expect(formatPublishedAt(iso), expected);
    const item = HomeAnnouncement(id: 'a', title: 't', body: 'b', pinned: false, publishedAt: iso);
    expect(item.publishedAtLabel, expected);
    expect(item.publishedAtLabel, isNot(contains('T')));
    expect(item.publishedAtLabel.length, 16);
  });

  testWidgets('narrow width blocks announcement detail', (tester) async {
    await _pumpDetail(
      tester,
      AnnouncementDetailPage(
        landscapeReady: false,
        announcementId: 'a1',
        feed: _FakeHomeFeed(
          data: const HomeFeedData(banners: [], announcements: []),
        ),
      ),
      size: const Size(800, 600),
    );
    expect(
      find.byKey(const Key('announcement-detail-landscape-required')),
      findsOneWidget,
    );
    expect(find.text('请使用横屏查看公告详情'), findsOneWidget);
    expect(find.byKey(const Key('announcement-detail-page')), findsNothing);
  });

  testWidgets('detail page shows title pinned time and body', (tester) async {
    final feed = _FakeHomeFeed(
      data: const HomeFeedData(banners: [], announcements: []),
      detail: const HomeAnnouncement(
        id: 'a1',
        title: '详情标题',
        body: '详情正文全文\n第二段',
        pinned: true,
        publishedAt: '2026-10-12T12:00:00Z',
      ),
    );
    await _pumpDetail(
      tester,
      AnnouncementDetailPage(
        landscapeReady: true,
        announcementId: 'a1',
        feed: feed,
      ),
    );
    expect(feed.detailQueries, ['a1']);
    expect(find.byKey(const Key('announcement-detail-title')), findsOneWidget);
    expect(find.text('详情标题'), findsOneWidget);
    expect(find.byKey(const Key('announcement-detail-pinned')), findsOneWidget);
    expect(find.text('置顶'), findsOneWidget);
    expect(
      find.text(formatPublishedAt('2026-10-12T12:00:00Z')),
      findsOneWidget,
    );
    expect(find.text('详情正文全文\n第二段'), findsOneWidget);
  });

  testWidgets('404 shows 公告不存在 without English code', (tester) async {
    final feed = _FakeHomeFeed(
      data: const HomeFeedData(banners: [], announcements: []),
      detailError: const AnnouncementLoadException('公告不存在'),
    );
    await _pumpDetail(
      tester,
      AnnouncementDetailPage(
        landscapeReady: true,
        announcementId: 'missing',
        feed: feed,
      ),
    );
    expect(find.text('公告不存在'), findsOneWidget);
    expect(find.byKey(const Key('announcement-detail-error')), findsOneWidget);
    expect(find.textContaining('ANNOUNCEMENT'), findsNothing);
  });

  testWidgets('home announcement row opens detail via callback', (tester) async {
    String? openedId;
    final feed = _FakeHomeFeed(
      data: const HomeFeedData(
        banners: [],
        announcements: [
          HomeAnnouncement(
            id: 'a9',
            title: '可点公告',
            body: '摘要一行',
            pinned: false,
            publishedAt: '2026-10-01T00:00:00Z',
          ),
        ],
      ),
    );
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          landscapeReady: true,
          feed: feed,
          onOpenAnnouncement: (id) => openedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('announcement-a9')));
    await tester.pumpAndSettle();
    expect(openedId, 'a9');
  });

  testWidgets('back button invokes onBack', (tester) async {
    var backed = false;
    await _pumpDetail(
      tester,
      AnnouncementDetailPage(
        landscapeReady: true,
        announcementId: 'a1',
        feed: _FakeHomeFeed(
          data: const HomeFeedData(banners: [], announcements: []),
        ),
        onBack: () => backed = true,
      ),
    );
    await tester.tap(find.byKey(const Key('announcement-detail-back')));
    await tester.pumpAndSettle();
    expect(backed, isTrue);
  });

  testWidgets('detail rebuild across rotation does not reload', (tester) async {
    final feed = _FakeHomeFeed(
      data: const HomeFeedData(banners: [], announcements: []),
    );
    Widget build(bool landscape) => MaterialApp(
          home: AnnouncementDetailPage(
            landscapeReady: landscape,
            announcementId: 'a1',
            feed: feed,
          ),
        );
    await _pumpDetail(tester, AnnouncementDetailPage(
      landscapeReady: true,
      announcementId: 'a1',
      feed: feed,
    ));
    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();
    expect(feed.detailQueries, ['a1']);
    expect(find.text('正在读取'), findsNothing);
    expect(find.text('详情标题'), findsOneWidget);
  });

  testWidgets('app shell reuses home feed so rotation keeps detail loaded',
      (tester) async {
    final feed = _FakeHomeFeed(
      data: const HomeFeedData(
        banners: [],
        announcements: [
          HomeAnnouncement(id: 'a7', title: '壳内公告', body: '摘要', pinned: false),
        ],
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: AppShell(homeFeed: feed)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('announcement-a7')));
    await tester.pumpAndSettle();
    expect(feed.detailQueries, ['a7']);

    tester.view.physicalSize = const Size(800, 1280);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pumpAndSettle();
    expect(feed.detailQueries, ['a7']);
    expect(find.byKey(const Key('announcement-detail-title')), findsOneWidget);
  });
}
