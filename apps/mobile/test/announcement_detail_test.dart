import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/announcement_detail_page.dart';
import 'package:lottery_forum/pages/home_feed.dart';
import 'package:lottery_forum/pages/home_page.dart';

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

  test('formats published_at for display', () {
    const item = HomeAnnouncement(
      id: 'a1',
      title: 't',
      body: 'b',
      pinned: false,
      publishedAt: '2026-10-12T12:00:00Z',
    );
    expect(item.publishedAtLabel, '2026-10-12 12:00:00');
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
    expect(find.text('2026-10-12 12:00:00'), findsOneWidget);
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
}
