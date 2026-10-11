import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'play_betting.dart';

class PlayCenterPage extends StatefulWidget {
  const PlayCenterPage({
    required this.landscapeReady,
    required this.loggedIn,
    required this.gateway,
    this.onGoToAccount,
    super.key,
  });

  final bool landscapeReady;
  final bool loggedIn;
  final PlayBettingGateway gateway;
  final VoidCallback? onGoToAccount;

  @override
  State<PlayCenterPage> createState() => _PlayCenterPageState();
}

class _PlayCenterPageState extends State<PlayCenterPage> {
  PlayKind _kind = PlayKind.numberPick;
  OpenRound? _openRound;
  String? _roundHint;
  bool _loadingRound = false;
  bool _submitting = false;
  String? _resultMessage;
  bool _resultOk = false;
  final _n1 = TextEditingController(text: '1');
  final _n2 = TextEditingController(text: '2');
  final _n3 = TextEditingController(text: '3');
  final Set<int> _fujianPicks = <int>{};

  @override
  void initState() {
    super.initState();
    if (widget.loggedIn) {
      _refreshRound();
    }
  }

  @override
  void didUpdateWidget(covariant PlayCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loggedIn != oldWidget.loggedIn || widget.gateway != oldWidget.gateway) {
      if (widget.loggedIn) {
        _refreshRound();
      } else {
        setState(() {
          _openRound = null;
          _roundHint = null;
          _resultMessage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _n1.dispose();
    _n2.dispose();
    _n3.dispose();
    super.dispose();
  }

  Future<void> _selectKind(PlayKind kind) async {
    if (_kind == kind) return;
    setState(() {
      _kind = kind;
      _resultMessage = null;
      _openRound = null;
    });
    if (widget.loggedIn) {
      await _refreshRound();
    }
  }

  Future<void> _refreshRound() async {
    setState(() {
      _loadingRound = true;
      _roundHint = null;
    });
    try {
      final open = await widget.gateway.findOpenRound(lotteryIdFor(_kind));
      if (!mounted) return;
      setState(() {
        _openRound = open;
        _loadingRound = false;
        if (open == null) {
          _roundHint = '当期已截止，无法投注';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _openRound = null;
        _loadingRound = false;
        _roundHint = '当期已截止，无法投注';
      });
    }
  }

  void _toggleFujian(int n) {
    setState(() {
      if (_fujianPicks.contains(n)) {
        _fujianPicks.remove(n);
      } else if (_fujianPicks.length < 7) {
        _fujianPicks.add(n);
      }
    });
  }

  Future<void> _submit() async {
    final open = _openRound;
    if (open == null) {
      setState(() {
        _resultOk = false;
        _resultMessage = '当期已截止，无法投注';
      });
      return;
    }

    late final List<int> numbers;
    if (_kind == PlayKind.numberPick) {
      numbers = <int>[];
      for (final controller in [_n1, _n2, _n3]) {
        final value = int.tryParse(controller.text.trim());
        if (value == null) {
          setState(() {
            _resultOk = false;
            _resultMessage = '选号未通过校验';
          });
          return;
        }
        numbers.add(value);
      }
    } else {
      if (_fujianPicks.length != 7) {
        setState(() {
          _resultOk = false;
          _resultMessage = '选号未通过校验';
        });
        return;
      }
      numbers = _fujianPicks.toList()..sort();
    }

    setState(() {
      _submitting = true;
      _resultMessage = null;
    });
    final key = 'mobile-${DateTime.now().microsecondsSinceEpoch}';
    final result = await widget.gateway.placeBet({
      'idempotency_key': key,
      'round_id': open.roundId,
      'play_id': playIdFor(_kind),
      'rule_version': ruleVersionFor(_kind),
      'numbers': numbers,
    });
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _resultOk = result.ok;
      _resultMessage = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.landscapeReady) {
      return const Center(
        child: Text('请使用横屏查看玩法中心', key: Key('play-landscape-required')),
      );
    }
    if (!widget.loggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('去个人中心登录后再投注', key: Key('play-login-hint')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.onGoToAccount,
              child: const Text('去个人中心'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        key: const Key('play-landscape-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 280,
            child: ListView(
              children: [
                Text('玩法', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    key: const Key('play-game-number-pick'),
                    selected: _kind == PlayKind.numberPick,
                    title: const Text('数字选号'),
                    subtitle: const Text('选择 3 个不重复数字，投注冻结占位'),
                    onTap: () => _selectKind(PlayKind.numberPick),
                  ),
                ),
                const Card(
                  child: ListTile(
                    title: Text('排名竞猜'),
                    subtitle: Text('本片不接投注'),
                  ),
                ),
                Card(
                  child: ListTile(
                    key: const Key('play-game-fujian-31'),
                    selected: _kind == PlayKind.fujian31,
                    title: const Text('福建31选7'),
                    subtitle: const Text('选择 7 个 1 到 31 的号码，投注冻结占位'),
                    onTap: () => _selectKind(PlayKind.fujian31),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: _buildPanel(context)),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final open = _openRound;
    final title = _kind == PlayKind.fujian31 ? '福建31选7' : '数字选号';
    final roundLine = _loadingRound
        ? '正在读取期号…'
        : open == null
            ? (_roundHint ?? '当期已截止，无法投注')
            : '销售中 · ${open.code.isEmpty ? open.roundId : open.code}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(roundLine, key: const Key('play-round-status')),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('输入区'),
                  const SizedBox(height: 8),
                  Text(
                    _kind == PlayKind.fujian31
                        ? '选择 7 个不重复号码（1-31），已选 ${_fujianPicks.length}/7'
                        : '选择 3 个不重复数字（0-9）',
                  ),
                  const SizedBox(height: 12),
                  if (_kind == PlayKind.numberPick)
                    Row(
                      children: [
                        _DigitField(controller: _n1, label: '号1'),
                        const SizedBox(width: 8),
                        _DigitField(controller: _n2, label: '号2'),
                        const SizedBox(width: 8),
                        _DigitField(controller: _n3, label: '号3'),
                      ],
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('fujian-number-grid'),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var n = 1; n <= 31; n++)
                              FilterChip(
                                key: Key('fujian-n-$n'),
                                label: Text('$n'),
                                selected: _fujianPicks.contains(n),
                                onSelected: (_) => _toggleFujian(n),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('play-submit-bet'),
                    onPressed: _submitting || open == null ? null : _submit,
                    child: Text(_submitting ? '提交中' : '确认投注'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            key: const Key('play-result-panel'),
            title: const Text('结果区'),
            subtitle: Text(
              _resultMessage ?? '确认后走真实投注冻结占位，暂不派奖',
              key: const Key('play-result-message'),
            ),
            trailing: _resultMessage == null
                ? null
                : Text(_resultOk ? '已受理' : '失败'),
          ),
        ),
      ],
    );
  }
}

class _DigitField extends StatelessWidget {
  const _DigitField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
