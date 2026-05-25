import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/theme/app_theme.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class CulturalNote {
  final String id;
  final String title;
  final String body;
  final String category;
  final int upvoteCount;
  final bool isAiGenerated;
  final String author;

  const CulturalNote({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.upvoteCount,
    required this.isAiGenerated,
    required this.author,
  });

  factory CulturalNote.fromJson(Map<String, dynamic> j) => CulturalNote(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        category: j['category'] as String? ?? 'general',
        upvoteCount: j['upvote_count'] as int? ?? 0,
        isAiGenerated: j['is_ai_generated'] as bool? ?? false,
        author: j['author'] as String? ?? 'Hapa AI',
      );
}

class _GuideResult {
  final String city;
  final List<CulturalNote> notes;
  final bool aiPowered;
  const _GuideResult(this.city, this.notes, this.aiPowered);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _guideProvider = FutureProvider.family<_GuideResult, String>((ref, city) async {
  final client = ref.watch(apiClientProvider);
  return client.get(
    '/v1/guide/$city',
    fromJson: (d) {
      final notes = (d['notes'] as List? ?? [])
          .map((n) => CulturalNote.fromJson(n as Map<String, dynamic>))
          .toList();
      return _GuideResult(
        d['city'] as String? ?? city,
        notes,
        d['ai_powered'] as bool? ?? false,
      );
    },
  );
});

// ── Constants ─────────────────────────────────────────────────────────────────

const _categories = ['all', 'food', 'transport', 'culture', 'safety', 'etiquette', 'nightlife', 'nature'];

const _categoryMeta = {
  'all':       (icon: Icons.apps_rounded,         color: Color(0xFF6B7280), label: 'All'),
  'food':      (icon: Icons.restaurant,           color: HapaColors.ochre,  label: 'Food'),
  'transport': (icon: Icons.directions_bus,        color: Color(0xFF10B981), label: 'Transport'),
  'culture':   (icon: Icons.auto_stories,          color: Color(0xFFF59E0B), label: 'Culture'),
  'safety':    (icon: Icons.shield_outlined,       color: Color(0xFFEF4444), label: 'Safety'),
  'etiquette': (icon: Icons.handshake_outlined,    color: Color(0xFF6366F1), label: 'Etiquette'),
  'nightlife': (icon: Icons.nightlife,             color: Color(0xFF8B5CF6), label: 'Nightlife'),
  'nature':    (icon: Icons.nature_people_rounded, color: Color(0xFF3D6B38), label: 'Nature'),
};

typedef _CatMeta = ({IconData icon, Color color, String label});
_CatMeta _meta(String cat) => (_categoryMeta[cat] ?? _categoryMeta['all'])!;

// ── Guide Screen ──────────────────────────────────────────────────────────────

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen>
    with SingleTickerProviderStateMixin {
  String _city = 'Kampala';
  String _activeCategory = 'all';
  final _searchCtrl = TextEditingController(text: 'Kampala');
  final _searchFocus = FocusNode();
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _categories.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() => _activeCategory = _categories[_tabCtrl.index]);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCity());
  }

  void _initCity() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final city = user.currentCity ?? user.homeCity ?? 'Kampala';
      if (city.isNotEmpty && city != _city) {
        setState(() {
          _city = city;
          _searchCtrl.text = city;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _search() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    _searchFocus.unfocus();
    setState(() {
      _city = q;
      _activeCategory = 'all';
      _tabCtrl.animateTo(0);
    });
  }

  void _openDetail(CulturalNote note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuideDetailSheet(
        note: note,
        city: _city,
        onAskAI: (question) {
          Navigator.pop(context);
          _openAI(initialQuestion: question);
        },
      ),
    );
  }

  void _openAI({String? initialQuestion}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HapaAIPanel(
        city: _city,
        apiClient: ref.read(apiClientProvider),
        initialQuestion: initialQuestion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guideAsync = ref.watch(_guideProvider(_city));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      floatingActionButton: _AIFab(onTap: () => _openAI()),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: HapaColors.deep,
            leading: const SizedBox.shrink(),
            leadingWidth: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(city: _city, guideAsync: guideAsync),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(116),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1E10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              decoration: InputDecoration(
                                hintText: 'Search a city…',
                                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                border: InputBorder.none,
                                prefixIcon: const Icon(Icons.search, color: HapaColors.ochre, size: 18),
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _search,
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: HapaColors.ochre,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'GO',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CategoryTabs(controller: _tabCtrl, activeCategory: _activeCategory),
                ],
              ),
            ),
          ),

          guideAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => const _SkeletonCard(),
                childCount: 6,
              ),
            ),
            error: (_, __) => SliverFillRemaining(
              child: _ErrorState(
                city: _city,
                onRetry: () => ref.invalidate(_guideProvider(_city)),
              ),
            ),
            data: (result) {
              final visible = _activeCategory == 'all'
                  ? result.notes
                  : result.notes.where((n) => n.category == _activeCategory).toList();

              if (visible.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    category: _activeCategory,
                    city: result.city,
                    onClearFilter: () => setState(() {
                      _activeCategory = 'all';
                      _tabCtrl.animateTo(0);
                    }),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _GuideCard(
                      note: visible[i],
                      onTap: () => _openDetail(visible[i]),
                    ),
                    childCount: visible.length,
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

// ── Hero Header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String city;
  final AsyncValue<_GuideResult> guideAsync;
  const _HeroHeader({required this.city, required this.guideAsync});

  @override
  Widget build(BuildContext context) {
    final count = guideAsync.valueOrNull?.notes.length ?? 0;
    final aiPowered = guideAsync.valueOrNull?.aiPowered ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1208), Color(0xFF2D1A06), Color(0xFF3A200A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -30,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HapaColors.ochre.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 40, left: -40,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HapaColors.ochre.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'HAPA GUIDE',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono', fontSize: 10,
                          fontWeight: FontWeight.w600, color: HapaColors.ochre,
                          letterSpacing: 2.5,
                        ),
                      ),
                      if (aiPowered) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: HapaColors.ochre.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: HapaColors.ochre.withValues(alpha: 0.4)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('✨', style: TextStyle(fontSize: 9)),
                            SizedBox(width: 3),
                            Text('AI Powered', style: TextStyle(fontSize: 9, color: HapaColors.ochreMuted, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    city,
                    style: const TextStyle(
                      fontFamily: 'Fraunces', fontSize: 28,
                      fontWeight: FontWeight.w800, color: Colors.white, height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count > 0 ? '$count insider tips from locals' : 'Generating local tips…',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Tabs ─────────────────────────────────────────────────────────────

class _CategoryTabs extends StatelessWidget {
  final TabController controller;
  final String activeCategory;
  const _CategoryTabs({required this.controller, required this.activeCategory});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: HapaColors.deep,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorColor: HapaColors.ochre,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        tabs: _categories.map((cat) {
          final m = _meta(cat);
          final isActive = cat == activeCategory;
          return Tab(
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(m.icon, size: 14, color: isActive ? m.color : Colors.grey.shade600),
                const SizedBox(width: 5),
                Text(
                  m.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? Colors.white : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Guide Card ────────────────────────────────────────────────────────────────

class _GuideCard extends StatelessWidget {
  final CulturalNote note;
  final VoidCallback onTap;
  const _GuideCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = _meta(note.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: m.color,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: m.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(m.icon, size: 18, color: m.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: m.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    m.label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w700,
                                      color: m.color, letterSpacing: 0.8, fontFamily: 'JetBrainsMono',
                                    ),
                                  ),
                                ),
                                if (note.isAiGenerated) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                                    ),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text('✨', style: TextStyle(fontSize: 8)),
                                      SizedBox(width: 2),
                                      Text('AI', style: TextStyle(fontSize: 8, color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                                    ]),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              note.title,
                              style: const TextStyle(
                                fontFamily: 'Fraunces', fontSize: 15,
                                fontWeight: FontWeight.w700, color: HapaColors.deep, height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1C5B4)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    note.body,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(note.author, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const Spacer(),
                      Icon(Icons.touch_app_outlined, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text('Tap to read more', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    ],
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

// ── Guide Detail Sheet ────────────────────────────────────────────────────────

class _GuideDetailSheet extends StatelessWidget {
  final CulturalNote note;
  final String city;
  final void Function(String question) onAskAI;
  const _GuideDetailSheet({required this.note, required this.city, required this.onAskAI});

  @override
  Widget build(BuildContext context) {
    final m = _meta(note.category);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            // Colored header bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [m.color.withValues(alpha: 0.15), m.color.withValues(alpha: 0.05)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: m.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(m.icon, color: m.color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: m.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m.label.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w800,
                                  color: Colors.white, letterSpacing: 1.0, fontFamily: 'JetBrainsMono',
                                ),
                              ),
                            ),
                            if (note.isAiGenerated) ...[
                              const SizedBox(width: 6),
                              const Text('✨ AI Generated', style: TextStyle(fontSize: 10, color: Color(0xFF6366F1))),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          note.title,
                          style: const TextStyle(
                            fontFamily: 'Fraunces', fontSize: 17,
                            fontWeight: FontWeight.w800, color: HapaColors.deep, height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                children: [
                  Text(
                    note.body,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF374151), height: 1.7),
                  ),
                  const SizedBox(height: 20),
                  // Author row
                  Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8DCC8)),
                        child: const Icon(Icons.person, size: 14, color: HapaColors.ochre),
                      ),
                      const SizedBox(width: 8),
                      Text(note.author, style: const TextStyle(fontSize: 12, color: HapaColors.muted, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (note.upvoteCount > 0) ...[
                        const Icon(Icons.thumb_up, size: 12, color: HapaColors.ochre),
                        const SizedBox(width: 4),
                        Text('${note.upvoteCount}', style: const TextStyle(fontSize: 12, color: HapaColors.muted)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.ios_share_rounded,
                          label: 'Share',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Save',
                          onTap: () => HapticFeedback.lightImpact(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Ask Hapa AI button
                  GestureDetector(
                    onTap: () => onAskAI('Tell me more about "${note.title}" in $city'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1208), Color(0xFF2D1A06)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: HapaColors.ochre.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Text('✨', style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ask Hapa AI about this',
                                  style: TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Get deeper insights, tips and recommendations',
                                  style: TextStyle(color: Color(0xFFAA8855), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: HapaColors.ochre, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5DDD0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: HapaColors.muted),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: HapaColors.muted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── AI FAB ────────────────────────────────────────────────────────────────────

class _AIFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AIFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D1A06), Color(0xFF1A1208)],
          ),
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: HapaColors.deep.withValues(alpha: 0.5),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✨', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Hapa AI',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700,
                fontSize: 14, fontFamily: 'Fraunces',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hapa AI Panel ─────────────────────────────────────────────────────────────

class _AIChatMsg {
  final String role;
  final String content;
  final bool isError;
  _AIChatMsg({required this.role, required this.content, this.isError = false});
}

class _HapaAIPanel extends StatefulWidget {
  final String city;
  final dynamic apiClient;
  final String? initialQuestion;
  const _HapaAIPanel({required this.city, required this.apiClient, this.initialQuestion});

  @override
  State<_HapaAIPanel> createState() => _HapaAIPanelState();
}

class _HapaAIPanelState extends State<_HapaAIPanel> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focus = FocusNode();
  final _messages = <_AIChatMsg>[];
  bool _isTyping = false;

  static const _suggestions = [
    'Best street food spots?',
    'Is it safe to walk at night?',
    'How do I get around cheaply?',
    'Hidden gems tourists miss?',
    'Best time to visit?',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(widget.initialQuestion!));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    _focus.unfocus();

    setState(() {
      _messages.add(_AIChatMsg(role: 'user', content: text.trim()));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final reply = await widget.apiClient.post(
        '/v1/ai/chat',
        body: {'city': widget.city, 'messages': history},
        fromJson: (d) => d['reply'] as String,
      );
      if (mounted) {
        setState(() => _messages.add(_AIChatMsg(role: 'assistant', content: reply)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add(_AIChatMsg(
          role: 'assistant',
          content: 'Sorry, I couldn\'t connect right now. Try again in a moment.',
          isError: true,
        )));
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.80 + bottom,
      decoration: const BoxDecoration(
        color: Color(0xFF12100E),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: HapaColors.ochre.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('✨', style: TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hapa AI',
                      style: TextStyle(
                        color: Colors.white, fontFamily: 'Fraunces',
                        fontSize: 16, fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Local insider for ${widget.city}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2418), height: 1),
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _SuggestionsView(
                    city: widget.city,
                    suggestions: _suggestions,
                    onTap: _send,
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_isTyping && i == _messages.length) {
                        return _TypingIndicator();
                      }
                      return _MessageBubble(msg: _messages[i]);
                    },
                  ),
          ),
          // Input
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF2A2418))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1812),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF3A2E20)),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: 'Ask anything about ${widget.city}…',
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_ctrl.text),
                  child: Container(
                    width: 42, height: 42,
                    decoration: const BoxDecoration(
                      color: HapaColors.ochre,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsView extends StatelessWidget {
  final String city;
  final List<String> suggestions;
  final void Function(String) onTap;
  const _SuggestionsView({required this.city, required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your local insider for',
            style: TextStyle(color: Color(0xFF6B6054), fontSize: 12),
          ),
          Text(
            city,
            style: const TextStyle(
              color: Colors.white, fontFamily: 'Fraunces',
              fontSize: 22, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask me anything — food, transport, safety, culture, hidden gems…',
            style: TextStyle(color: Color(0xFF6B6054), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'SUGGESTED QUESTIONS',
            style: TextStyle(
              color: Color(0xFF4A3828), fontSize: 10,
              letterSpacing: 1.5, fontFamily: 'JetBrainsMono',
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map((q) => GestureDetector(
            onTap: () => onTap(q),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1812),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A2418)),
              ),
              child: Row(
                children: [
                  const Text('💬', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(q, style: const TextStyle(color: Color(0xFFD4C4A0), fontSize: 13)),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF4A3828)),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _AIChatMsg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: HapaColors.ochre.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('✨', style: TextStyle(fontSize: 13))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? HapaColors.ochre
                    : msg.isError
                        ? const Color(0xFF2A1515)
                        : const Color(0xFF1E1812),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: !isUser ? Border.all(color: const Color(0xFF2A2418)) : null,
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  color: isUser ? Colors.white : msg.isError ? const Color(0xFFFF6B6B) : const Color(0xFFD4C4A0),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: HapaColors.ochre.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('✨', style: TextStyle(fontSize: 13))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1812),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2418)),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => Container(
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: HapaColors.ochre.withValues(alpha: _anim.value - i * 0.15),
                    shape: BoxShape.circle,
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton, Error, Empty ────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
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
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _bone(36, 36, circle: true),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _bone(60, 10), const SizedBox(height: 6), _bone(140, 14),
            ]),
          ]),
          const SizedBox(height: 12),
          _bone(double.infinity, 12), const SizedBox(height: 6),
          _bone(double.infinity, 12), const SizedBox(height: 6), _bone(180, 12),
        ]),
      ),
    );
  }

  Widget _bone(double w, double h, {bool circle = false}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: Colors.grey.shade200.withValues(alpha: _anim.value),
      borderRadius: circle ? null : BorderRadius.circular(4),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String city;
  final VoidCallback onRetry;
  const _ErrorState({required this.city, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.08), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Couldn\'t load guide', style: TextStyle(fontFamily: 'Fraunces', fontSize: 18, fontWeight: FontWeight.w700, color: HapaColors.deep)),
        const SizedBox(height: 8),
        Text('Check your connection and try again.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Try Again')),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String category;
  final String city;
  final VoidCallback onClearFilter;
  const _EmptyState({required this.category, required this.city, required this.onClearFilter});

  @override
  Widget build(BuildContext context) {
    final m = _meta(category);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: m.color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(m.icon, color: m.color, size: 32),
          ),
          const SizedBox(height: 16),
          Text('No ${m.label} tips for $city', style: const TextStyle(fontFamily: 'Fraunces', fontSize: 16, fontWeight: FontWeight.w700, color: HapaColors.deep), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Try a different category or explore all tips.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
          if (category != 'all') ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onClearFilter, child: const Text('View all tips')),
          ],
        ]),
      ),
    );
  }
}
