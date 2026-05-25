import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/models/post.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _Place {
  final String id, name, category;
  final double? ratingAvg;
  final String? coverUrl, address, city;
  _Place({
    required this.id, required this.name, required this.category,
    this.ratingAvg, this.coverUrl, this.address, this.city,
  });
  factory _Place.fromJson(Map<String, dynamic> j) => _Place(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? 'place',
        ratingAvg: (j['rating_avg'] as num?)?.toDouble(),
        coverUrl: j['cover_url'] as String?,
        address: j['address'] as String?,
        city: j['city'] as String?,
      );
}

class _Person {
  final String id, displayName, userType;
  final String? avatarUrl, bio, currentCity;
  final int trustScore;
  final bool isVerified, isFollowing;
  final List<String> interestTags;
  _Person({
    required this.id, required this.displayName, required this.userType,
    this.avatarUrl, this.bio, this.currentCity,
    this.trustScore = 0, this.isVerified = false, this.isFollowing = false,
    this.interestTags = const [],
  });
  factory _Person.fromJson(Map<String, dynamic> j) => _Person(
        id: j['id'] as String,
        displayName: j['display_name'] as String? ?? 'Hapa User',
        userType: j['user_type'] as String? ?? 'explorer',
        avatarUrl: j['avatar_url'] as String?,
        bio: j['bio'] as String?,
        currentCity: j['current_city'] as String?,
        trustScore: j['trust_score'] as int? ?? 0,
        isVerified: j['is_verified'] as bool? ?? false,
        isFollowing: j['is_following'] as bool? ?? false,
        interestTags: (j['interest_tags'] as List?)?.cast<String>() ?? [],
      );
}

class _SearchResults {
  final List<_Place> places;
  final List<Post> posts;
  final List<_Person> people;
  const _SearchResults({
    this.places = const [], this.posts = const [], this.people = const [],
  });
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _queryProvider = StateProvider<String>((ref) => '');

final _resultsProvider = FutureProvider.autoDispose.family<_SearchResults, String>((ref, query) async {
  if (query.length < 2) return const _SearchResults();
  final client = ref.watch(apiClientProvider);

  final results = await Future.wait([
    client.get<List<_Place>>(
      '/v1/search',
      queryParams: {'q': query, 'type': 'businesses', 'limit': '10'},
      fromJson: (d) => ((d['results'] as List?) ?? [])
          .map((p) => _Place.fromJson(p as Map<String, dynamic>))
          .toList(),
    ).catchError((_) => <_Place>[]),
    client.get<List<Post>>(
      '/v1/search',
      queryParams: {'q': query, 'type': 'posts', 'limit': '10'},
      fromJson: (d) => ((d['results'] as List?) ?? [])
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
    ).catchError((_) => <Post>[]),
    client.get<List<_Person>>(
      '/v1/users/search',
      queryParams: {'q': query},
      fromJson: (d) => ((d['users'] as List?) ?? [])
          .map((p) => _Person.fromJson(p as Map<String, dynamic>))
          .toList(),
    ).catchError((_) => <_Person>[]),
  ]);

  return _SearchResults(
    places: results[0] as List<_Place>,
    posts: results[1] as List<Post>,
    people: results[2] as List<_Person>,
  );
});

// ── Screen ────────────────────────────────────────────────────────────────────

enum _Tab { all, places, posts, people }

const _trending = [
  'Coffee', 'Rooftop', 'Sunset', 'Street Food',
  'Art Gallery', 'Live Music', 'Markets', 'Hidden Gems',
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  final _recentSearches = <String>[];
  _Tab _tab = _Tab.all;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      setState(() => _tab = _Tab.values[_tabCtrl.index]);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(_queryProvider.notifier).state = v.trim();
    });
  }

  void _submitSearch(String v) {
    final q = v.trim();
    if (q.length >= 2 && !_recentSearches.contains(q)) {
      setState(() {
        _recentSearches.insert(0, q);
        if (_recentSearches.length > 8) _recentSearches.removeLast();
      });
    }
    ref.read(_queryProvider.notifier).state = q;
  }

  void _setQuery(String q) {
    _searchCtrl.text = q;
    _submitSearch(q);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_queryProvider);
    final resultsAsync = ref.watch(_resultsProvider(query));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: _SearchBar(
        ctrl: _searchCtrl,
        focus: _focus,
        onChanged: _onChanged,
        onSubmit: _submitSearch,
        onBack: () => context.pop(),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: HapaColors.ochre,
              unselectedLabelColor: Colors.grey.shade500,
              indicatorColor: HapaColors.ochre,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Places'),
                Tab(text: 'Posts'),
                Tab(text: 'People'),
              ],
            ),
          ),

          Expanded(
            child: query.length < 2
                ? _EmptyState(
                    recentSearches: _recentSearches,
                    onTrending: _setQuery,
                    onRecent: _setQuery,
                    onClearRecent: () => setState(_recentSearches.clear),
                  )
                : resultsAsync.when(
                    loading: () => _SearchSkeleton(),
                    error: (_, __) => _ErrorState(onRetry: () => ref.invalidate(_resultsProvider(query))),
                    data: (results) => _ResultsView(
                      results: results,
                      tab: _tab,
                      tabCtrl: _tabCtrl,
                      query: query,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;
  const _SearchBar({
    required this.ctrl, required this.focus,
    required this.onChanged, required this.onSubmit, required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 44,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: Colors.grey.shade700,
        onPressed: onBack,
        splashRadius: 20,
      ),
      title: TextField(
        controller: ctrl,
        focusNode: focus,
        onChanged: onChanged,
        onSubmitted: onSubmit,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search places, posts, people…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      actions: [
        if (ctrl.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: Colors.grey.shade500,
            onPressed: () {
              ctrl.clear();
              onChanged('');
            },
            splashRadius: 20,
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      ),
    );
  }
}

// ── Empty / Pre-search state ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onTrending;
  final ValueChanged<String> onRecent;
  final VoidCallback onClearRecent;
  const _EmptyState({
    required this.recentSearches, required this.onTrending,
    required this.onRecent, required this.onClearRecent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // Recent searches
        if (recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Text('Recent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
              const Spacer(),
              GestureDetector(
                onTap: onClearRecent,
                child: Text('Clear', style: TextStyle(fontSize: 12, color: HapaColors.ochre)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recentSearches.map((q) => GestureDetector(
              onTap: () => onRecent(q),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(q, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 28),
        ],

        // Trending topics
        Text(
          'Trending on Hapa',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trending.asMap().entries.map((e) {
            final gradient = [
              [const Color(0xFFD97706), const Color(0xFFF59E0B)],
              [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
              [const Color(0xFF059669), const Color(0xFF34D399)],
              [const Color(0xFFDC2626), const Color(0xFFF87171)],
              [const Color(0xFF2563EB), const Color(0xFF60A5FA)],
            ][e.key % 5];
            return GestureDetector(
              onTap: () => onTrending(e.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '# ${e.value}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        // Categories
        Text(
          'Explore by Category',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 3,
          children: [
            _CategoryTile('🍽️', 'Restaurants', onTap: () => onTrending('restaurant')),
            _CategoryTile('☕', 'Cafés', onTap: () => onTrending('cafe')),
            _CategoryTile('🎭', 'Arts & Culture', onTap: () => onTrending('art gallery')),
            _CategoryTile('🏖️', 'Outdoors', onTap: () => onTrending('outdoor')),
            _CategoryTile('🛍️', 'Shopping', onTap: () => onTrending('market')),
            _CategoryTile('🎵', 'Nightlife', onTap: () => onTrending('nightlife')),
          ],
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _CategoryTile(this.emoji, this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Results ───────────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final _SearchResults results;
  final _Tab tab;
  final TabController tabCtrl;
  final String query;
  const _ResultsView({
    required this.results, required this.tab,
    required this.tabCtrl, required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabCtrl,
      children: [
        _AllResults(results: results, query: query),
        _PlacesList(places: results.places, query: query),
        _PostsList(posts: results.posts, query: query),
        _PeopleList(people: results.people, query: query),
      ],
    );
  }
}

// All tab
class _AllResults extends StatelessWidget {
  final _SearchResults results;
  final String query;
  const _AllResults({required this.results, required this.query});

  @override
  Widget build(BuildContext context) {
    final total = results.places.length + results.posts.length + results.people.length;
    if (total == 0) return _NoResults(query: query);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        if (results.places.isNotEmpty) ...[
          _SectionHeader('Places', results.places.length, onSeeAll: null),
          ...results.places.take(3).map((p) => _PlaceResultTile(place: p)),
        ],
        if (results.posts.isNotEmpty) ...[
          _SectionHeader('Posts', results.posts.length, onSeeAll: null),
          ...results.posts.take(3).map((p) => _PostResultTile(post: p)),
        ],
        if (results.people.isNotEmpty) ...[
          _SectionHeader('People', results.people.length, onSeeAll: null),
          ...results.people.take(3).map((p) => _PersonResultTile(person: p)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onSeeAll;
  const _SectionHeader(this.label, this.count, {required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: HapaColors.ochre.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: HapaColors.ochre)),
          ),
        ],
      ),
    );
  }
}

// Places list
class _PlacesList extends StatelessWidget {
  final List<_Place> places;
  final String query;
  const _PlacesList({required this.places, required this.query});

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return _NoResults(query: query);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: places.length,
      itemBuilder: (_, i) => _PlaceResultTile(place: places[i])
          .animate(delay: Duration(milliseconds: i * 40))
          .fadeIn(duration: 200.ms)
          .slideY(begin: 0.06, end: 0, duration: 200.ms),
    );
  }
}

class _PlaceResultTile extends StatelessWidget {
  final _Place place;
  const _PlaceResultTile({required this.place});

  Color get _catColor {
    const m = {
      'restaurant': Color(0xFFEF4444),
      'cafe': Color(0xFFD97706),
      'bar': Color(0xFF7C3AED),
      'hotel': Color(0xFF2563EB),
    };
    return m[place.category.toLowerCase()] ?? const Color(0xFF059669);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/places/${place.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: place.coverUrl != null
                  ? Image.network(place.coverUrl!, width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _CategoryBox(color: _catColor, cat: place.category))
                  : _CategoryBox(color: _catColor, cat: place.category),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _catColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(place.category, style: TextStyle(fontSize: 10, color: _catColor, fontWeight: FontWeight.w600)),
                        ),
                        if (place.ratingAvg != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(place.ratingAvg!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                        ],
                      ],
                    ),
                    if (place.address != null) ...[
                      const SizedBox(height: 4),
                      Text(place.address!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBox extends StatelessWidget {
  final Color color;
  final String cat;
  const _CategoryBox({required this.color, required this.cat});

  @override
  Widget build(BuildContext context) {
    const icons = {
      'restaurant': '🍽️', 'cafe': '☕', 'bar': '🍺',
      'hotel': '🏨', 'market': '🛍️', 'museum': '🏛️',
    };
    return Container(
      width: 72,
      height: 72,
      color: color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(icons[cat.toLowerCase()] ?? '📍', style: const TextStyle(fontSize: 28)),
    );
  }
}

// Posts list
class _PostsList extends StatelessWidget {
  final List<Post> posts;
  final String query;
  const _PostsList({required this.posts, required this.query});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return _NoResults(query: query);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: posts.length,
      itemBuilder: (_, i) => _PostResultTile(post: posts[i])
          .animate(delay: Duration(milliseconds: i * 40))
          .fadeIn(duration: 200.ms)
          .slideY(begin: 0.06, end: 0, duration: 200.ms),
    );
  }
}

class _PostResultTile extends StatelessWidget {
  final Post post;
  const _PostResultTile({required this.post});

  Color get _typeColor {
    const m = {
      'review': Color(0xFFD97706),
      'tip': Color(0xFF059669),
      'flash': Color(0xFFEF4444),
      'guide': Color(0xFF7C3AED),
    };
    return m[post.postType] ?? const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/posts/${post.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(post.postType, style: TextStyle(fontSize: 10, color: _typeColor, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.title != null)
                    Text(post.title!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (post.body != null) ...[
                    const SizedBox(height: 3),
                    Text(post.body!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(post.displayName,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      if (post.city != null) ...[
                        Text(' · ', style: TextStyle(color: Colors.grey.shade400)),
                        const Icon(Icons.location_on_outlined, size: 10, color: Colors.grey),
                        Text(post.city!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (post.mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(post.mediaUrl!, width: 54, height: 54, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
          ],
        ),
      ),
    );
  }
}

// People list
class _PeopleList extends StatelessWidget {
  final List<_Person> people;
  final String query;
  const _PeopleList({required this.people, required this.query});

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return _NoResults(query: query);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: people.length,
      itemBuilder: (_, i) => _PersonResultTile(person: people[i])
          .animate(delay: Duration(milliseconds: i * 40))
          .fadeIn(duration: 200.ms)
          .slideY(begin: 0.06, end: 0, duration: 200.ms),
    );
  }
}

class _PersonResultTile extends StatelessWidget {
  final _Person person;
  const _PersonResultTile({required this.person});

  Color get _typeColor {
    const m = {
      'creator': Color(0xFF7C3AED),
      'local': Color(0xFFD97706),
      'traveler': Color(0xFF059669),
    };
    return m[person.userType] ?? const Color(0xFF2563EB);
  }

  Color get _avatarColor {
    final palette = [
      const Color(0xFFD97706), const Color(0xFF7C3AED),
      const Color(0xFF059669), const Color(0xFFDC2626), const Color(0xFF2563EB),
    ];
    final hash = person.id.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/creators/${person.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _avatarColor.withValues(alpha: 0.15),
                  backgroundImage: person.avatarUrl != null ? NetworkImage(person.avatarUrl!) : null,
                  child: person.avatarUrl == null
                      ? Text(person.displayName[0].toUpperCase(),
                          style: TextStyle(color: _avatarColor, fontWeight: FontWeight.w800, fontSize: 18))
                      : null,
                ),
                if (person.isVerified)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(person.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(person.userType, style: TextStyle(fontSize: 9, color: _typeColor, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  if (person.bio != null) ...[
                    const SizedBox(height: 2),
                    Text(person.bio!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if (person.interestTags.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      children: person.interestTags.take(3).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('#$t', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              person.isFollowing ? Icons.check_circle_rounded : Icons.person_add_outlined,
              size: 20,
              color: person.isFollowing ? const Color(0xFF059669) : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Utility states ────────────────────────────────────────────────────────────

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No results for "$query"',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Try a different search term or explore trending topics.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Search unavailable', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: HapaColors.ochre),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
