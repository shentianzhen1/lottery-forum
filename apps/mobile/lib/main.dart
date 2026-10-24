import 'package:flutter/material.dart';

import 'design/app_theme.dart';
import 'shell/app_shell.dart';

void main() {
  runApp(const LotteryForumApp());
}

class LotteryForumApp extends StatelessWidget {
  const LotteryForumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '彩友论坛',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
