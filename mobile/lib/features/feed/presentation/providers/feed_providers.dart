import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/post.dart';
import '../../domain/feed_repository.dart';

// ── Paginated feed ─────────────────────────────────────────────────────────

class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

class FeedNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repo;
  final double lat, lng;
  int _page = 1;

  FeedNotifier(this._repo, this.lat, this.lng)
      : super(const FeedState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await _repo.getFeed(lat: lat, lng: lng, page: _page);
      if (mounted) {
        state = FeedState(posts: posts, hasMore: posts.length >= 20);
      }
    } catch (e) {
      if (mounted) {
        state = FeedState(error: e.toString());
      }
    }
  }

  Future<void> refresh() async {
    _page = 1;
    state = const FeedState(isLoading: true);
    await _load();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    _page++;
    try {
      final more = await _repo.getFeed(lat: lat, lng: lng, page: _page);
      if (mounted) {
        state = state.copyWith(
          posts: [...state.posts, ...more],
          isLoadingMore: false,
          hasMore: more.length >= 20,
        );
      }
    } catch (_) {
      _page--;
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  void updatePost(Post updated) {
    final posts = state.posts.map((p) => p.id == updated.id ? updated : p).toList();
    state = state.copyWith(posts: posts);
  }
}

final feedNotifierProvider =
    StateNotifierProvider.family<FeedNotifier, FeedState, (double, double)>(
  (ref, coords) => FeedNotifier(ref.read(feedRepositoryProvider), coords.$1, coords.$2),
);

// ── Post detail ────────────────────────────────────────────────────────────

final postDetailProvider = FutureProvider.family<Post, String>((ref, postId) {
  return ref.read(feedRepositoryProvider).getPost(postId);
});

// ── Related posts ──────────────────────────────────────────────────────────

final relatedPostsProvider =
    FutureProvider.family<List<Post>, (String, double, double)>((ref, args) {
  final (postId, lat, lng) = args;
  return ref.read(feedRepositoryProvider).getRelatedPosts(postId, lat: lat, lng: lng);
});

// ── Flash feed ─────────────────────────────────────────────────────────────

final flashFeedProvider =
    FutureProvider.family<List<Post>, (double, double)>((ref, coords) {
  return ref.read(feedRepositoryProvider).getFlashFeed(lat: coords.$1, lng: coords.$2);
});

// ── Comments ───────────────────────────────────────────────────────────────

class CommentsState {
  final List<PostComment> comments;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final String sort;

  const CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.sort = 'new',
  });

  CommentsState copyWith({
    List<PostComment>? comments,
    bool? isLoading,
    bool? hasMore,
    String? error,
    String? sort,
  }) =>
      CommentsState(
        comments: comments ?? this.comments,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        error: error,
        sort: sort ?? this.sort,
      );
}

class CommentsNotifier extends StateNotifier<CommentsState> {
  final FeedRepository _repo;
  final String postId;
  int _page = 1;

  CommentsNotifier(this._repo, this.postId) : super(const CommentsState(isLoading: true)) {
    load();
  }

  Future<void> load({String? sort}) async {
    final s = sort ?? state.sort;
    _page = 1;
    if (mounted) state = CommentsState(isLoading: true, sort: s);
    try {
      final comments = await _repo.getComments(postId, page: 1, sort: s);
      if (mounted) {
        state = CommentsState(
          comments: comments,
          hasMore: comments.length >= 20,
          sort: s,
        );
      }
    } catch (e) {
      if (mounted) state = CommentsState(error: e.toString(), sort: s);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    _page++;
    try {
      final more = await _repo.getComments(postId, page: _page, sort: state.sort);
      if (mounted) {
        state = state.copyWith(
          comments: [...state.comments, ...more],
          hasMore: more.length >= 20,
        );
      }
    } catch (_) {
      _page--;
    }
  }

  Future<PostComment?> addComment(
    String content, {
    String? parentId,
    List<String> mediaUrls = const [],
  }) async {
    try {
      final comment = await _repo.addComment(postId, content, parentId: parentId, mediaUrls: mediaUrls);
      if (mounted) {
        if (parentId != null) {
          // Append reply under its parent
          final updated = state.comments.map((c) {
            if (c.id == parentId) {
              return c.copyWith(
                replies: [...c.replies, comment],
                replyCount: c.replyCount + 1,
              );
            }
            return c;
          }).toList();
          state = state.copyWith(comments: updated);
        } else {
          state = state.copyWith(comments: [...state.comments, comment]);
        }
      }
      return comment;
    } catch (_) {
      return null;
    }
  }

  Future<void> likeComment(String commentId) async {
    // Optimistic update — find comment at top level or in replies
    final before = state.comments;
    final updated = _toggleCommentLike(state.comments, commentId);
    if (mounted) state = state.copyWith(comments: updated);
    try {
      final result = await _repo.likeComment(commentId);
      final confirmed = _setCommentLike(state.comments, commentId, result.liked, result.count);
      if (mounted) state = state.copyWith(comments: confirmed);
    } catch (_) {
      if (mounted) state = state.copyWith(comments: before);
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _repo.deleteComment(commentId);
      final updated = _markCommentDeleted(state.comments, commentId);
      if (mounted) state = state.copyWith(comments: updated);
    } catch (_) {}
  }

  Future<void> loadReplies(String commentId) async {
    try {
      final replies = await _repo.getCommentReplies(commentId);
      final updated = state.comments.map((c) {
        if (c.id == commentId) {
          return c.copyWith(replies: replies, replyCount: replies.length);
        }
        return c;
      }).toList();
      if (mounted) state = state.copyWith(comments: updated);
    } catch (_) {}
  }

  // Helpers
  List<PostComment> _toggleCommentLike(List<PostComment> comments, String id) =>
      comments.map((c) {
        if (c.id == id) {
          return c.copyWith(
            viewerLiked: !c.viewerLiked,
            likeCount: c.viewerLiked ? c.likeCount - 1 : c.likeCount + 1,
          );
        }
        if (c.replies.isNotEmpty) {
          return c.copyWith(replies: _toggleCommentLike(c.replies, id));
        }
        return c;
      }).toList();

  List<PostComment> _setCommentLike(List<PostComment> comments, String id, bool liked, int count) =>
      comments.map((c) {
        if (c.id == id) return c.copyWith(viewerLiked: liked, likeCount: count);
        if (c.replies.isNotEmpty) {
          return c.copyWith(replies: _setCommentLike(c.replies, id, liked, count));
        }
        return c;
      }).toList();

  List<PostComment> _markCommentDeleted(List<PostComment> comments, String id) =>
      comments.map((c) {
        if (c.id == id) return c.copyWith(isDeleted: true, content: '[deleted]');
        if (c.replies.isNotEmpty) {
          return c.copyWith(replies: _markCommentDeleted(c.replies, id));
        }
        return c;
      }).toList();
}

final commentsProvider =
    StateNotifierProvider.family<CommentsNotifier, CommentsState, String>(
  (ref, postId) => CommentsNotifier(ref.read(feedRepositoryProvider), postId),
);

// ── User posts ─────────────────────────────────────────────────────────────

class UserPostsNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repo;
  final String userId;
  int _page = 1;

  UserPostsNotifier(this._repo, this.userId)
      : super(const FeedState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _repo.getUserPosts(userId, page: _page);
      if (mounted) {
        state = FeedState(posts: result.posts, hasMore: result.hasMore);
      }
    } catch (e) {
      if (mounted) state = FeedState(error: e.toString());
    }
  }

  Future<void> refresh() async {
    _page = 1;
    state = const FeedState(isLoading: true);
    await _load();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    _page++;
    try {
      final result = await _repo.getUserPosts(userId, page: _page);
      if (mounted) {
        state = state.copyWith(
          posts: [...state.posts, ...result.posts],
          isLoadingMore: false,
          hasMore: result.hasMore,
        );
      }
    } catch (_) {
      _page--;
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  void prepend(Post post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }
}

final userPostsProvider =
    StateNotifierProvider.family<UserPostsNotifier, FeedState, String>(
  (ref, userId) => UserPostsNotifier(ref.read(feedRepositoryProvider), userId),
);

// ── Saved posts ────────────────────────────────────────────────────────────

class SavedPostsNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repo;
  int _page = 1;

  SavedPostsNotifier(this._repo) : super(const FeedState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _repo.savedPosts(page: _page);
      if (mounted) state = FeedState(posts: result.posts, hasMore: result.hasMore);
    } catch (e) {
      if (mounted) state = FeedState(error: e.toString());
    }
  }

  Future<void> refresh() async {
    _page = 1;
    state = const FeedState(isLoading: true);
    await _load();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    _page++;
    try {
      final result = await _repo.savedPosts(page: _page);
      if (mounted) {
        state = state.copyWith(
          posts: [...state.posts, ...result.posts],
          isLoadingMore: false,
          hasMore: result.hasMore,
        );
      }
    } catch (_) {
      _page--;
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  void removePost(String postId) {
    state = state.copyWith(posts: state.posts.where((p) => p.id != postId).toList());
  }
}

final savedPostsProvider = StateNotifierProvider<SavedPostsNotifier, FeedState>(
  (ref) => SavedPostsNotifier(ref.read(feedRepositoryProvider)),
);
