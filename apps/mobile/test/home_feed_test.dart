import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/pages/home_feed.dart';
import 'package:lottery_forum/pages/home_page.dart';

class _FakeHomeFeed implements HomeFeed {
  _FakeHomeFeed(this.data);

  final HomeFeedData data;

  @override
  Future<HomeFeedData> load() async => data;
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

  test('recent draw parser keeps integer number arrays', () {
    final item = recentDrawFromApi({
      'lottery_id': 'fujian-31',
      'normalized_code': '2026281',
      'draw_date': '2026-10-22',
      'main_numbers': [3, 10, 11, 12, 24, 25, 30],
      'extra_numbers': [22],
    });
    expect(item.code, '2026281');
    expect(item.mainNumbers, [3, 10, 11, 12, 24, 25, 30]);
    expect(item.extraNumbers, [22]);
  });

  testWidgets('empty feed shows empty announcement and confirmed draw states', (tester) async {
    await _pumpHome(tester, const EmptyHomeFeed());
    expect(find.text('平台公告'), findsOneWidget);
    expect(find.text('暂无公告'), findsOneWidget);
    expect(find.byKey(const Key('home-banner-strip')), findsNothing);
    expect(find.byKey(const Key('home-recent-draws')), findsOneWidget);
    expect(find.text('暂无已确认开奖'), findsOneWidget);
    expect(find.text('管理后台'), findsNothing);
  });

  testWidgets('home rotates announcements and banners and renders confirmed draws', (tester) async {
    await _pumpHome(
      tester,
      _FakeHomeFeed(
        const HomeFeedData(
          banners: [
            HomeBanner(id: 'b1', title: '横幅一', subtitle: '副文一'),
            HomeBanner(id: 'b2', title: '横幅二', subtitle: '副文二'),
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
          recentDraws: [
            HomeRecentDraw(
              lotteryId: 'fujian-31',
              code: '2026281',
              drawDate: '2026-10-22',
              mainNumbers: [3, 10, 11, 12, 24, 25, 30],
              extraNumbers: [22],
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('home-banner-strip')), findsOneWidget);
    expect(find.byKey(const Key('home-banner-dots')), findsOneWidget);
    expect(find.text('横幅一'), findsOneWidget);
    expect(find.text('置顶 · 置顶公告'), findsOneWidget);
    expect(find.text('普通公告'), findsNothing);
    expect(find.text('1/2'), findsOneWidget);

    expect(find.byKey(const Key('home-draw-2026281')), findsOneWidget);
    expect(find.text('福建31 · 2026281'), findsOneWidget);
    expect(find.text('03'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('暂无已确认开奖'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('普通公告'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('横幅二'), findsOneWidget);
  });
}
