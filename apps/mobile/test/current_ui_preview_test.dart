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

    for (final size in [const Size(1024, 600), const Size(1366, 768)]) {
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

// The preview uses the actual Flutter UI with an empty forum response. No posts
// or activity are invented; other endpoints retain their normal behavior.
class _PreviewClient extends ApiClient {
  _PreviewClient() : super(const ApiConfig(), Session());

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    if (path == '/api/v1/forum/home') {
      return {
        'boards': [
          for (final board in const [
            ('general', '综合讨论'),
            ('fujian31', '福建31'),
            ('number-pick', '数字选号'),
            ('pailie3', '排列三'),
            ('kuaile8', '快乐8'),
          ])
            {'id': board.$1, 'title': board.$2, 'thread_count': 0},
        ],
        'hot_topics': [],
        'latest_threads': [],
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
