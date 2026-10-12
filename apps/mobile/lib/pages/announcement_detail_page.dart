import 'package:flutter/material.dart';

import 'home_feed.dart';

class AnnouncementDetailPage extends StatefulWidget {
  const AnnouncementDetailPage({
    required this.landscapeReady,
    required this.announcementId,
    required this.feed,
    this.onBack,
    super.key,
  });

  final bool landscapeReady;
  final String announcementId;
  final HomeFeed feed;
  final VoidCallback? onBack;

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  HomeAnnouncement? _item;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AnnouncementDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.announcementId != oldWidget.announcementId ||
        widget.feed != oldWidget.feed) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _item = null;
    });
    try {
      final item = await widget.feed.loadAnnouncement(widget.announcementId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is AnnouncementLoadException
            ? error.message
            : '读取失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.landscapeReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '请使用横屏查看公告详情',
            key: Key('announcement-detail-landscape-required'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        key: const Key('announcement-detail-page'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                key: const Key('announcement-detail-back'),
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Text('正在读取', key: Key('announcement-detail-loading')),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              key: const Key('announcement-detail-error'),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('announcement-detail-retry'),
              onPressed: _load,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final item = _item!;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    key: const Key('announcement-detail-title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (item.pinned)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('置顶', key: Key('announcement-detail-pinned')),
                  ),
              ],
            ),
            if (item.publishedAtLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.publishedAtLabel,
                key: const Key('announcement-detail-published-at'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              item.body,
              key: const Key('announcement-detail-body'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
