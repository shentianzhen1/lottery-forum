import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pages/points_reader.dart';
import 'api_config.dart';
import 'session.dart';

class ApiClient {
  ApiClient(this.config, this.session);

  final ApiConfig config;
  final Session session;

  Future<Map<String, Object?>> getJson(String path) async {
    final response = await http.get(
      Uri.parse('${config.baseUrl}$path'),
      headers: _headers(),
    );
    return _decode(response);
  }

  Future<Map<String, Object?>> postJson(String path, Map<String, Object?> body) async {
    final response = await http.post(
      Uri.parse('${config.baseUrl}$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, String> _headers() {
    return {
      'content-type': 'application/json',
      if (session.token != null) 'authorization': 'Bearer ${session.token}',
    };
  }

  Map<String, Object?> _decode(http.Response response) {
    final body = response.body.isEmpty ? <String, Object?>{} : jsonDecode(response.body);
    if (body is! Map<String, Object?>) {
      throw const PointsLoadException('接口返回不是对象');
    }
    if (response.statusCode >= 400) {
      final detail = body['detail'];
      final message = detail is Map ? detail['message']?.toString() : null;
      throw PointsLoadException(message ?? '接口请求失败');
    }
    return body;
  }
}

class ApiPointsReader implements PointsReader {
  ApiPointsReader(this.client);

  final ApiClient client;

  @override
  Future<PointsSnapshot> load() async {
    if (client.session.token == null) {
      throw const PointsLoadException('需要登录');
    }
    final balance = await client.getJson('/api/v1/points/balance');
    final entriesBody = await client.getJson('/api/v1/points/entries');
    final rows = entriesBody['entries'];
    return snapshotFromApi(
      balance: balance,
      entries: [
        for (final row in rows is List ? rows : const [])
          if (row is Map) Map<String, Object?>.from(row),
      ],
    );
  }
}
