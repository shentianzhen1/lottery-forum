import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/main.dart';

void main() {
  const export = bool.fromEnvironment('EXPORT_UI_PREVIEW');

  testWidgets('premium shell stays usable at compact landscape and desktop sizes', (tester) async {
    if (export) {
      final font = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
      final bytes = ByteData.sublistView(font.readAsBytesSync());
      for (final family in ['Noto Sans CJK SC', 'Roboto', 'Ahem']) {
        final loader = FontLoader(family)..addFont(Future.value(bytes));
        await loader.load();
      }
      final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await iconLoader.load();
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(1024, 600), const Size(1366, 768)]) {
      tester.view.physicalSize = size;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: const LotteryForumApp()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home-game-fujian-31')), findsOneWidget);
      if (export) await _capture(tester, boundaryKey, 'home-${size.width.toInt()}');
      for (final label in ['玩法中心', '积分中心', '版主中心', '个人中心']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label at $size');
      }
      if (export) await _capture(tester, boundaryKey, 'account-${size.width.toInt()}');
      // Dispose the shell so the next viewport starts on the home destination.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
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
