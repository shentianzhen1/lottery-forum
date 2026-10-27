import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/api_client.dart';
import 'package:lottery_forum/api/api_config.dart';
import 'package:lottery_forum/api/forum_api.dart';
import 'package:lottery_forum/api/session.dart';
import 'package:lottery_forum/design/app_theme.dart';
import 'package:lottery_forum/pages/forum_center_page.dart';
import 'package:lottery_forum/pages/home_page.dart';

class _FakeForumClient extends ApiClient {
  _FakeForumClient({bool loggedIn = false}) : super(const ApiConfig(baseUrl: 'http://test'), Session()) {
    if (loggedIn) {
      session.token = 'token';
      session.username = 'tester';
    }
  }

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    final uri = Uri.parse(path);
    if (uri.path == '/api/v1/forum/home') {
      return {
        'boards': [
          {'id': 'general', 'title': '综合讨论', 'description': '综合交流', 'lottery_id': '', 'thread_count': 1},
          {'id': 'fujian31', 'title': '福建31', 'description': '福建31讨论', 'lottery_id': 'fujian-31', 'thread_count': 1},
        ],
        'hot_topics': [
          {'tag': '福建31讨论', 'thread_count': 1},
        ],
        'latest_threads': [
          {
            'id': 'thread-1',
            'board_id': 'fujian31',
            'board_title': '福建31',
            'author_username': 'tester',
            'title': '福建31 今日讨论',
            'body': '交流选号思路',
            'tags': ['福建31讨论'],
            'reply_count': 0,
            'created_at': '2026-10-27T10:00:00Z',
            'updated_at': '2026-10-27T10:00:00Z',
            'locked': false,
          },
        ],
      };
    }
    if (uri.path == '/api/v1/forum/threads') {
      return {
        'threads': [
          {
            'id': 'thread-1',
            'board_id': 'fujian31',
            'board_title': '福建31',
            'author_username': 'tester',
            'title': '福建31 今日讨论',
            'body': '交流选号思路',
            'tags': ['福建31讨论'],
            'reply_count': 0,
            'created_at': '2026-10-27T10:00:00Z',
            'updated_at': '2026-10-27T10:00:00Z',
            'locked': false,
          },
        ],
      };
    }
    if (uri.path == '/api/v1/forum/threads/thread-1') {
      return {
        'id': 'thread-1',
        'board_id': 'fujian31',
        'board_title': '福建31',
        'author_username': 'tester',
        'title': '福建31 今日讨论',
        'body': '交流选号思路',
        'tags': ['福建31讨论'],
        'reply_count': 0,
        'created_at': '2026-10-27T10:00:00Z',
        'updated_at': '2026-10-27T10:00:00Z',
        'locked': false,
        'replies': <Map<String, Object?>>[],
      };
    }
    return {};
  }
}

void main() {
  for (final size in [const Size(1024, 600), const Size(1366, 768)]) {
    testWidgets('home exposes forum at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var accountOpened = false;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: HomePage(
          landscapeReady: true,
          forumApi: ForumApi(_FakeForumClient()),
          onGoToAccount: () => accountOpened = true,
        )),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('热门话题'), findsOneWidget);
      expect(find.text('彩种分区'), findsOneWidget);
      expect(find.text('福建31 今日讨论'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-forum-publish')));
      expect(accountOpened, isTrue);
      await tester.tap(find.byKey(const Key('home-forum-search')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forum-search-field')), findsOneWidget);
    });
  }

  testWidgets('forum center renders real forum modules without overflow', (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ForumCenterPage(
          landscapeReady: true,
          loggedIn: true,
          api: ForumApi(_FakeForumClient(loggedIn: true)),
          onGoToAccount: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('forum-hero')), findsOneWidget);
    expect(find.text('热门话题'), findsOneWidget);
    expect(find.text('彩种分区'), findsOneWidget);
    expect(find.text('最新讨论'), findsOneWidget);
    expect(find.text('福建31 今日讨论'), findsOneWidget);
  });

  testWidgets('forum search opens and returns thread rows', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ForumCenterPage(
          landscapeReady: true,
          loggedIn: false,
          api: ForumApi(_FakeForumClient()),
          onGoToAccount: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-search-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-search-field')), findsOneWidget);
    expect(find.text('福建31 今日讨论'), findsWidgets);
  });

  testWidgets('logged-out publish redirects to account callback', (tester) async {
    var redirected = false;
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ForumCenterPage(
          landscapeReady: true,
          loggedIn: false,
          api: ForumApi(_FakeForumClient()),
          onGoToAccount: () => redirected = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-publish-button')));
    await tester.pump();
    expect(redirected, isTrue);
  });
}
