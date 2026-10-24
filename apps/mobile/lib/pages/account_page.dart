import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../design/app_theme.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    required this.landscapeReady,
    required this.client,
    required this.onChanged,
    super.key,
  });

  final bool landscapeReady;
  final ApiClient client;
  final VoidCallback onChanged;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(String path) async {
    setState(() => _error = null);
    try {
      final body = await widget.client.postJson(path, {
        'username': _username.text.trim(),
        'password': _password.text,
      });
      widget.client.session.token = body['token'] as String?;
      widget.client.session.username = body['username'] as String?;
      widget.onChanged();
    } catch (error) {
      setState(() => _error = path.endsWith('register') ? '注册失败' : '登录失败');
    }
  }

  void _logout() {
    widget.client.session.token = null;
    widget.client.session.username = null;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.landscapeReady) {
      return const Center(
        child: Text(
          '请使用横屏查看个人中心',
          key: Key('account-landscape-required'),
        ),
      );
    }

    final session = widget.client.session;
    if (session.token != null) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AccountBrandBadge(),
                const SizedBox(height: 18),
                Text(
                  '已登录 ${session.username ?? ''}',
                  key: const Key('logged-in'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  '账户状态正常',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 180,
                  child: OutlinedButton(onPressed: _logout, child: const Text('退出')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 460,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                key: const Key('login-form'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _AccountBrandBadge(),
                  const SizedBox(height: 18),
                  Text('登录彩友论坛', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 7),
                  const Text(
                    '登录后可查看积分、参与玩法与管理版主入口。',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: '用户名'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '密码'),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _submit('/api/v1/auth/login'),
                          child: const Text('登录'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _submit('/api/v1/auth/register'),
                          child: const Text('注册'),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        key: const Key('login-error'),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountBrandBadge extends StatelessWidget {
  const _AccountBrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF332F27),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.gold.withOpacity(.3)),
      ),
      child: const Text(
        '彩',
        style: TextStyle(
          color: AppTheme.gold,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
