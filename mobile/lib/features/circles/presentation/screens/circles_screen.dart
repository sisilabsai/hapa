import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/theme/app_theme.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class Circle {
  final String id;
  final String name;
  final String description;
  final String city;
  final String category;
  final String coverUrl;
  final int memberCount;
  final bool isPublic;
  final bool isMember;

  const Circle({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    required this.category,
    required this.coverUrl,
    required this.memberCount,
    required this.isPublic,
    required this.isMember,
  });

  factory Circle.fromJson(Map<String, dynamic> j) => Circle(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        city: j['city'] as String,
        category: j['category'] as String? ?? '',
        coverUrl: j['cover_url'] as String? ?? '',
        memberCount: j['member_count'] as int? ?? 0,
        isPublic: j['is_public'] as bool? ?? true,
        isMember: j['is_member'] as bool? ?? false,
      );

  Circle withMembership(bool member) => Circle(
        id: id, name: name, description: description, city: city,
        category: category, coverUrl: coverUrl,
        memberCount: member ? memberCount + 1 : memberCount - 1,
        isPublic: isPublic, isMember: member,
      );
}

// ── Category metadata ─────────────────────────────────────────────────────────

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

const _categoryLabel = {
  'food_dining': 'Food & Dining',
  'nightlife': 'Nightlife',
  'arts_culture': 'Arts & Culture',
  'business_networking': 'Business & Networking',
  'sports_fitness': 'Sports & Fitness',
  'faith_community': 'Faith & Community',
  'family_parenting': 'Family & Parenting',
  'fashion_style': 'Fashion & Style',
  'music_events': 'Music & Events',
  'street_life': 'Street Life',
  'travel': 'Travel',
  'tech': 'Tech',
  'nature_outdoors': 'Nature & Outdoors',
};

// ── Provider ──────────────────────────────────────────────────────────────────

final _circlesProvider = FutureProvider.family<List<Circle>, String>((ref, city) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get<Map<String, dynamic>>(
    '/v1/circles',
    queryParams: {'city': city, 'limit': '30'},
    fromJson: (d) => d as Map<String, dynamic>,
  );
  final list = data['circles'] as List? ?? [];
  return list.map((e) => Circle.fromJson(e as Map<String, dynamic>)).toList();
});

final _myCirclesProvider = FutureProvider<List<Circle>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get<Map<String, dynamic>>(
    '/v1/circles/mine',
    fromJson: (d) => d as Map<String, dynamic>,
  );
  final list = data['circles'] as List? ?? [];
  return list.map((e) => Circle.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CirclesScreen extends ConsumerStatefulWidget {
  const CirclesScreen({super.key});

  @override
  ConsumerState<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends ConsumerState<CirclesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String get _city => ref.read(currentUserProvider)?.currentCity ?? 'Kampala';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: const Text(
          'Circles',
          style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: HapaColors.deep,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: HapaColors.ochre,
          unselectedLabelColor: HapaColors.muted,
          indicatorColor: HapaColors.ochre,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
          tabs: const [Tab(text: 'DISCOVER'), Tab(text: 'MY CIRCLES')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: HapaColors.ochre,
            onPressed: () => _openCreateSheet(),
            tooltip: 'Create circle',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DiscoverTab(city: _city),
          const _MyCirclesTab(),
        ],
      ),
    );
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCircleSheet(city: _city),
    ).then((_) {
      ref.invalidate(_circlesProvider(_city));
      ref.invalidate(_myCirclesProvider);
    });
  }
}

// ── Discover tab ──────────────────────────────────────────────────────────────

class _DiscoverTab extends ConsumerWidget {
  final String city;
  const _DiscoverTab({required this.city});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_circlesProvider(city));
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: HapaColors.ochre, strokeWidth: 2),
      ),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(_circlesProvider(city)),
          child: const Text('Retry'),
        ),
      ),
      data: (circles) => circles.isEmpty
          ? _EmptyDiscover(city: city)
          : RefreshIndicator(
              color: HapaColors.ochre,
              onRefresh: () async => ref.invalidate(_circlesProvider(city)),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: circles.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CircleCard(
                    circle: circles[i],
                    onJoined: () => ref.invalidate(_circlesProvider(city)),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── My Circles tab ────────────────────────────────────────────────────────────

class _MyCirclesTab extends ConsumerWidget {
  const _MyCirclesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myCirclesProvider);
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: HapaColors.ochre, strokeWidth: 2),
      ),
      error: (_, __) => const Center(child: Text('Could not load')),
      data: (circles) => circles.isEmpty
          ? const _EmptyMyCircles()
          : RefreshIndicator(
              color: HapaColors.ochre,
              onRefresh: () async => ref.invalidate(_myCirclesProvider),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: circles.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CircleCard(
                    circle: circles[i],
                    onJoined: () => ref.invalidate(_myCirclesProvider),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Circle card ───────────────────────────────────────────────────────────────

class _CircleCard extends ConsumerStatefulWidget {
  final Circle circle;
  final VoidCallback onJoined;

  const _CircleCard({required this.circle, required this.onJoined});

  @override
  ConsumerState<_CircleCard> createState() => _CircleCardState();
}

class _CircleCardState extends ConsumerState<_CircleCard> {
  late bool _isMember;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _isMember = widget.circle.isMember;
  }

  Future<void> _toggle() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      final client = ref.read(apiClientProvider);
      if (_isMember) {
        await client.delete('/v1/circles/${widget.circle.id}/join');
      } else {
        await client.post<void>(
          '/v1/circles/${widget.circle.id}/join',
          body: {},
          fromJson: (_) {},
        );
      }
      setState(() => _isMember = !_isMember);
      widget.onJoined();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.circle;
    final emoji = _categoryEmoji[c.category] ?? '⭕';
    final label = _categoryLabel[c.category] ?? c.category;

    return GestureDetector(
      onTap: () => context.push('/circles/${c.id}'),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: HapaColors.ochre, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji avatar
              Container(
                width: 52,
                height: 52,
                color: HapaColors.ochre.withValues(alpha: 0.10),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        color: HapaColors.deep,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (c.description.isNotEmpty)
                      Text(
                        c.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: HapaColors.muted, fontSize: 12, height: 1.4),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: HapaColors.ochre.withValues(alpha: 0.75),
                            fontSize: 10,
                            fontFamily: 'JetBrainsMono',
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_memberLabel(c.memberCount)} members',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Join button
              GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _isMember
                        ? Colors.transparent
                        : HapaColors.ochre,
                    border: Border.all(
                      color: _isMember ? Colors.grey.shade300 : HapaColors.ochre,
                    ),
                  ),
                  child: _toggling
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: _isMember ? HapaColors.ochre : Colors.white,
                          ),
                        )
                      : Text(
                          _isMember ? 'JOINED' : 'JOIN',
                          style: TextStyle(
                            color: _isMember ? Colors.grey.shade500 : Colors.white,
                            fontSize: 10,
                            fontFamily: 'JetBrainsMono',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _memberLabel(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyDiscover extends StatelessWidget {
  final String city;
  const _EmptyDiscover({required this.city});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌐', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Text(
              'No circles in $city yet',
              style: const TextStyle(
                color: HapaColors.deep,
                fontSize: 18,
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to build community here.',
              style: TextStyle(color: HapaColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMyCircles extends StatelessWidget {
  const _EmptyMyCircles();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⭕', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            const Text(
              "You haven't joined any circles",
              style: TextStyle(
                color: HapaColors.deep,
                fontSize: 16,
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Discover circles in your city\nand join the conversation.',
              style: TextStyle(color: HapaColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create circle sheet ───────────────────────────────────────────────────────

const _kCategories = [
  ('food_dining', '🍽️', 'Food & Dining'),
  ('nightlife', '🌙', 'Nightlife'),
  ('arts_culture', '🎨', 'Arts & Culture'),
  ('business_networking', '💼', 'Business & Networking'),
  ('sports_fitness', '⚽', 'Sports & Fitness'),
  ('faith_community', '🕊️', 'Faith & Community'),
  ('family_parenting', '👨‍👩‍👧', 'Family & Parenting'),
  ('fashion_style', '👗', 'Fashion & Style'),
  ('music_events', '🎶', 'Music & Events'),
  ('street_life', '🏙️', 'Street Life'),
  ('travel', '✈️', 'Travel'),
  ('tech', '💻', 'Tech'),
  ('nature_outdoors', '🌿', 'Nature & Outdoors'),
];

class _CreateCircleSheet extends ConsumerStatefulWidget {
  final String city;
  const _CreateCircleSheet({required this.city});

  @override
  ConsumerState<_CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends ConsumerState<_CreateCircleSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _category;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameCtrl.text.trim().length >= 3 && _category != null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final client = ref.read(apiClientProvider);
      await client.post<void>(
        '/v1/circles',
        body: {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'city': widget.city,
          'category': _category,
        },
        fromJson: (_) {},
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create circle. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 3,
              color: Colors.grey.shade200,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New Circle',
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: HapaColors.deep,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _canSubmit && !_submitting ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: HapaColors.ochre,
                            ),
                          )
                        : const Text(
                            'CREATE',
                            style: TextStyle(
                              color: HapaColors.ochre,
                              fontFamily: 'JetBrainsMono',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                      ),
                    _buildLabel('CIRCLE NAME'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'e.g. Kampala Food Lovers',
                        fillColor: const Color(0xFFFAF8F5),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: HapaColors.ochre),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('DESCRIPTION (OPTIONAL)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      maxLength: 280,
                      decoration: InputDecoration(
                        hintText: 'What is this circle about?',
                        fillColor: const Color(0xFFFAF8F5),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: HapaColors.ochre),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('CATEGORY'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kCategories.map((cat) {
                        final selected = _category == cat.$1;
                        return GestureDetector(
                          onTap: () => setState(() => _category = cat.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? HapaColors.ochre.withValues(alpha: 0.1) : Colors.transparent,
                              border: Border.all(
                                color: selected ? HapaColors.ochre : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(cat.$2, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  cat.$3,
                                  style: TextStyle(
                                    color: selected ? HapaColors.ochre : HapaColors.deep,
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xFFFAF8F5),
                      child: Row(
                        children: [
                          const Icon(Icons.location_city_outlined, size: 16, color: HapaColors.muted),
                          const SizedBox(width: 8),
                          Text(
                            'City: ${widget.city}',
                            style: const TextStyle(color: HapaColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 10,
          fontFamily: 'JetBrainsMono',
          letterSpacing: 1.5,
        ),
      );
}
