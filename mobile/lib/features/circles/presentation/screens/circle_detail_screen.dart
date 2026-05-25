import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'circles_screen.dart';

// ── Post model (circle context) ───────────────────────────────────────────────

class _CirclePost {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String content;
  final List<String> mediaUrls;
  final String postType;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final DateTime createdAt;

  const _CirclePost({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.content,
    required this.mediaUrls,
    required this.postType,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.createdAt,
  });

  factory _CirclePost.fromJson(Map<String, dynamic> j) => _CirclePost(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String? ?? 'Hapa User',
        avatarUrl: (j['avatar_url'] as String?)?.isEmpty == true ? null : j['avatar_url'] as String?,
        content: j['content'] as String? ?? '',
        mediaUrls: (j['media_urls'] as List?)?.cast<String>() ?? [],
        postType: j['post_type'] as String? ?? 'story',
        likeCount: j['like_count'] as int? ?? 0,
        commentCount: j['comment_count'] as int? ?? 0,
        isLiked: j['is_liked'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _circleDetailProvider = FutureProvider.family<Circle, String>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get<Map<String, dynamic>>(
    '/v1/circles/$id',
    fromJson: (d) => d as Map<String, dynamic>,
  );
  return Circle.fromJson(data);
});

final _circlePostsProvider = FutureProvider.family<List<_CirclePost>, String>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get<Map<String, dynamic>>(
    '/v1/circles/$id/posts',
    queryParams: {'limit': '30'},
    fromJson: (d) => d as Map<String, dynamic>,
  );
  final list = data['posts'] as List? ?? [];
  return list.map((e) => _CirclePost.fromJson(e as Map<String, dynamic>)).toList();
});

const _categoryEmoji = {
  'food_dining': '🍽️',
  'nightlife': '🌙',
  'arts_culture': '🎨',
  'business_networking': '💼',
  'sports_fitness': '⚽',
  'faith_community': '🕊️',
  'family_parenting': '👨‍👩‍👧',
  'fashion_style': '👗',
  'music_events': '🎶',
  'street_life': '🏙️',
  'travel': '✈️',
  'tech': '💻',
  'nature_outdoors': '🌿',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class CircleDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const CircleDetailScreen({super.key, required this.id});

  @override
  ConsumerState<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends ConsumerState<CircleDetailScreen> {
  bool? _memberOverride;
  bool _toggling = false;

  Future<void> _toggleMembership(Circle circle) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final joining = !((_memberOverride ?? circle.isMember));
    try {
      final client = ref.read(apiClientProvider);
      if (joining) {
        await client.post<void>('/v1/circles/${widget.id}/join', body: {}, fromJson: (_) {});
      } else {
        await client.delete('/v1/circles/${widget.id}/join');
      }
      setState(() => _memberOverride = joining);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final circleAsync = ref.watch(_circleDetailProvider(widget.id));
    final postsAsync = ref.watch(_circlePostsProvider(widget.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: circleAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: HapaColors.ochre, strokeWidth: 2),
        ),
        error: (_, __) => const Center(child: Text('Circle not found')),
        data: (circle) {
          final isMember = _memberOverride ?? circle.isMember;
          return CustomScrollView(
            slivers: [
              _buildAppBar(circle, isMember),
              _buildHeader(circle, isMember),
              _buildPostsSection(postsAsync, circle),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(Circle circle, bool isMember) {
    final emoji = _categoryEmoji[circle.category] ?? '⭕';
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: HapaColors.deep,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              circle.name,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HapaColors.deep,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          child: GestureDetector(
            onTap: () => _toggleMembership(circle),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isMember ? Colors.transparent : HapaColors.ochre,
                border: Border.all(
                  color: isMember ? Colors.grey.shade300 : HapaColors.ochre,
                ),
              ),
              child: _toggling
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: isMember ? HapaColors.ochre : Colors.white,
                      ),
                    )
                  : Text(
                      isMember ? 'JOINED' : 'JOIN',
                      style: TextStyle(
                        color: isMember ? Colors.grey.shade500 : Colors.white,
                        fontSize: 10,
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Circle circle, bool isMember) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (circle.description.isNotEmpty)
              Text(
                circle.description,
                style: TextStyle(color: HapaColors.muted, fontSize: 14, height: 1.5),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatChip(
                  icon: Icons.people_outline,
                  label: '${circle.memberCount} members',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.location_city_outlined,
                  label: circle.city,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsSection(
    AsyncValue<List<_CirclePost>> postsAsync,
    Circle circle,
  ) {
    return postsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: HapaColors.ochre, strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Could not load posts')),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Text('📝', style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 16),
                  const Text(
                    'No posts here yet',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 16,
                      color: HapaColors.deep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Posts tagged ${_categoryEmoji[circle.category] ?? ''} will appear here.',
                    style: TextStyle(color: HapaColors.muted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PostCard(post: posts[i]),
              ),
              childCount: posts.length,
            ),
          ),
        );
      },
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final _CirclePost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/posts/${post.id}'),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: HapaColors.ochre.withValues(alpha: 0.15),
                  backgroundImage: post.avatarUrl != null
                      ? NetworkImage(post.avatarUrl!)
                      : null,
                  child: post.avatarUrl == null
                      ? Text(
                          post.displayName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: HapaColors.ochre,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: HapaColors.deep,
                        ),
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                post.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HapaColors.deep,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            if (post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                child: Image.network(
                  post.mediaUrls.first,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: post.isLiked ? const Color(0xFFEF4444) : Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(width: 14),
                Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: HapaColors.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: HapaColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
