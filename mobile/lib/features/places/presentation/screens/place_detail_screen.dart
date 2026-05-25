import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/models/business.dart';
import '../../../../shared/models/post.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _placeProvider = FutureProvider.family<Business, String>((ref, id) {
  return ref.watch(apiClientProvider).get(
    '/v1/places/$id',
    fromJson: (d) => Business.fromJson(d as Map<String, dynamic>),
  );
});

final _placePostsProvider = FutureProvider.family<List<Post>, String>((ref, bizId) async {
  try {
    return ref.watch(apiClientProvider).get<List<Post>>(
      '/v1/feed',
      queryParams: {'business_id': bizId, 'limit': '8'},
      fromJson: (d) => ((d['posts'] as List?) ?? [])
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  } catch (_) {
    return [];
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class PlaceDetailScreen extends ConsumerWidget {
  final String id;
  const PlaceDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeAsync = ref.watch(_placeProvider(id));

    return placeAsync.when(
      loading: () => Scaffold(backgroundColor: const Color(0xFFF8F5F0), body: _PlaceSkeleton()),
      error: (_, __) => Scaffold(
        backgroundColor: const Color(0xFFF8F5F0),
        body: _PlaceError(onRetry: () => ref.invalidate(_placeProvider(id))),
      ),
      data: (biz) => _PlaceScaffold(business: biz),
    );
  }
}

class _PlaceScaffold extends StatelessWidget {
  final Business business;
  const _PlaceScaffold({required this.business});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _BookingSheet(business: business),
        ),
        backgroundColor: HapaColors.ochre,
        icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
        label: const Text('Book a Visit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _PlaceDetail(business: business),
    );
  }
}

// ── Main detail body ──────────────────────────────────────────────────────────

class _PlaceDetail extends ConsumerStatefulWidget {
  final Business business;
  const _PlaceDetail({required this.business});

  @override
  ConsumerState<_PlaceDetail> createState() => _PlaceDetailState();
}

class _PlaceDetailState extends ConsumerState<_PlaceDetail> {
  final _photoCtrl = PageController();
  int _photoIndex = 0;

  // Real gallery: cover + gallery_urls, with at least 1 slot for placeholder
  List<String?> get _photos {
    final real = widget.business.allPhotos;
    if (real.isEmpty) return [null]; // single placeholder
    return real.cast<String?>();
  }

  @override
  void dispose() {
    _photoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final biz = widget.business;
    final postsAsync = ref.watch(_placePostsProvider(biz.id));

    return CustomScrollView(
      slivers: [
        // ── Photo gallery appbar ─────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: HapaColors.deep,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          actions: [
            GestureDetector(
              onTap: _sharePlace,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Photo gallery PageView
                PageView.builder(
                  controller: _photoCtrl,
                  itemCount: _photos.length,
                  onPageChanged: (i) => setState(() => _photoIndex = i),
                  itemBuilder: (_, i) {
                    final url = _photos[i];
                    if (url != null) {
                      return CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _GalleryPlaceholder(biz: biz, index: i),
                        errorWidget: (_, __, ___) => _GalleryPlaceholder(biz: biz, index: i),
                      );
                    }
                    return _GalleryPlaceholder(biz: biz, index: i);
                  },
                ),

                // Bottom gradient
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                      ),
                    ),
                  ),
                ),

                // Photo indicator dots
                if (_photos.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_photos.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _photoIndex ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _photoIndex ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                    ),
                  ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ────────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                biz.name,
                                style: const TextStyle(
                                  fontFamily: 'Fraunces',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _CategoryBadge(biz.category),
                                  const SizedBox(width: 8),
                                  Text(
                                    biz.priceLabel,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                  ),
                                  if (biz.isVerified) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF3B82F6)),
                                    const SizedBox(width: 2),
                                    const Text('Verified', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Rating block
                        if (biz.avgRating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: HapaColors.ochre.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: HapaColors.ochre.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  biz.avgRating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: HapaColors.ochre,
                                    fontFamily: 'Fraunces',
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (i) => Icon(
                                    i < biz.avgRating!.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 10,
                                    color: HapaColors.ochre,
                                  )),
                                ),
                                Text(
                                  '${biz.reviewCount}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    if (biz.description != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        biz.description!,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.55),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Contact buttons ────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Get in touch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (biz.phone != null)
                          Expanded(child: _ContactBtn(
                            icon: Icons.phone_rounded,
                            label: 'Call',
                            color: const Color(0xFF059669),
                            onTap: () => launchUrl(Uri.parse('tel:${biz.phone}')),
                          )),
                        if (biz.phone != null && biz.whatsapp != null) const SizedBox(width: 8),
                        if (biz.whatsapp != null)
                          Expanded(child: _ContactBtn(
                            icon: Icons.chat_bubble_rounded,
                            label: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            onTap: () => launchUrl(Uri.parse('https://wa.me/${biz.whatsapp}')),
                          )),
                        if (biz.website != null) ...[
                          const SizedBox(width: 8),
                          Expanded(child: _ContactBtn(
                            icon: Icons.language_rounded,
                            label: 'Website',
                            color: const Color(0xFF2563EB),
                            onTap: () => launchUrl(Uri.parse(biz.website!)),
                          )),
                        ],
                        const SizedBox(width: 8),
                        Expanded(child: _ContactBtn(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          color: Colors.grey.shade600,
                          onTap: _sharePlace,
                        )),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Info rows ──────────────────────────────────────────────────
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    if (biz.address != null)
                      _InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: biz.address!),
                    if (biz.openingHours != null)
                      _InfoRow(icon: Icons.access_time_rounded, label: 'Hours', value: biz.openingHours!),
                    if (biz.city.isNotEmpty)
                      _InfoRow(icon: Icons.location_city_rounded, label: 'City', value: biz.city),
                    if (biz.distanceMeters != null)
                      _InfoRow(
                        icon: Icons.directions_walk_rounded,
                        label: 'Distance',
                        value: biz.distanceMeters! < 1000
                            ? '${biz.distanceMeters!.round()}m away'
                            : '${(biz.distanceMeters! / 1000).toStringAsFixed(1)}km away',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Nearby Posts ───────────────────────────────────────────────
              postsAsync.when(
                loading: () => _NearbyPostsSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (posts) => posts.isEmpty
                    ? const SizedBox.shrink()
                    : _NearbyPosts(posts: posts),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  void _sharePlace() {
    // Share via platform
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share link copied!'), behavior: SnackBarBehavior.floating),
    );
  }
}

// ── Gallery Placeholder ───────────────────────────────────────────────────────

class _GalleryPlaceholder extends StatelessWidget {
  final Business biz;
  final int index;
  const _GalleryPlaceholder({required this.biz, required this.index});

  Color get _color {
    const colors = [
      Color(0xFF1E293B), Color(0xFF1A2032), Color(0xFF1E1A32),
    ];
    return colors[index % colors.length];
  }

  String get _emoji {
    const m = {
      'restaurant': '🍽️', 'cafe': '☕', 'bar': '🍺',
      'hotel': '🏨', 'market': '🛍️', 'museum': '🏛️',
      'spa': '💆', 'gym': '💪', 'salon': '💇',
    };
    return m[biz.category.toLowerCase()] ?? '📍';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_color, Colors.black],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(
            biz.name,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Badge ────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge(this.category);

  Color get _color {
    const m = {
      'restaurant': Color(0xFFEF4444),
      'cafe': Color(0xFFD97706),
      'bar': Color(0xFF7C3AED),
      'hotel': Color(0xFF2563EB),
      'market': Color(0xFF059669),
    };
    return m[category.toLowerCase()] ?? HapaColors.ochre;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

// ── Contact Button ────────────────────────────────────────────────────────────

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContactBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: HapaColors.ochre),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}

// ── Nearby Posts ──────────────────────────────────────────────────────────────

class _NearbyPosts extends StatelessWidget {
  final List<Post> posts;
  const _NearbyPosts({required this.posts});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(width: 3, height: 14, color: HapaColors.ochre),
                const SizedBox(width: 8),
                const Text(
                  'Community Posts',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                const Spacer(),
                Text('${posts.length} posts', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: posts.length,
              itemBuilder: (_, i) => _PostThumb(post: posts[i])
                  .animate(delay: Duration(milliseconds: i * 60))
                  .fadeIn(duration: 200.ms)
                  .slideX(begin: 0.08, end: 0, duration: 200.ms),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostThumb extends StatelessWidget {
  final Post post;
  const _PostThumb({required this.post});

  Color get _typeColor {
    const m = {'review': Color(0xFFD97706), 'tip': Color(0xFF059669), 'flash': Color(0xFFEF4444)};
    return m[post.postType] ?? Colors.grey.shade500;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/posts/${post.id}'),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or colored header
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: post.mediaUrl != null
                  ? Image.network(post.mediaUrl!, height: 84, width: 140, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _TypeHeader(color: _typeColor, type: post.postType))
                  : _TypeHeader(color: _typeColor, type: post.postType),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title ?? post.body ?? '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.favorite_rounded, size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 2),
                      Text('${post.likeCount}', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
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

class _TypeHeader extends StatelessWidget {
  final Color color;
  final String type;
  const _TypeHeader({required this.color, required this.type});

  @override
  Widget build(BuildContext context) {
    const icons = {'review': '⭐', 'tip': '💡', 'flash': '⚡', 'moment': '📸'};
    return Container(
      height: 84, width: 140,
      color: color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(icons[type] ?? '📝', style: const TextStyle(fontSize: 32)),
    );
  }
}

// ── Booking Bottom Sheet ──────────────────────────────────────────────────────

class _BookingSheet extends ConsumerStatefulWidget {
  final Business business;
  const _BookingSheet({required this.business});

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _guests = 1;
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post<void>(
        '/v1/bookings',
        body: {
          'business_id': widget.business.id,
          'service_name': 'Table / Visit',
          'quantity': _guests,
          'price_usd': 0.0,
          'notes': _notesCtrl.text.trim(),
          'booking_date': _date.toIso8601String(),
        },
        fromJson: (_) {},
      );
      setState(() {_loading = false; _done = true;});
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking failed. Please try again.'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _done ? _DoneView(business: widget.business) : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              Text(
                'Book at ${widget.business.name}',
                style: const TextStyle(fontFamily: 'Fraunces', fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),

              // Date picker
              Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(primary: HapaColors.ochre),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: HapaColors.ochre),
                      const SizedBox(width: 10),
                      Text(
                        '${_date.day}/${_date.month}/${_date.year}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Guests
              Text('Guests', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CounterBtn(icon: Icons.remove, onTap: () { if (_guests > 1) setState(() => _guests--); }),
                  const SizedBox(width: 16),
                  Text('$_guests', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 16),
                  _CounterBtn(icon: Icons.add, onTap: () { if (_guests < 20) setState(() => _guests++); }),
                ],
              ),

              const SizedBox(height: 14),

              // Notes
              Text('Notes (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Any special requests…',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: HapaColors.ochre),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 20),

              // Book button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _book,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HapaColors.ochre,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  final Business business;
  const _DoneView({required this.business});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'Booking Confirmed!',
            style: const TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Your visit to ${business.name} has been requested. They\'ll be in touch to confirm.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: HapaColors.ochre,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton / Error ──────────────────────────────────────────────────────────

class _PlaceSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Column(
        children: [
          Container(height: 280, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 160, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 80, color: Colors.white),
        ],
      ),
    );
  }
}

class _NearbyPostsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        height: 180,
        child: Row(
          children: List.generate(3, (i) => Container(
            width: 140, margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          )),
        ),
      ),
    );
  }
}

class _PlaceError extends StatelessWidget {
  final VoidCallback onRetry;
  const _PlaceError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Place not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
