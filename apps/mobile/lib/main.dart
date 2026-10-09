import 'package:flutter/material.dart';

import 'shell/app_shell.dart';

void main() {
  runApp(const LotteryForumApp());
}

class LotteryForumApp extends StatelessWidget {
  const LotteryForumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '彩票论坛',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6F6A)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F1EA),
      ),
      home: const AppShell(),
    );
  }
}
