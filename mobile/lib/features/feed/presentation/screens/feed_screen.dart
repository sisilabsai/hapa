import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../providers/feed_providers.dart';
import '../widgets/post_card.dart';
import '../widgets/flash_stories.dart';

final _notifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    return await client.get<int>(
      '/v1/notifications/count',
      fromJson: (d) => (d as Map<String, dynamic>)['count'] as int? ?? 0,
    );
  } catch (_) {
    return 0;
  }
});

final _locationProvider = FutureProvider<Position?>((ref) async {
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }
  }
  return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
});

final _filterProvider = StateProvider<String>((ref) => 'all');

const _filters = [
  ('all', 'All'),
  ('mine', 'My Posts'),
  ('moment', 'Moments'),
  ('review', 'Reviews'),
  ('tip', 'Tips'),
  ('flash', 'Flash'),
  ('guide', 'Guides'),
];

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(_locationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: _FeedAppBar(locationAsync: locationAsync),
      body: locationAsync.when(
        loading: () => _ShimmerFeed(),
        error: (e, _) => _LocationError(onRetry: () => ref.refresh(_locationProvider)),
        data: (pos) {
          if (pos == null) {
            return _LocationPermissionPrompt(onRetry: () => ref.refresh(_locationProvider));
          }
          return _FeedBody(coords: (pos.latitude, pos.longitude));
        },
      ),
    );
  }
}

class _FeedAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final AsyncValue<Position?> locationAsync;
  const _FeedAppBar({required this.locationAsync});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final location = locationAsync.value;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/branding/hapa-wordmark-horizontal.png',
            height: 28,
          ),
          if (location != null)
            const Padding(
              padding: EdgeInsets.only(left: 6, top: 2),
              child: Icon(Icons.radio_button_checked, size: 8, color: Color(0xFF22C55E)),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 22),
          color: HapaColors.muted,
          onPressed: () => context.push('/search'),
          splashRadius: 22,
        ),
        _NotifBell(),

        // Create post button
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 24),
            color: HapaColors.ochre,
            splashRadius: 22,
            onPressed: () => context.push('/posts/new', extra: {
              'lat': location?.latitude,
              'lng': location?.longitude,
              'feedCoords': location != null
                  ? (location.latitude, location.longitude)
                  : null,
            }),
          ),
        ),
        // Profile avatar
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => context.go('/profile'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: HapaColors.ochre.withValues(alpha: 0.12),
              backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
              child: user?.avatarUrl == null
                  ? Text(
                      (user?.displayName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: HapaColors.ochre,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotifBell extends ConsumerWidget {
  const _NotifBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(_notifCountProvider);
    final count = countAsync.value ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 22),
          color: HapaColors.muted,
          onPressed: () => context.push('/notifications'),
          splashRadius: 22,
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedBody extends ConsumerStatefulWidget {
  final (double, double) coords;
  const _FeedBody({required this.coords});

  @override
  ConsumerState<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends ConsumerState<_FeedBody> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 400) {
      final filter = ref.read(_filterProvider);
      final currentUser = ref.read(currentUserProvider);
      if (filter == 'mine' && currentUser != null) {
        ref.read(userPostsProvider(currentUser.id).notifier).loadMore();
      } else {
        ref.read(feedNotifierProvider(widget.coords).notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedNotifierProvider(widget.coords));
    final flashAsync = ref.watch(flashFeedProvider(widget.coords));
    final filter = ref.watch(_filterProvider);
    final currentUser = ref.watch(currentUserProvider);

    // Conditionally watch the mine feed when that filter is active
    FeedState? mineState;
    if (filter == 'mine' && currentUser != null) {
      mineState = ref.watch(userPostsProvider(currentUser.id));
    }

    final FeedState activeState = mineState ?? feedState;

    final posts = filter == 'mine'
        ? (mineState?.posts ?? [])
        : filter == 'all'
            ? feedState.posts
            : feedState.posts.where((p) {
                if (filter == 'moment') {
                  return p.postType == 'moment' || p.postType == 'location_post';
                }
                return p.postType == filter;
              }).toList();

    return RefreshIndicator(
      color: HapaColors.ochre,
      displacement: 20,
      onRefresh: () async {
        if (filter == 'mine' && currentUser != null) {
          await ref.read(userPostsProvider(currentUser.id).notifier).refresh();
        } else {
          await ref.read(feedNotifierProvider(widget.coords).notifier).refresh();
        }
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Flash banner (only for non-mine filters)
          if (filter != 'mine')
            flashAsync.whenOrNull(
              data: (flashes) => flashes.isEmpty
                  ? null
                  : SliverToBoxAdapter(child: FlashStories(posts: flashes)),
            ) ?? const SliverToBoxAdapter(child: SizedBox.shrink()),

          // Filter tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterTabsDelegate(
              filter: filter,
              onFilter: (f) => ref.read(_filterProvider.notifier).state = f,
            ),
          ),

          // Section header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(width: 3, height: 14, color: HapaColors.ochre),
                  const SizedBox(width: 8),
                  Text(
                    filter == 'mine' ? 'Your posts' : 'Happening near you',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  if (posts.isNotEmpty)
                    Text(
                      '${posts.length}${activeState.hasMore ? '+' : ''} posts',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Feed content
          if (activeState.isLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => _ShimmerPostCard(),
                childCount: 5,
              ),
            )
          else if (activeState.error != null)
            SliverToBoxAdapter(child: _FeedError(
              onRetry: () {
                if (filter == 'mine' && currentUser != null) {
                  ref.read(userPostsProvider(currentUser.id).notifier).refresh();
                } else {
                  ref.read(feedNotifierProvider(widget.coords).notifier).refresh();
                }
              },
            ))
          else if (posts.isEmpty)
            SliverToBoxAdapter(child: _EmptyFeed(filter: filter))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => PostCard(
                  post: posts[i],
                  feedCoords: filter == 'mine' ? null : widget.coords,
                )
                    .animate(delay: Duration(milliseconds: i * 40))
                    .fadeIn(duration: 250.ms)
                    .slideY(begin: 0.08, end: 0, duration: 250.ms),
                childCount: posts.length,
              ),
            ),

          // Load more indicator
          if (activeState.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: HapaColors.ochre,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),

          // End marker
          if (!activeState.hasMore && posts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    filter == 'mine' ? '— all your posts —' : '— you\'ve seen it all —',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ),
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

// ── Filter tabs ─────────────────────────────────────────────────────────────

class _FilterTabsDelegate extends SliverPersistentHeaderDelegate {
  final String filter;
  final ValueChanged<String> onFilter;

  const _FilterTabsDelegate({required this.filter, required this.onFilter});

  @override
  double get minExtent => 42;
  @override
  double get maxExtent => 42;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 42,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _filters.map((f) {
          final (key, label) = f;
          final active = filter == key;
          return GestureDetector(
            onTap: () => onFilter(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: active ? HapaColors.ochre : const Color(0xFFF0EBE0),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : HapaColors.muted,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterTabsDelegate old) =>
      old.filter != filter || old.onFilter != onFilter;
}

// ── Shimmer loading ─────────────────────────────────────────────────────────

class _ShimmerFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => _ShimmerPostCard(),
    );
  }
}

class _ShimmerPostCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEEE),
      highlightColor: const Color(0xFFFAFAFA),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fake image
            Container(height: 160, color: Colors.grey),
            const SizedBox(height: 12),
            // Author row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const CircleAvatar(radius: 16, backgroundColor: Colors.grey),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 10, color: Colors.grey),
                      const SizedBox(height: 5),
                      Container(width: 60, height: 8, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 10, color: Colors.grey),
                  const SizedBox(height: 6),
                  Container(width: 200, height: 10, color: Colors.grey),
                  const SizedBox(height: 6),
                  Container(width: 140, height: 10, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ── States ──────────────────────────────────────────────────────────────────

class _FeedError extends StatelessWidget {
  final VoidCallback onRetry;
  const _FeedError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              'Could not load feed',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: HapaColors.ochre),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final String filter;
  const _EmptyFeed({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_searching_rounded, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              filter == 'mine'
                  ? 'No posts yet'
                  : filter == 'all'
                      ? 'Nothing nearby yet'
                      : 'No ${_filters.firstWhere((f) => f.$1 == filter, orElse: () => ('', 'posts')).$2.toLowerCase()} nearby',
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HapaColors.deep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filter == 'mine'
                  ? 'Tap + to create your first post!'
                  : 'Be the first to share what\'s happening around you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LocationError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Location error', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _LocationPermissionPrompt extends StatelessWidget {
  final VoidCallback onRetry;
  const _LocationPermissionPrompt({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 60, color: HapaColors.ochre),
            const SizedBox(height: 20),
            Text(
              'Hapa needs your location',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your location lets us show you what\'s happening right around you. It\'s never shared without your permission.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: HapaColors.ochre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: const Text(
                'ENABLE LOCATION',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
