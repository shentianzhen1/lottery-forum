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

    for (final size in [const Size(1024, 600), const Size(1366, 768)]) {
      tester.view.physicalSize = size;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: const _PreviewPlayApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-item-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        boundaryKey,
        'play-${size.width.toInt()}x${size.height.toInt()}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '彩友论坛',
      debugShowCheckedModeBanner: false,
      theme: _previewTheme(),
      home: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'Noto Sans CJK SC',
          color: AppTheme.ink,
        ),
        child: AppShell(client: _PreviewClient()),
      ),
    );
  }
}

class _PreviewPlayApp extends StatelessWidget {
  const _PreviewPlayApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '彩友论坛',
      debugShowCheckedModeBanner: false,
      theme: _previewTheme(),
      home: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'Noto Sans CJK SC',
          color: AppTheme.ink,
        ),
        child: AppShell(client: _PreviewPlayClient()),
      ),
    );
  }
}

class _PreviewPlayClient extends ApiClient {
  _PreviewPlayClient() : super(const ApiConfig(), Session()) {
    session.token = 'preview-token';
    session.username = '演示账号';
  }

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    final uri = Uri.parse(path);
    if (uri.path == '/api/v1/rounds') {
      return {
        'rounds': [
          {
            'round_id': 'preview-fujian-31',
            'lottery_id': 'fujian-31',
            'code': 'TEST-001',
            'status': 'OPEN',
          },
        ],
      };
    }
    if (uri.path == '/api/v1/bets') return {'items': <Map<String, Object?>>[]};
    return super.getJson(path);
  }
}

ThemeData _previewTheme() {
  final theme = AppTheme.dark;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Noto Sans CJK SC'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Noto Sans CJK SC'),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(fontFamily: 'Noto Sans CJK SC'),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(fontFamily: 'Noto Sans CJK SC'),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontFamily: 'Noto Sans CJK SC'),
      ),
    ),
    navigationRailTheme: theme.navigationRailTheme.copyWith(
      selectedLabelTextStyle: theme.navigationRailTheme.selectedLabelTextStyle
          ?.copyWith(fontFamily: 'Noto Sans CJK SC'),
      unselectedLabelTextStyle: theme.navigationRailTheme.unselectedLabelTextStyle
          ?.copyWith(fontFamily: 'Noto Sans CJK SC'),
    ),
  );
}

class _PreviewClient extends ApiClient {
  _PreviewClient() : super(const ApiConfig(), Session()) {
    session.token = 'preview-token';
    session.username = '演示账号';
  }

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    final uri = Uri.parse(path);
    if (uri.path == '/api/v1/home/banners') {
      return {
        'banners': [
          {
            'id': 'demo-banner',
            'title': '演示：三种彩票，轻松体验',
            'subtitle': '31选7已开放 · 福彩3D与排列五筹备中',
          },
        ],
      };
    }
    if (uri.path == '/api/v1/home/announcements') {
      return {
        'announcements': [
          {
            'id': 'demo-notice',
            'title': '演示数据说明',
            'body': '当前画面仅用于展示界面布局，不代表真实开奖或用户参与。',
            'pinned': true,
          },
        ],
      };
    }
    if (uri.path == '/api/v1/home/draws/recent') {
      return {
        'items': [
          {
            'lottery_id': 'fujian-31',
            'normalized_code': 'DEMO-20261115',
            'draw_date': '2026-11-15',
            'main_numbers': [3, 7, 12, 18, 22, 26, 31],
            'extra_numbers': [9],
          },
        ],
      };
    }
    if (uri.path == '/api/v1/home/rounds/current') {
      return {
        'round': {
          'lottery_id': 'fujian-31',
          'code': '演示期 DEMO-001',
          'status': 'OPEN',
          'accepts_bets': true,
        },
      };
    }
    if (uri.path == '/api/v1/rounds') {
      return {
        'rounds': [
          {
            'round_id': 'demo-round',
            'lottery_id': 'fujian-31',
            'code': 'DEMO-001',
            'status': 'OPEN',
          },
        ],
      };
    }
    if (uri.path == '/api/v1/bets') {
      return {
        'items': [
          {'bet_id': 'demo-bet'},
        ],
      };
    }
    if (uri.path == '/api/v1/points/balance') {
      return {'balance': 12580, 'frozen': 120};
    }
    if (uri.path == '/api/v1/points/entries') {
      return {'entries': <Map<String, Object?>>[]};
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
