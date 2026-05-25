import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import 'creator_apply_sheet.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/post_card.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class CreatorProfile {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String bio;
  final String tier;
  final String status;
  final String city;
  final String contentFocus;
  final int totalReach;
  final double engagementScore;
  final int beenHereTotal;
  final int followerCount;
  final int postCount;
  final bool isFollowing;
  final double monthlyEarnings;

  const CreatorProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.bio,
    required this.tier,
    required this.status,
    required this.city,
    required this.contentFocus,
    required this.totalReach,
    required this.engagementScore,
    required this.beenHereTotal,
    required this.followerCount,
    required this.postCount,
    required this.isFollowing,
    this.monthlyEarnings = 0,
  });

  factory CreatorProfile.fromJson(Map<String, dynamic> j) => CreatorProfile(
    id: j['id'] as String? ?? '',
    userId: j['user_id'] as String? ?? '',
    displayName: j['display_name'] as String? ?? 'Creator',
    avatarUrl: j['avatar_url'] as String?,
    bio: j['bio'] as String? ?? '',
    tier: j['tier'] as String? ?? 'rising_voice',
    status: j['status'] as String? ?? 'pending',
    city: j['city'] as String? ?? '',
    contentFocus: j['content_focus'] as String? ?? '',
    totalReach: j['total_reach'] as int? ?? 0,
    engagementScore: (j['engagement_score'] as num?)?.toDouble() ?? 0.0,
    beenHereTotal: j['been_here_total'] as int? ?? 0,
    followerCount: j['follower_count'] as int? ?? 0,
    postCount: j['post_count'] as int? ?? 0,
    isFollowing: j['is_following'] as bool? ?? false,
    monthlyEarnings: (j['monthly_earnings'] as num?)?.toDouble() ?? 0.0,
  );

  CreatorProfile copyWith({bool? isFollowing, int? followerCount}) => CreatorProfile(
    id: id, userId: userId, displayName: displayName, avatarUrl: avatarUrl,
    bio: bio, tier: tier, status: status, city: city, contentFocus: contentFocus,
    totalReach: totalReach, engagementScore: engagementScore, beenHereTotal: beenHereTotal,
    followerCount: followerCount ?? this.followerCount,
    postCount: postCount,
    isFollowing: isFollowing ?? this.isFollowing,
    monthlyEarnings: monthlyEarnings,
  );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _creatorProvider = FutureProvider.family.autoDispose<CreatorProfile, String>((ref, id) {
  return ref.watch(apiClientProvider).get(
    '/v1/creators/$id',
    fromJson: (d) => CreatorProfile.fromJson(d as Map<String, dynamic>),
  );
});

// ── Tier config ───────────────────────────────────────────────────────────────

const _tierConfig = {
  'rising_voice': (label: 'Rising Voice', color: Color(0xFF10B981)),
  'local_voice':  (label: 'Local Voice',  color: Color(0xFF6366F1)),
  'city_voice':   (label: 'City Voice',   color: Color(0xFFF59E0B)),
};

// ── Screen ────────────────────────────────────────────────────────────────────

class CreatorProfileScreen extends ConsumerStatefulWidget {
  final String id;
  const CreatorProfileScreen({super.key, required this.id});

  @override
  ConsumerState<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends ConsumerState<CreatorProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool? _followOverride;       // null = use server value
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openApplySheet(CreatorProfile creator) async {
    final applied = await showCreatorApplySheet(
      context,
      prefillCity: creator.city.isNotEmpty ? creator.city : null,
    );
    if (applied && mounted) {
      ref.invalidate(_creatorProvider(widget.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Application submitted — we'll review it within 48 hours"),
          backgroundColor: HapaColors.deep,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleFollow(CreatorProfile creator) async {
    if (_followLoading) return;
    HapticFeedback.selectionClick();

    final currentlyFollowing = _followOverride ?? creator.isFollowing;
    setState(() {
      _followLoading = true;
      _followOverride = !currentlyFollowing;
    });

    try {
      final client = ref.read(apiClientProvider);
      if (currentlyFollowing) {
        await client.delete('/v1/users/${creator.userId}/follow');
      } else {
        await client.post<void>(
          '/v1/users/${creator.userId}/follow',
          body: {},
          fromJson: (_) {},
        );
      }
    } catch (_) {
      if (mounted) setState(() => _followOverride = currentlyFollowing);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creatorAsync = ref.watch(_creatorProvider(widget.id));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: creatorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: HapaColors.ochre)),
        error: (e, _) => _ErrorBody(onRetry: () => ref.invalidate(_creatorProvider(widget.id))),
        data: (creator) => _CreatorBody(
          creator: creator,
          tabs: _tabs,
          isOwner: creator.userId == currentUserId,
          followOverride: _followOverride,
          followLoading: _followLoading,
          onFollowTap: () => _toggleFollow(creator),
          onApplyTap: () => _openApplySheet(creator),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CreatorBody extends StatelessWidget {
  final CreatorProfile creator;
  final TabController tabs;
  final bool isOwner;
  final bool? followOverride;
  final bool followLoading;
  final VoidCallback onFollowTap;
  final VoidCallback onApplyTap;

  const _CreatorBody({
    required this.creator,
    required this.tabs,
    required this.isOwner,
    required this.followOverride,
    required this.followLoading,
    required this.onFollowTap,
    required this.onApplyTap,
  });

  bool get isFollowing => followOverride ?? creator.isFollowing;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _CreatorAppBar(creator: creator, isOwner: isOwner, isFollowing: isFollowing,
            followLoading: followLoading, onFollowTap: onFollowTap),
        _StatsSliver(creator: creator, isOwner: isOwner, isFollowing: isFollowing,
            followLoading: followLoading, onFollowTap: onFollowTap, onApplyTap: onApplyTap),
        SliverFillRemaining(
          hasScrollBody: true,
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF0EBE0))),
                ),
                child: TabBar(
                  controller: tabs,
                  labelColor: HapaColors.ochre,
                  unselectedLabelColor: HapaColors.muted,
                  indicatorColor: HapaColors.ochre,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: const [Tab(text: 'POSTS'), Tab(text: 'ABOUT')],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: tabs,
                  children: [
                    _PostsTab(userId: creator.userId),
                    _AboutTab(creator: creator, isOwner: isOwner, onApplyTap: onApplyTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _CreatorAppBar extends StatelessWidget {
  final CreatorProfile creator;
  final bool isOwner;
  final bool isFollowing;
  final bool followLoading;
  final VoidCallback onFollowTap;

  const _CreatorAppBar({
    required this.creator,
    required this.isOwner,
    required this.isFollowing,
    required this.followLoading,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    final tier = _tierConfig[creator.tier];

    return SliverAppBar(
      pinned: true,
      expandedHeight: 220,
      backgroundColor: HapaColors.deep,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'Edit profile',
            onPressed: () => context.go('/profile'),
          )
        else
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {},
          ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Abstract background pattern
            _CreatorCoverArt(userId: creator.userId),
            // Bottom gradient
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, HapaColors.deep],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            // Profile content
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: HapaColors.ochre.withValues(alpha: 0.2),
                      backgroundImage: creator.avatarUrl != null
                          ? NetworkImage(creator.avatarUrl!) : null,
                      child: creator.avatarUrl == null
                          ? Text(
                              creator.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                color: HapaColors.ochre,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          creator.displayName,
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (creator.city.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 11, color: HapaColors.ochre),
                              const SizedBox(width: 2),
                              Text(
                                creator.city,
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        if (tier != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: tier.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: tier.color.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 9, color: tier.color),
                                const SizedBox(width: 4),
                                Text(
                                  tier.label.toUpperCase(),
                                  style: TextStyle(
                                    color: tier.color,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generative cover art ──────────────────────────────────────────────────────

class _CreatorCoverArt extends StatelessWidget {
  final String userId;
  const _CreatorCoverArt({required this.userId});

  @override
  Widget build(BuildContext context) {
    // Deterministic color from user ID
    final hash = userId.codeUnits.fold(0, (a, b) => a + b);
    final colors = [
      [const Color(0xFF1E3A5F), const Color(0xFF0D1B2A)],
      [const Color(0xFF2D1B69), const Color(0xFF11071F)],
      [const Color(0xFF1A3A2A), const Color(0xFF0A1F15)],
      [const Color(0xFF3A1A1A), const Color(0xFF1F0A0A)],
    ];
    final pair = colors[hash % colors.length];

    return CustomPaint(
      painter: _CoverArtPainter(
        color1: pair[0],
        color2: pair[1],
        seed: hash,
      ),
    );
  }
}

class _CoverArtPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final int seed;
  const _CoverArtPainter({required this.color1, required this.color2, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color1, color2],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final rng = math.Random(seed);
    final circlePaint = Paint()..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final radius = 30.0 + rng.nextDouble() * 80;
      circlePaint.color = Colors.white.withValues(alpha: 0.04 + rng.nextDouble() * 0.06);
      circlePaint.strokeWidth = 1 + rng.nextDouble() * 2;
      canvas.drawCircle(Offset(cx, cy), radius, circlePaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Stats sliver ──────────────────────────────────────────────────────────────

class _StatsSliver extends StatelessWidget {
  final CreatorProfile creator;
  final bool isOwner;
  final bool isFollowing;
  final bool followLoading;
  final VoidCallback onFollowTap;
  final VoidCallback onApplyTap;

  const _StatsSliver({
    required this.creator,
    required this.isOwner,
    required this.isFollowing,
    required this.followLoading,
    required this.onFollowTap,
    required this.onApplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCreator = creator.id.isNotEmpty;

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                _StatChip(value: _fmt(creator.followerCount), label: 'Followers'),
                _StatChip(value: _fmt(creator.postCount), label: 'Posts'),
                if (isCreator) ...[
                  _StatChip(
                    value: '${(creator.engagementScore * 100).toStringAsFixed(1)}%',
                    label: 'Engagement',
                  ),
                  _StatChip(value: _fmt(creator.totalReach), label: 'Reach'),
                ] else
                  _StatChip(value: _fmt(creator.beenHereTotal), label: 'Been Here'),
              ],
            ),
            const SizedBox(height: 14),

            if (isOwner) ...[
              // Owner: Edit profile + creator program CTA
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go('/profile'),
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('Edit Profile',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: HapaColors.deep,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isCreator ? null : onApplyTap,
                      icon: Icon(
                        isCreator ? Icons.verified_outlined : Icons.stars_outlined,
                        size: 15,
                      ),
                      label: Text(
                        isCreator ? 'Creator Hub' : 'Apply as Creator',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HapaColors.ochre,
                        side: const BorderSide(color: HapaColors.ochre),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              // Creator status banner
              if (isCreator && creator.status == 'pending') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded, size: 13, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          "Creator application under review — we'll notify you within 48h",
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Guest: Follow + Message
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _FollowButton(
                      isFollowing: isFollowing,
                      loading: followLoading,
                      onTap: onFollowTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.message_outlined, size: 15),
                      label: const Text('Message', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HapaColors.deep,
                        side: const BorderSide(color: Color(0xFFE0D8C8)),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: HapaColors.deep,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Follow button ─────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool loading;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: isFollowing
          ? OutlinedButton.icon(
              onPressed: loading ? null : onTap,
              icon: loading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: HapaColors.muted),
                    )
                  : const Icon(Icons.check_rounded, size: 15),
              label: const Text('Following', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: HapaColors.muted,
                side: const BorderSide(color: Color(0xFFD0C9B8)),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )
          : FilledButton.icon(
              onPressed: loading ? null : onTap,
              icon: loading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_rounded, size: 15),
              label: const Text('Follow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: HapaColors.ochre,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
    );
  }
}

// ── Posts tab ─────────────────────────────────────────────────────────────────

class _PostsTab extends ConsumerStatefulWidget {
  final String userId;
  const _PostsTab({required this.userId});

  @override
  ConsumerState<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends ConsumerState<_PostsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(userPostsProvider(widget.userId));

    if (state.isLoading && state.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: HapaColors.ochre, strokeWidth: 2));
    }

    if (state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No posts yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.extentAfter < 200 &&
            state.hasMore &&
            !state.isLoadingMore) {
          ref.read(userPostsProvider(widget.userId).notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= state.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(
                  color: HapaColors.ochre, strokeWidth: 2)),
            );
          }
          return PostCard(post: state.posts[i]);
        },
      ),
    );
  }
}

// ── About tab ─────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final CreatorProfile creator;
  final bool isOwner;
  final VoidCallback onApplyTap;
  const _AboutTab({required this.creator, required this.isOwner, required this.onApplyTap});

  @override
  Widget build(BuildContext context) {
    final isCreator = creator.id.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Bio
        if (creator.bio.isNotEmpty) ...[
          _AboutSection(
            icon: Icons.person_outline,
            title: 'BIO',
            child: Text(
              creator.bio,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.55),
            ),
          ),
          const SizedBox(height: 16),
        ] else if (isOwner) ...[
          _AboutSection(
            icon: Icons.person_outline,
            title: 'BIO',
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: Text(
                'Add a bio to tell people about yourself →',
                style: TextStyle(fontSize: 14, color: HapaColors.ochre.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Creator focus — only show if they're a creator
        if (isCreator) ...[
          _AboutSection(
            icon: Icons.star_outline,
            title: 'CREATOR FOCUS',
            child: Text(
              creator.contentFocus.isNotEmpty ? creator.contentFocus : 'Not specified',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 16),

          _AboutSection(
            icon: Icons.bar_chart_rounded,
            title: 'IMPACT',
            child: Column(
              children: [
                _ImpactRow('Total Reach', _fmt(creator.totalReach), Icons.visibility_outlined),
                _ImpactRow('Been Here', _fmt(creator.beenHereTotal), Icons.where_to_vote_outlined),
                _ImpactRow(
                  'Engagement Rate',
                  '${(creator.engagementScore * 100).toStringAsFixed(1)}%',
                  Icons.trending_up_rounded,
                ),
                if (isOwner && creator.monthlyEarnings > 0)
                  _ImpactRow(
                    'Monthly Earnings',
                    'UGX ${creator.monthlyEarnings.toStringAsFixed(0)}',
                    Icons.account_balance_wallet_outlined,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _AboutSection(
            icon: Icons.verified_outlined,
            title: 'TIER',
            child: _TierDisplay(tier: creator.tier),
          ),
          const SizedBox(height: 16),
        ],

        // Owner non-creator: creator program CTA
        if (isOwner && !isCreator) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: HapaColors.ochre.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: HapaColors.ochre, size: 18),
                    const SizedBox(width: 8),
                    const Text('Become a Hapa Creator',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                            color: HapaColors.deep)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your local knowledge, grow an audience, and earn from your content. '
                  'Creators get access to analytics, tips, and exclusive features.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onApplyTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: HapaColors.ochre,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: const Text('Apply to Creator Program',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _AboutSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _AboutSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: HapaColors.ochre),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ImpactRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HapaColors.deep,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }
}

class _TierDisplay extends StatelessWidget {
  final String tier;
  const _TierDisplay({required this.tier});

  @override
  Widget build(BuildContext context) {
    final tiers = [
      ('rising_voice', 'Rising Voice', 'Just getting started — building your audience', Icons.trending_up_rounded, const Color(0xFF10B981)),
      ('local_voice', 'Local Voice', 'Established creator with strong local engagement', Icons.star_rounded, const Color(0xFF6366F1)),
      ('city_voice', 'City Voice', 'Top creator — the voice of the city', Icons.verified_rounded, const Color(0xFFF59E0B)),
    ];

    return Column(
      children: tiers.map((t) {
        final active = tier == t.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: active
                      ? t.$5.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(t.$4, size: 16, color: active ? t.$5 : Colors.grey.shade300),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? HapaColors.deep : Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      t.$3,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.$5.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    'CURRENT',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: t.$5,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Creator not found', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}
