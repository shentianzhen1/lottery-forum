import 'api_client.dart';
import 'api_exception.dart';

class ForumBoard {
  const ForumBoard({
    required this.id,
    required this.title,
    required this.description,
    required this.threadCount,
    this.lotteryId = '',
  });

  final String id;
  final String title;
  final String description;
  final String lotteryId;
  final int threadCount;

  factory ForumBoard.fromJson(Map<String, Object?> json) => ForumBoard(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        description: '${json['description'] ?? ''}',
        lotteryId: '${json['lottery_id'] ?? ''}',
        threadCount: _int(json['thread_count']),
      );
}

class ForumThreadSummary {
  const ForumThreadSummary({
    required this.id,
    required this.boardId,
    required this.boardTitle,
    required this.authorUsername,
    required this.title,
    required this.body,
    required this.tags,
    required this.replyCount,
    required this.createdAt,
    required this.updatedAt,
    required this.locked,
  });

  final String id;
  final String boardId;
  final String boardTitle;
  final String authorUsername;
  final String title;
  final String body;
  final List<String> tags;
  final int replyCount;
  final String createdAt;
  final String updatedAt;
  final bool locked;

  factory ForumThreadSummary.fromJson(Map<String, Object?> json) => ForumThreadSummary(
        id: '${json['id'] ?? ''}',
        boardId: '${json['board_id'] ?? ''}',
        boardTitle: '${json['board_title'] ?? ''}',
        authorUsername: '${json['author_username'] ?? ''}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        tags: [
          for (final tag in json['tags'] is List ? json['tags'] as List : const []) '$tag',
        ],
        replyCount: _int(json['reply_count']),
        createdAt: '${json['created_at'] ?? ''}',
        updatedAt: '${json['updated_at'] ?? ''}',
        locked: json['locked'] == true,
      );
}

class ForumReply {
  const ForumReply({
    required this.id,
    required this.authorUsername,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorUsername;
  final String body;
  final String createdAt;

  factory ForumReply.fromJson(Map<String, Object?> json) => ForumReply(
        id: '${json['id'] ?? ''}',
        authorUsername: '${json['author_username'] ?? ''}',
        body: '${json['body'] ?? ''}',
        createdAt: '${json['created_at'] ?? ''}',
      );
}

class ForumThreadDetail {
  const ForumThreadDetail({required this.thread, required this.replies});
  final ForumThreadSummary thread;
  final List<ForumReply> replies;
}

class ForumTopic {
  const ForumTopic({required this.tag, required this.threadCount});
  final String tag;
  final int threadCount;
}

class ForumHomeData {
  const ForumHomeData({
    required this.boards,
    required this.latestThreads,
    required this.hotTopics,
  });

  final List<ForumBoard> boards;
  final List<ForumThreadSummary> latestThreads;
  final List<ForumTopic> hotTopics;

  static const empty = ForumHomeData(boards: [], latestThreads: [], hotTopics: []);
}

class ForumApi {
  ForumApi(this.client);
  final ApiClient client;

  Future<ForumHomeData> home() async {
    try {
      final json = await client.getJson('/api/v1/forum/home');
      return ForumHomeData(
        boards: _maps(json['boards']).map(ForumBoard.fromJson).toList(),
        latestThreads: _maps(json['latest_threads']).map(ForumThreadSummary.fromJson).toList(),
        hotTopics: [
          for (final row in _maps(json['hot_topics']))
            ForumTopic(tag: '${row['tag'] ?? ''}', threadCount: _int(row['thread_count'])),
        ],
      );
    } on ApiException catch (error) {
      if (error.code == 'NOT_IMPLEMENTED') return ForumHomeData.empty;
      rethrow;
    }
  }

  Future<List<ForumThreadSummary>> search(String query, {String? boardId}) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (boardId != null && boardId.isNotEmpty) 'board_id': boardId,
    };
    final uri = Uri(path: '/api/v1/forum/threads', queryParameters: params);
    final json = await client.getJson(uri.toString());
    return _maps(json['threads']).map(ForumThreadSummary.fromJson).toList();
  }

  Future<ForumThreadDetail> detail(String threadId) async {
    final json = await client.getJson('/api/v1/forum/threads/$threadId');
    return ForumThreadDetail(
      thread: ForumThreadSummary.fromJson(json),
      replies: _maps(json['replies']).map(ForumReply.fromJson).toList(),
    );
  }

  Future<ForumThreadSummary> createThread({
    required String boardId,
    required String title,
    required String body,
    List<String> tags = const [],
  }) async {
    final json = await client.postJson('/api/v1/forum/threads', {
      'board_id': boardId,
      'title': title,
      'body': body,
      'tags': tags,
    });
    return ForumThreadSummary.fromJson(json);
  }

  Future<ForumReply> reply(String threadId, String body) async {
    final json = await client.postJson('/api/v1/forum/threads/$threadId/replies', {'body': body});
    return ForumReply.fromJson(json);
  }
}

List<Map<String, Object?>> _maps(Object? value) => [
      for (final row in value is List ? value : const [])
        if (row is Map) Map<String, Object?>.from(row),
    ];

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
