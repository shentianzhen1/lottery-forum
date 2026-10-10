import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

const defaultModeratorLotteryId = 'fujian-31';
const defaultModeratorLotteryLabel = '福建31选7';

class ModeratorBoard {
  const ModeratorBoard({
    required this.boardId,
    required this.lotteryId,
    required this.status,
  });

  final String boardId;
  final String lotteryId;
  final String status;
}

abstract class ModeratorGateway {
  Future<int> loadThreshold();
  Future<List<ModeratorBoard>> loadMyBoards();
  Future<ModeratorBoard> openBoard(String lotteryId);
}

class ApiModeratorGateway implements ModeratorGateway {
  ApiModeratorGateway(this.client);

  final ApiClient client;

  @override
  Future<int> loadThreshold() async {
    final body = await client.getJson('/api/v1/moderator/settings');
    final value = body['threshold'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw const ApiException('门槛字段缺失');
  }

  @override
  Future<List<ModeratorBoard>> loadMyBoards() async {
    final body = await client.getJson('/api/v1/moderator/boards/me');
    final rows = body['boards'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map)
          ModeratorBoard(
            boardId: '${row['board_id']}',
            lotteryId: '${row['lottery_id']}',
            status: '${row['status']}',
          ),
    ];
  }

  @override
  Future<ModeratorBoard> openBoard(String lotteryId) async {
    final body = await client.postJson('/api/v1/moderator/boards', {
      'lottery_id': lotteryId,
    });
    return ModeratorBoard(
      boardId: '${body['board_id']}',
      lotteryId: '${body['lottery_id']}',
      status: '${body['status']}',
    );
  }
}

class ModeratorPage extends StatefulWidget {
  const ModeratorPage({
    required this.landscapeReady,
    required this.loggedIn,
    required this.gateway,
    this.onGoToAccount,
    this.lotteryId = defaultModeratorLotteryId,
    this.lotteryLabel = defaultModeratorLotteryLabel,
    super.key,
  });

  final bool landscapeReady;
  final bool loggedIn;
  final ModeratorGateway gateway;
  final VoidCallback? onGoToAccount;
  final String lotteryId;
  final String lotteryLabel;

  @override
  State<ModeratorPage> createState() => _ModeratorPageState();
}

class _ModeratorPageState extends State<ModeratorPage> {
  int? _threshold;
  ModeratorBoard? _board;
  String? _error;
  String? _statusMessage;
  bool _loading = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (widget.loggedIn) {
      _refresh();
    }
  }

  @override
  void didUpdateWidget(covariant ModeratorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loggedIn != oldWidget.loggedIn || widget.gateway != oldWidget.gateway) {
      if (widget.loggedIn) {
        _refresh();
      } else {
        setState(() {
          _threshold = null;
          _board = null;
          _error = null;
          _statusMessage = null;
          _loading = false;
          _opening = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      final threshold = await widget.gateway.loadThreshold();
      final boards = await widget.gateway.loadMyBoards();
      ModeratorBoard? mine;
      for (final board in boards) {
        if (board.lotteryId == widget.lotteryId) {
          mine = board;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _threshold = threshold;
        _board = mine;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '读取失败';
        _loading = false;
      });
    }
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _statusMessage = null;
      _error = null;
    });
    try {
      final board = await widget.gateway.openBoard(widget.lotteryId);
      if (!mounted) return;
      setState(() {
        _board = board;
        _opening = false;
        _statusMessage = '已开通';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        if (error.code == 'INSUFFICIENT_POINTS') {
          _statusMessage = '积分不足';
        } else {
          _error = error.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = '开通失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.landscapeReady) {
      return const Center(
        child: Text('请使用横屏查看版主中心', key: Key('moderator-landscape-required')),
      );
    }
    if (!widget.loggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('去个人中心登录后再开通版主', key: Key('moderator-login-hint')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.onGoToAccount,
              child: const Text('去个人中心'),
            ),
          ],
        ),
      );
    }
    if (_loading && _threshold == null && _error == null) {
      return const Center(child: Text('正在读取版主状态'));
    }
    if (_error != null && _threshold == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, key: const Key('moderator-load-error')),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('重试')),
          ],
        ),
      );
    }

    final threshold = _threshold ?? 10000;
    final opened = _board != null;
    final statusLine = opened
        ? '已开通 · ${widget.lotteryLabel} · ${_board!.status}'
        : '达标即可开通（默认门槛 $threshold，开通时冻结），无需审核';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        key: const Key('moderator-landscape-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 360,
            child: Card(
              child: ListTile(
                key: const Key('open-moderator'),
                title: const Text('开通版主'),
                subtitle: Text(statusLine, key: Key(opened ? 'moderator-opened-status' : 'moderator-open-copy')),
                trailing: opened
                    ? const Text('已开通')
                    : FilledButton(
                        key: const Key('moderator-open-button'),
                        onPressed: _opening ? null : _open,
                        child: Text(_opening ? '开通中' : '开通'),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('开通说明', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('当前彩种：${widget.lotteryLabel}（${widget.lotteryId}）'),
                Text('门槛：$threshold 积分，开通时冻结，无需审核。'),
                const SizedBox(height: 12),
                if (_statusMessage == '积分不足')
                  const Text('积分不足', key: Key('moderator-insufficient')),
                if (_statusMessage == '已开通')
                  const Text('开通成功', key: Key('moderator-open-success')),
                if (_error != null) Text(_error!, key: const Key('moderator-action-error')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
