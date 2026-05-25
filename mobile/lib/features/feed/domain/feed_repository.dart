import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/models/post.dart';

class FeedRepository {
  final ApiClient _client;
  FeedRepository(this._client);

  Future<List<Post>> getFeed({
    required double lat,
    required double lng,
    int radiusM = 5000,
    int page = 1,
  }) async {
    return _client.get<List<Post>>(
      '/v1/feed',
      queryParams: {
        'lat': lat,
        'lng': lng,
        'radius': radiusM,
        'page': page,
      },
      fromJson: (data) => (data['posts'] as List? ?? [])
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<Post>> getFlashFeed({required double lat, required double lng}) async {
    return _client.get<List<Post>>(
      '/v1/feed/flash',
      queryParams: {'lat': lat, 'lng': lng},
      fromJson: (data) => (data['posts'] as List? ?? [])
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Post> getPost(String id) async {
    return _client.get<Post>(
      '/v1/posts/$id',
      fromJson: (data) => Post.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<PostComment>> getComments(String postId, {int page = 1, String sort = 'new'}) async {
    return _client.get<List<PostComment>>(
      '/v1/posts/$postId/comments',
      queryParams: {'page': page, 'sort': sort},
      fromJson: (data) => (data['comments'] as List? ?? [])
          .map((c) => PostComment.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<PostComment> addComment(
    String postId,
    String content, {
    String? parentId,
    List<String> mediaUrls = const [],
  }) async {
    return _client.post<PostComment>(
      '/v1/posts/$postId/comments',
      body: {
        'content': content,
        if (parentId != null) 'parent_id': parentId,
        if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
      },
      fromJson: (data) => PostComment.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<PostComment>> getCommentReplies(String commentId, {int page = 1}) async {
    return _client.get<List<PostComment>>(
      '/v1/posts/comments/$commentId/replies',
      queryParams: {'page': page},
      fromJson: (data) => (data['replies'] as List? ?? [])
          .map((c) => PostComment.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<({int count, bool liked})> likeComment(String commentId) async {
    return _client.post<({int count, bool liked})>(
      '/v1/posts/comments/$commentId/like',
      body: {},
      fromJson: (data) => (
        count: (data['like_count'] as num?)?.toInt() ?? 0,
        liked: data['liked'] as bool? ?? false,
      ),
    );
  }

  Future<void> deleteComment(String commentId) async {
    await _client.delete('/v1/posts/comments/$commentId');
  }

  Future<({int count, bool liked})> likePost(String postId) async {
    return _client.post<({int count, bool liked})>(
      '/v1/posts/$postId/like',
      body: {},
      fromJson: (data) => (
        count: (data['like_count'] as num?)?.toInt() ?? 0,
        liked: data['liked'] as bool? ?? false,
      ),
    );
  }

  Future<List<Post>> getRelatedPosts(
    String postId, {
    required double lat,
    required double lng,
  }) async {
    return _client.get<List<Post>>(
      '/v1/posts/$postId/related',
      queryParams: {'lat': lat, 'lng': lng},
      fromJson: (data) => (data['posts'] as List? ?? [])
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> beenHere(String postId) async {
    await _client.post('/v1/posts/$postId/been-here', body: {}, fromJson: (_) => null);
  }

  Future<void> pulse(String postId) async {
    await _client.post('/v1/posts/$postId/pulse', body: {}, fromJson: (_) => null);
  }

  Future<bool> savePost(String postId) async {
    return _client.post<bool>(
      '/v1/posts/$postId/save',
      body: {},
      fromJson: (data) => data['saved'] as bool? ?? false,
    );
  }

  Future<({List<Post> posts, bool hasMore})> savedPosts({int page = 1}) async {
    final posts = await _client.get<List<Post>>(
      '/v1/posts/saved',
      queryParams: {'page': page},
      fromJson: (data) => (data['posts'] as List? ?? [])
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
    return (posts: posts, hasMore: posts.length >= 20);
  }

  Future<({List<Post> posts, bool hasMore})> getUserPosts(String userId, {int page = 1}) async {
    final posts = await _client.get<List<Post>>(
      '/v1/posts/by-user/$userId',
      queryParams: {'page': page},
      fromJson: (data) => (data['posts'] as List? ?? [])
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
    return (posts: posts, hasMore: posts.length >= 20);
  }

  Future<Post> createPost(Map<String, dynamic> body) async {
    return _client.post<Post>(
      '/v1/posts',
      body: body,
      fromJson: (data) => Post.fromJson(data as Map<String, dynamic>),
    );
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(apiClientProvider)),
);
