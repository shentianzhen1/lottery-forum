import 'package:flutter/material.dart';

import '../api/api_client.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({required this.client, required this.onChanged, super.key});

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

  Future<void> _login() async {
    setState(() => _error = null);
    try {
      final body = await widget.client.postJson('/api/v1/auth/login', {
        'username': _username.text.trim(),
        'password': _password.text,
      });
      widget.client.session.token = body['token'] as String?;
      widget.client.session.username = body['username'] as String?;
      widget.onChanged();
    } catch (error) {
      setState(() => _error = '登录失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.client.session;
    if (session.token != null) {
      return Center(child: Text('已登录 ${session.username ?? ''}', key: const Key('logged-in')));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        key: const Key('login-form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('登录', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(controller: _username, decoration: const InputDecoration(labelText: '用户名')),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _login, child: const Text('登录')),
          if (_error != null) Text(_error!, key: const Key('login-error')),
        ],
      ),
    );
  }
}
