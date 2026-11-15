import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/design/app_theme.dart';
import 'package:lottery_forum/api/api_client.dart';
import 'package:lottery_forum/api/api_config.dart';
import 'package:lottery_forum/api/session.dart';
import 'package:lottery_forum/shell/app_shell.dart';

void main() {
  const export = bool.fromEnvironment('EXPORT_UI_PREVIEW');

  testWidgets('export current home previews', (tester) async {
    if (!export) return;

    await tester.runAsync(() async {
      final font = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
      final fontBytes = ByteData.sublistView(font.readAsBytesSync());
      final fontLoader = FontLoader('Noto Sans CJK SC')
        ..addFont(Future.value(fontBytes));
      await fontLoader.load();

      final icons = File(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await iconLoader.load();
    });

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [
      const Size(800, 360),
      const Size(854, 480),
      const Size(1024, 600),
      const Size(1366, 768),
    ]) {
      tester.view.physicalSize = size;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: const _PreviewApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, boundaryKey, 'home-${size.width.toInt()}x${size.height.toInt()}');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark;
    return MaterialApp(
      title: '彩友论坛',
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Noto Sans CJK SC'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Noto Sans CJK SC'),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(textStyle: const TextStyle(fontFamily: 'Noto Sans CJK SC')),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontFamily: 'Noto Sans CJK SC')),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: 'Noto Sans CJK SC')),
        ),
        navigationRailTheme: theme.navigationRailTheme.copyWith(
          selectedLabelTextStyle: theme.navigationRailTheme.selectedLabelTextStyle
              ?.copyWith(fontFamily: 'Noto Sans CJK SC'),
          unselectedLabelTextStyle: theme.navigationRailTheme.unselectedLabelTextStyle
              ?.copyWith(fontFamily: 'Noto Sans CJK SC'),
        ),
      ),
      home: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Noto Sans CJK SC'),
        child: AppShell(client: _PreviewClient()),
      ),
    );
  }
}

// Preview-only examples are clearly marked so reviewers can inspect the forum
// feed hierarchy without presenting them as real community activity.
class _PreviewClient extends ApiClient {
  _PreviewClient() : super(const ApiConfig(), Session());

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    if (path == '/api/v1/forum/home') {
      const threads = [
        {
          'id': 'preview-1',
          'board_id': 'general',
          'board_title': '综合讨论',
          'author_username': '演示账号',
          'title': '第一次来到彩友论坛，可以从哪些板块开始？',
          'body': '论坛讨论与积分玩法相互独立，可以从感兴趣的彩种分区开始交流。',
          'tags': ['演示内容', '新手指南'],
          'reply_count': 0,
          'created_at': '2026-11-15T10:30:00Z',
          'updated_at': '2026-11-15T10:30:00Z',
          'locked': false,
        },
        {
          'id': 'preview-2',
          'board_id': 'fujian31',
          'board_title': '福建31',
          'author_username': '演示账号',
          'title': '福建31讨论区：如何整理自己的选号思路',
          'body': '演示帖子用于展示标题、摘要和标签，不代表真实用户观点。',
          'tags': ['演示内容', '选号思路'],
          'reply_count': 0,
          'created_at': '2026-11-15T09:45:00Z',
          'updated_at': '2026-11-15T09:45:00Z',
          'locked': false,
        },
        {
          'id': 'preview-3',
          'board_id': 'number-pick',
          'board_title': '数字选号',
          'author_username': '演示账号',
          'title': '记录选号过程，比只看结果更容易复盘',
          'body': '可以记录选择依据，后续再回来对照自己的判断过程。',
          'tags': ['演示内容', '经验分享'],
          'reply_count': 0,
          'created_at': '2026-11-15T08:20:00Z',
          'updated_at': '2026-11-15T08:20:00Z',
          'locked': false,
        },
      ];
      return {
        'boards': [
          for (final board in const [
            ('general', '综合讨论'),
            ('fujian31', '福建31'),
            ('number-pick', '数字选号'),
            ('pailie3', '排列三'),
            ('kuaile8', '快乐8'),
          ])
            {
              'id': board.$1,
              'title': board.$2,
              'thread_count': threads
                  .where((thread) => thread['board_id'] == board.$1)
                  .length,
            },
        ],
        'hot_topics': [
          {'tag': '新手指南', 'thread_count': 1},
          {'tag': '选号思路', 'thread_count': 1},
          {'tag': '经验分享', 'thread_count': 1},
        ],
        'latest_threads': threads,
      };
    }
    return super.getJson(path);
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui-preview')..createSync(recursive: true);
    File('${directory.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
