import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/theme/app_theme.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class NearbyUser {
  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final String userType;
  final String? currentCity;
  final double distanceM;
  final int trustScore;
  final bool isVerified;
  final List<String> interestTags;
  bool isFollowing;

  NearbyUser({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.bio,
    required this.userType,
    this.currentCity,
    required this.distanceM,
    required this.trustScore,
    required this.isVerified,
    required this.interestTags,
    required this.isFollowing,
  });

  factory NearbyUser.fromJson(Map<String, dynamic> j) => NearbyUser(
        id: j['id'] as String,
        displayName: j['display_name'] as String? ?? 'Hapa User',
        username: j['username'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        bio: j['bio'] as String?,
        userType: j['user_type'] as String? ?? 'local',
        currentCity: j['current_city'] as String?,
        distanceM: (j['distance_m'] as num?)?.toDouble() ?? 0,
        trustScore: j['trust_score'] as int? ?? 0,
        isVerified: j['is_verified'] as bool? ?? false,
        interestTags: (j['interest_tags'] as List?)?.cast<String>() ?? [],
        isFollowing: j['is_following'] as bool? ?? false,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _nearbyPeopleProvider = FutureProvider<List<NearbyUser>>((ref) async {
  Position? pos;
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm != LocationPermission.deniedForever) {
      pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    }
  } catch (_) {}

  return ref.watch(apiClientProvider).get(
    '/v1/users/nearby',
    queryParams: pos != null ? {'lat': pos.latitude, 'lng': pos.longitude} : null,
    fromJson: (d) => (d['users'] as List)
        .map((u) => NearbyUser.fromJson(u as Map<String, dynamic>))
        .toList(),
  );
});

// ── Constants ─────────────────────────────────────────────────────────────────

enum _PeopleFilter { everyone, creators, locals, travelers }

const _userTypeColors = {
  'creator':  Color(0xFF8B5CF6),
  'local':    HapaColors.ochre,
  'traveler': Color(0xFF10B981),
  'explorer': Color(0xFF06B6D4),
};

const _userTypeIcons = {
  'creator':  Icons.star_rounded,
  'local':    Icons.home_rounded,
  'traveler': Icons.flight_rounded,
  'explorer': Icons.explore_rounded,
};

Color _typeColor(String t) => _userTypeColors[t] ?? HapaColors.ochre;
IconData _typeIcon(String t) => _userTypeIcons[t] ?? Icons.person_rounded;

final _avatarPalette = [
  [const Color(0xFFDC7F30), const Color(0xFFF5A623)],
  [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
  [const Color(0xFF047857), const Color(0xFF10B981)],
  [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
  [const Color(0xFF9D174D), const Color(0xFFEC4899)],
];

List<Color> _avatarGradient(String id) {
  final idx = id.codeUnits.fold(0, (a, b) => a + b) % _avatarPalette.length;
  return _avatarPalette[idx];
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchCtrl = TextEditingController();
  _PeopleFilter _filter = _PeopleFilter.everyone;
  final _followLoading = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow(NearbyUser user) async {
    if (_followLoading.contains(user.id)) return;
    setState(() => _followLoading.add(user.id));
    final wasFollowing = user.isFollowing;
    setState(() => user.isFollowing = !wasFollowing);

    try {
      final client = ref.read(apiClientProvider);
      if (wasFollowing) {
        await client.delete('/v1/users/${user.id}/follow');
      } else {
        await client.post(
          '/v1/users/${user.id}/follow',
          body: {},
          fromJson: (_) => null,
        );
      }
    } catch (_) {
      setState(() => user.isFollowing = wasFollowing);
    } finally {
      setState(() => _followLoading.remove(user.id));
    }
  }

  List<NearbyUser> _applyFilters(List<NearbyUser> people) {
    var list = people;

    // Filter by type
    if (_filter != _PeopleFilter.everyone) {
      final type = _filter.name;
      list = list.where((u) => u.userType == type).toList();
    }

    // Search
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((u) =>
        u.displayName.toLowerCase().contains(q) ||
        (u.bio?.toLowerCase().contains(q) ?? false) ||
        u.interestTags.any((t) => t.toLowerCase().contains(q)) ||
        (u.currentCity?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(_nearbyPeopleProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'People Nearby',
                          style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w800, color: HapaColors.deep),
                        ),
                        const Spacer(),
                        peopleAsync.when(
                          data: (p) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: HapaColors.ochre.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${p.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HapaColors.ochre)),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _SearchBar(controller: _searchCtrl, onChanged: () => setState(() {})),
              ),
            ),
          ),

          // Privacy notice
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HapaColors.ochre.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HapaColors.ochre.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: HapaColors.ochre),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only people who\'ve set their profile to discoverable appear here.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: _FilterRow(
              active: _filter,
              onSelect: (f) => setState(() { _filter = f; }),
            ),
          ),

          // Content
          peopleAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => const _SkeletonPersonCard(),
                childCount: 6,
              ),
            ),
            error: (_, __) => SliverFillRemaining(child: _PeopleError(onRetry: () => ref.invalidate(_nearbyPeopleProvider))),
            data: (allPeople) {
              final people = _applyFilters(allPeople);

              if (people.isEmpty) {
                return SliverFillRemaining(child: _EmptyPeople(filter: _filter, query: _searchCtrl.text));
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PersonCard(
                      user: people[i],
                      isCurrentUser: currentUser?.id == people[i].id,
                      isLoading: _followLoading.contains(people[i].id),
                      onFollow: () => _toggleFollow(people[i]),
                    ),
                    childCount: people.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EAE0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        style: const TextStyle(fontSize: 13, color: HapaColors.deep),
        decoration: InputDecoration(
          hintText: 'Search by name, interest, city…',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () { controller.clear(); onChanged(); },
                  child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}

// ── Filter Row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final _PeopleFilter active;
  final void Function(_PeopleFilter) onSelect;
  const _FilterRow({required this.active, required this.onSelect});

  static const _labels = {
    _PeopleFilter.everyone:  (label: 'Everyone', icon: Icons.people_outline),
    _PeopleFilter.creators:  (label: 'Creators',  icon: Icons.star_outline),
    _PeopleFilter.locals:    (label: 'Locals',    icon: Icons.home_outlined),
    _PeopleFilter.travelers: (label: 'Travelers', icon: Icons.flight_outlined),
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _PeopleFilter.values.map((f) {
          final meta = _labels[f]!;
          final isActive = f == active;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? HapaColors.deep : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? HapaColors.deep : const Color(0xFFE5DDD0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(meta.icon, size: 13, color: isActive ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(
                    meta.label,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Person Card ───────────────────────────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  final NearbyUser user;
  final bool isCurrentUser;
  final bool isLoading;
  final VoidCallback onFollow;
  const _PersonCard({required this.user, required this.isCurrentUser, required this.isLoading, required this.onFollow});

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(user.userType);
    final typeIcon = _typeIcon(user.userType);
    final gradient = _avatarGradient(user.id);
    final distText = user.distanceM < 1000
        ? '${user.distanceM.toInt()}m away'
        : '${(user.distanceM / 1000).toStringAsFixed(1)}km away';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                        image: user.avatarUrl != null
                            ? DecorationImage(image: NetworkImage(user.avatarUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: user.avatarUrl == null
                          ? Center(
                              child: Text(
                                user.displayName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Fraunces'),
                              ),
                            )
                          : null,
                    ),
                    // Type badge
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: typeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(typeIcon, size: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: HapaColors.deep),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified_rounded, size: 14, color: Color(0xFF3B82F6)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user.userType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 8, fontWeight: FontWeight.w800,
                                color: typeColor, letterSpacing: 0.6, fontFamily: 'JetBrainsMono',
                              ),
                            ),
                          ),
                          if (user.distanceM > 0) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.near_me_rounded, size: 10, color: Colors.grey.shade400),
                            const SizedBox(width: 2),
                            Text(distText, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          user.bio!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Follow button
                if (!isCurrentUser)
                  _FollowButton(
                    isFollowing: user.isFollowing,
                    isLoading: isLoading,
                    onTap: onFollow,
                  ),
              ],
            ),
          ),
          // Interest tags
          if (user.interestTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  ...user.interestTags.take(4).map((tag) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EAE0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(fontSize: 10, color: HapaColors.muted, fontWeight: FontWeight.w500),
                    ),
                  )),
                  if (user.interestTags.length > 4)
                    Text(
                      '+${user.interestTags.length - 4}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),
                ],
              ),
            ),
          // Trust score bar
          if (user.trustScore > 0)
            Container(
              height: 2,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (user.trustScore / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_typeColor(user.userType).withValues(alpha: 0.3), _typeColor(user.userType)]),
                    borderRadius: const BorderRadius.only(bottomRight: Radius.circular(14)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Follow Button ─────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onTap;
  const _FollowButton({required this.isFollowing, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isFollowing ? const Color(0xFFF0EAE0) : HapaColors.deep,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isFollowing ? const Color(0xFFD9CDB8) : HapaColors.deep),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: HapaColors.ochre),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: isFollowing ? HapaColors.muted : Colors.white,
                ),
              ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonPersonCard extends StatefulWidget {
  const _SkeletonPersonCard();
  @override
  State<_SkeletonPersonCard> createState() => _SkeletonPersonCardState();
}

class _SkeletonPersonCardState extends State<_SkeletonPersonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _bone(52, 52, circle: true),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bone(120, 14), const SizedBox(height: 6),
            _bone(80, 10), const SizedBox(height: 8),
            _bone(double.infinity, 11), const SizedBox(height: 4),
            _bone(160, 11),
          ])),
          const SizedBox(width: 10),
          _bone(70, 32),
        ]),
      ),
    );
  }

  Widget _bone(double w, double h, {bool circle = false}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: Colors.grey.shade200.withValues(alpha: _anim.value),
      borderRadius: circle ? null : BorderRadius.circular(6),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
    ),
  );
}

// ── Error & Empty ─────────────────────────────────────────────────────────────

class _PeopleError extends StatelessWidget {
  final VoidCallback onRetry;
  const _PeopleError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.people_outline, size: 52, color: HapaColors.muted),
        const SizedBox(height: 16),
        const Text('Couldn\'t load nearby people', style: TextStyle(fontFamily: 'Fraunces', fontSize: 16, fontWeight: FontWeight.w700, color: HapaColors.deep)),
        const SizedBox(height: 8),
        Text('Check your location settings and try again.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
      ]),
    ),
  );
}

class _EmptyPeople extends StatelessWidget {
  final _PeopleFilter filter;
  final String query;
  const _EmptyPeople({required this.filter, required this.query});

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: HapaColors.ochre.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline, size: 34, color: HapaColors.ochre),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No results for "$query"' : 'No one nearby right now',
            style: const TextStyle(fontFamily: 'Fraunces', fontSize: 16, fontWeight: FontWeight.w700, color: HapaColors.deep),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Try a different search term or clear the filter.'
                : filter == _PeopleFilter.everyone
                    ? 'Discoverable people who\'ve pinged their location recently will appear here.'
                    : 'No ${filter.name}s are nearby. Try "Everyone" instead.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
