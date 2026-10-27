import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../api/forum_api.dart';
import '../design/app_theme.dart';

class ForumOverview extends StatefulWidget {
  const ForumOverview({
    required this.api,
    required this.loggedIn,
    required this.onOpenBoard,
    required this.onOpenThread,
    required this.onCreateThread,
    super.key,
  });

  final ForumApi api;
  final bool loggedIn;
  final ValueChanged<String> onOpenBoard;
  final ValueChanged<String> onOpenThread;
  final VoidCallback onCreateThread;

  @override
  State<ForumOverview> createState() => _ForumOverviewState();
}

class _ForumOverviewState extends State<ForumOverview> {
  ForumHomeData? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ForumOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.loggedIn != widget.loggedIn) _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.home();
      if (mounted) setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() {
        _data = ForumHomeData.empty;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _HotTopicsCard(
                topics: data.hotTopics,
                onTopic: (tag) => showForumSearchDialog(context, widget.api, initialQuery: tag),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _BoardDirectoryCard(
                boards: data.boards,
                onBoard: widget.onOpenBoard,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _LatestThreadsCard(
          threads: data.latestThreads,
          error: _error,
          loggedIn: widget.loggedIn,
          onThread: widget.onOpenThread,
          onCreate: widget.onCreateThread,
          onRefresh: _load,
        ),
      ],
    );
  }
}

class _HotTopicsCard extends StatelessWidget {
  const _HotTopicsCard({required this.topics, required this.onTopic});
  final List<ForumTopic> topics;
  final ValueChanged<String> onTopic;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department_outlined, size: 18, color: AppTheme.gold),
                SizedBox(width: 8),
                Text('热门话题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),
            if (topics.isEmpty)
              const Text('暂无热门话题，发布第一篇讨论后这里会自动出现。', style: TextStyle(color: AppTheme.muted, fontSize: 11))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in topics)
                    ActionChip(
                      onPressed: () => onTopic(topic.tag),
                      avatar: const Icon(Icons.tag, size: 14),
                      label: Text(topic.tag),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardDirectoryCard extends StatelessWidget {
  const _BoardDirectoryCard({required this.boards, required this.onBoard});
  final List<ForumBoard> boards;
  final ValueChanged<String> onBoard;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.forum_outlined, size: 18, color: AppTheme.teal),
                SizedBox(width: 8),
                Text('彩种分区', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final board in boards.take(5))
                  OutlinedButton(
                    onPressed: () => onBoard(board.id),
                    child: Text('${board.title} · ${board.threadCount}帖'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestThreadsCard extends StatelessWidget {
  const _LatestThreadsCard({
    required this.threads,
    required this.error,
    required this.loggedIn,
    required this.onThread,
    required this.onCreate,
    required this.onRefresh,
  });

  final List<ForumThreadSummary> threads;
  final Object? error;
  final bool loggedIn;
  final ValueChanged<String> onThread;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('forum-latest-threads'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dynamic_feed_outlined, size: 18, color: AppTheme.gold),
                const SizedBox(width: 8),
                const Text('最新讨论', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(
                  key: const Key('forum-create-thread'),
                  onPressed: onCreate,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(loggedIn ? '发布帖子' : '登录后发帖'),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('论坛内容暂时无法加载', style: TextStyle(color: AppTheme.muted))),
                TextButton(onPressed: onRefresh, child: const Text('重试')),
              ]),
            ] else if (threads.isEmpty) ...[
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('还没有讨论帖。可以从综合讨论或彩种分区发布第一篇。', style: TextStyle(color: AppTheme.muted)),
              ),
            ] else
              for (final thread in threads.take(6)) _ThreadRow(thread: thread, onTap: () => onThread(thread.id)),
          ],
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread, required this.onTap});
  final ForumThreadSummary thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('forum-thread-${thread.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gold.withOpacity(.16)),
              ),
              child: Text(thread.boardTitle, style: const TextStyle(fontSize: 10, color: AppTheme.gold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(thread.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${thread.authorUsername} · ${thread.replyCount} 回复', style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

Future<void> showForumSearchDialog(
  BuildContext context,
  ForumApi api, {
  String initialQuery = '',
  String? boardId,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ForumSearchDialog(api: api, initialQuery: initialQuery, boardId: boardId),
  );
}

class _ForumSearchDialog extends StatefulWidget {
  const _ForumSearchDialog({required this.api, required this.initialQuery, this.boardId});
  final ForumApi api;
  final String initialQuery;
  final String? boardId;

  @override
  State<_ForumSearchDialog> createState() => _ForumSearchDialogState();
}

class _ForumSearchDialogState extends State<_ForumSearchDialog> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  List<ForumThreadSummary>? _threads;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _threads = null;
      _error = null;
    });
    try {
      final rows = await widget.api.search(_query.text, boardId: widget.boardId);
      if (mounted) setState(() => _threads = rows);
    } catch (error) {
      if (mounted) setState(() {
        _threads = const [];
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.boardId == null ? '搜索论坛' : '讨论区'),
      content: SizedBox(
        width: 680,
        height: 440,
        child: Column(
          children: [
            TextField(
              key: const Key('forum-search-field'),
              controller: _query,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '搜索帖子、话题或关键词',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _threads == null
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? const Center(child: Text('搜索暂不可用', style: TextStyle(color: AppTheme.muted)))
                      : _threads!.isEmpty
                          ? const Center(child: Text('暂无匹配讨论', style: TextStyle(color: AppTheme.muted)))
                          : ListView.separated(
                              itemCount: _threads!.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final thread = _threads![index];
                                return ListTile(
                                  title: Text(thread.title),
                                  subtitle: Text('${thread.boardTitle} · ${thread.authorUsername} · ${thread.replyCount} 回复'),
                                  onTap: () async {
                                    await showForumThreadDialog(context, widget.api, thread.id);
                                    if (mounted) await _search();
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
    );
  }
}

Future<bool> showCreateThreadDialog(
  BuildContext context,
  ForumApi api, {
  String initialBoardId = 'general',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => _CreateThreadDialog(api: api, initialBoardId: initialBoardId),
      ) ??
      false;
}

class _CreateThreadDialog extends StatefulWidget {
  const _CreateThreadDialog({required this.api, required this.initialBoardId});
  final ForumApi api;
  final String initialBoardId;

  @override
  State<_CreateThreadDialog> createState() => _CreateThreadDialogState();
}

class _CreateThreadDialogState extends State<_CreateThreadDialog> {
  late String _boardId = widget.initialBoardId;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('发布帖子'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _boardId,
              decoration: const InputDecoration(labelText: '板块'),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('综合讨论')),
                DropdownMenuItem(value: 'fujian31', child: Text('福建31')),
                DropdownMenuItem(value: 'number-pick', child: Text('数字选号')),
                DropdownMenuItem(value: 'pailie3', child: Text('排列三')),
                DropdownMenuItem(value: 'kuaile8', child: Text('快乐8')),
              ],
              onChanged: _saving ? null : (value) => setState(() => _boardId = value ?? 'general'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _title, maxLength: 80, decoration: const InputDecoration(labelText: '标题')),
            const SizedBox(height: 10),
            TextField(controller: _body, minLines: 4, maxLines: 7, maxLength: 5000, decoration: const InputDecoration(labelText: '正文')),
            const SizedBox(height: 10),
            TextField(controller: _tags, decoration: const InputDecoration(labelText: '话题标签（用逗号分隔，可选）')),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? '发布中…' : '发布')),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createThread(
        boardId: _boardId,
        title: _title.text,
        body: _body.text,
        tags: _tags.text.split(RegExp(r'[,，]')).map((value) => value.trim()).where((value) => value.isNotEmpty).toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Future<void> showForumThreadDialog(BuildContext context, ForumApi api, String threadId) async {
  await showDialog<void>(context: context, builder: (_) => _ForumThreadDialog(api: api, threadId: threadId));
}

class _ForumThreadDialog extends StatefulWidget {
  const _ForumThreadDialog({required this.api, required this.threadId});
  final ForumApi api;
  final String threadId;

  @override
  State<_ForumThreadDialog> createState() => _ForumThreadDialogState();
}

class _ForumThreadDialogState extends State<_ForumThreadDialog> {
  ForumThreadDetail? _detail;
  Object? _error;
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.api.detail(widget.threadId);
      if (mounted) setState(() {
        _detail = detail;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return AlertDialog(
      title: Text(detail?.thread.title ?? '帖子详情'),
      content: SizedBox(
        width: 720,
        height: 500,
        child: _error != null
            ? const Center(child: Text('帖子暂时无法加载'))
            : detail == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${detail.thread.boardTitle} · ${detail.thread.authorUsername}', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                      const SizedBox(height: 10),
                      Text(detail.thread.body, style: const TextStyle(height: 1.5)),
                      const SizedBox(height: 14),
                      const Divider(),
                      const Text('回复', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: detail.replies.isEmpty
                            ? const Center(child: Text('暂无回复', style: TextStyle(color: AppTheme.muted)))
                            : ListView.separated(
                                itemCount: detail.replies.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final reply = detail.replies[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(reply.authorUsername, style: const TextStyle(fontSize: 11, color: AppTheme.gold)),
                                    subtitle: Text(reply.body),
                                  );
                                },
                              ),
                      ),
                      if (widget.api.client.session.token != null && !detail.thread.locked) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _reply, decoration: const InputDecoration(hintText: '写下回复…'))),
                            const SizedBox(width: 8),
                            FilledButton(onPressed: _sending ? null : _sendReply, child: const Text('回复')),
                          ],
                        ),
                      ],
                    ],
                  ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
    );
  }

  Future<void> _sendReply() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.api.reply(widget.threadId, _reply.text);
      _reply.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
