import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/home_feed.dart';
import 'package:lottery_forum/pages/home_page.dart';

class _FakeHomeFeed implements HomeFeed {
  _FakeHomeFeed(this.data);

  final HomeFeedData data;

  @override
  Future<HomeFeedData> load() async => data;

  @override
  Future<HomeAnnouncement> loadAnnouncement(String id) async {
    throw const AnnouncementLoadException('公告不存在');
  }
}

Future<void> _pumpHome(WidgetTester tester, HomeFeed feed) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(landscapeReady: true, feed: feed),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('announcement summary keeps first two non-empty lines', () {
    const item = HomeAnnouncement(
      id: 'a1',
      title: '标题',
      body: '第一行\n\n第二行\n第三行',
      pinned: false,
    );
    expect(item.summary, '第一行 第二行');
  });

  testWidgets('empty feed shows 暂无公告 and no banner strip', (tester) async {
    await _pumpHome(tester, const EmptyHomeFeed());
    expect(find.text('平台公告'), findsOneWidget);
    expect(find.text('暂无公告'), findsOneWidget);
    expect(find.byKey(const Key('home-banner-strip')), findsNothing);
    expect(find.text('管理后台'), findsNothing);
  });

  testWidgets('populated feed shows banners and pinned announcement', (tester) async {
    await _pumpHome(
      tester,
      _FakeHomeFeed(
        const HomeFeedData(
          banners: [
            HomeBanner(id: 'b1', title: '横幅一', subtitle: '副文一'),
          ],
          announcements: [
            HomeAnnouncement(
              id: 'a1',
              title: '置顶公告',
              body: '摘要正文第一行\n第二行',
              pinned: true,
            ),
            HomeAnnouncement(
              id: 'a2',
              title: '普通公告',
              body: '普通摘要',
              pinned: false,
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('home-banner-strip')), findsOneWidget);
    expect(find.text('横幅一'), findsOneWidget);
    expect(find.text('副文一'), findsOneWidget);
    expect(find.text('暂无公告'), findsNothing);
    expect(find.text('置顶 · 置顶公告'), findsOneWidget);
    expect(find.text('摘要正文第一行 第二行'), findsOneWidget);
    expect(find.text('普通公告'), findsOneWidget);
    expect(find.text('管理后台'), findsNothing);
  });
}
