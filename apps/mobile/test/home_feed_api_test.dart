import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_forum/api/api_client.dart';
import 'package:lottery_forum/api/api_config.dart';
import 'package:lottery_forum/api/api_exception.dart';
import 'package:lottery_forum/api/home_feed_api.dart';
import 'package:lottery_forum/api/session.dart';

class _FakeClient extends ApiClient {
  _FakeClient({this.failDraws = false})
      : super(const ApiConfig(baseUrl: 'http://example.test'), Session());

  final bool failDraws;
  final List<String> paths = [];

  @override
  Future<Map<String, Object?>> getJson(String path) async {
    paths.add(path);
    if (path == '/api/v1/home/banners') {
      return {
        'banners': [
          {'id': 'b1', 'title': '横幅', 'subtitle': '副标题'},
        ],
      };
    }
    if (path == '/api/v1/home/announcements') {
      return {
        'announcements': [
          {'id': 'a1', 'title': '公告', 'body': '正文', 'pinned': true},
        ],
      };
    }
    if (path.startsWith('/api/v1/home/draws/recent')) {
      if (failDraws) {
        throw const ApiException('draw feed unavailable');
      }
      return {
        'items': [
          {
            'lottery_id': 'fujian-31',
            'normalized_code': '2026281',
            'draw_date': '2026-10-22',
            'main_numbers': [3, 10, 11, 12, 24, 25, 30],
            'extra_numbers': [22],
          },
        ],
      };
    }
    throw ApiException('unexpected path: $path');
  }
}

void main() {
  test('home feed loads public recent confirmed draws', () async {
    final client = _FakeClient();
    final data = await ApiHomeFeed(client).load();

    expect(data.banners.single.title, '横幅');
    expect(data.announcements.single.title, '公告');
    expect(data.recentDraws.single.code, '2026281');
    expect(data.recentDraws.single.mainNumbers, [3, 10, 11, 12, 24, 25, 30]);
    expect(
      client.paths,
      contains('/api/v1/home/draws/recent?lottery_id=fujian-31&limit=3'),
    );
  });

  test('optional draw failure does not blank banners and announcements', () async {
    final data = await ApiHomeFeed(_FakeClient(failDraws: true)).load();

    expect(data.banners, hasLength(1));
    expect(data.announcements, hasLength(1));
    expect(data.recentDraws, isEmpty);
  });
}
