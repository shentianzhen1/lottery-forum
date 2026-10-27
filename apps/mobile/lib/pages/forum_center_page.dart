import 'package:flutter/material.dart';

import '../api/forum_api.dart';
import '../design/app_theme.dart';
import 'forum_ui.dart';

class ForumCenterPage extends StatelessWidget {
  const ForumCenterPage({
    required this.landscapeReady,
    required this.loggedIn,
    required this.api,
    required this.onGoToAccount,
    super.key,
  });

  final bool landscapeReady;
  final bool loggedIn;
  final ForumApi api;
  final VoidCallback onGoToAccount;

  @override
  Widget build(BuildContext context) {
    if (!landscapeReady) {
      return const Center(child: Text('请使用横屏查看论坛'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: ListView(
        key: const Key('forum-center-scroll'),
        children: [
          _ForumHero(
            loggedIn: loggedIn,
            onSearch: () => showForumSearchDialog(context, api),
            onCreate: () => _create(context),
          ),
          const SizedBox(height: 16),
          ForumOverview(
            api: api,
            loggedIn: loggedIn,
            onOpenBoard: (boardId) => showForumSearchDialog(context, api, boardId: boardId),
            onOpenThread: (threadId) => showForumThreadDialog(context, api, threadId),
            onCreateThread: () => _create(context),
          ),
          const SizedBox(height: 16),
          const _ForumBoundaryNote(),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    if (!loggedIn) {
      onGoToAccount();
      return;
    }
    await showCreateThreadDialog(context, api);
  }
}

class _ForumHero extends StatelessWidget {
  const _ForumHero({required this.loggedIn, required this.onSearch, required this.onCreate});
  final bool loggedIn;
  final VoidCallback onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('forum-hero'),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF203A40), Color(0xFF172A35), Color(0xFF151E2B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF355054)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CAIYOU FORUM', style: TextStyle(fontSize: 10, letterSpacing: 2.6, color: AppTheme.gold, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('分享经验 · 交流心得', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                SizedBox(height: 7),
                Text('围绕彩种、规则、开奖与玩法进行公开讨论。', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 310,
            child: OutlinedButton.icon(
              key: const Key('forum-search-button'),
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Align(alignment: Alignment.centerLeft, child: Text('搜索帖子、话题或关键词')),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: const Key('forum-publish-button'),
            onPressed: onCreate,
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: Text(loggedIn ? '发布帖子' : '登录后发帖'),
          ),
        ],
      ),
    );
  }
}

class _ForumBoundaryNote extends StatelessWidget {
  const _ForumBoundaryNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 17, color: AppTheme.teal),
          SizedBox(width: 9),
          Expanded(child: Text('论坛只提供公开讨论与内容交流；暂不提供好友、私聊、用户间积分转账。', style: TextStyle(fontSize: 11, color: AppTheme.muted))),
        ],
      ),
    );
  }
}
