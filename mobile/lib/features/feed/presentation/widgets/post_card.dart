import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/widgets/rich_content.dart';
import '../../../../shared/widgets/hapa_video_player.dart';
import '../../domain/feed_repository.dart';
import '../providers/feed_providers.dart';

class PostCard extends ConsumerStatefulWidget {
  final Post post;
  final (double, double)? feedCoords;

  const PostCard({super.key, required this.post, this.feedCoords});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late Post _post;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _startExpiryTimer();
  }

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id) {
      _post = widget.post;
      _expiryTimer?.cancel();
      _startExpiryTimer();
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _startExpiryTimer() {
    if (_post.isFlash && _post.flashExpiresAt != null) {
      _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _sync(Post updated) {
    if (mounted) setState(() => _post = updated);
    if (widget.feedCoords != null) {
      ref.read(feedNotifierProvider(widget.feedCoords!).notifier).updatePost(updated);
    }
  }

  Future<void> _tapLike() async {
    final original = _post;
    final wasLiked = _post.viewer.liked;
    _sync(_post.copyWith(
      likeCount: wasLiked ? _post.likeCount - 1 : _post.likeCount + 1,
      viewer: PostViewer(
        liked: !wasLiked,
        beenHere: _post.viewer.beenHere,
        pulsed: _post.viewer.pulsed,
        saved: _post.viewer.saved,
      ),
    ));
    try {
      final result = await ref.read(feedRepositoryProvider).likePost(original.id);
      _sync(_post.copyWith(
        likeCount: result.count,
        viewer: PostViewer(
          liked: result.liked,
          beenHere: _post.viewer.beenHere,
          pulsed: _post.viewer.pulsed,
          saved: _post.viewer.saved,
        ),
      ));
    } catch (_) {
      _sync(original);
    }
  }

  Future<void> _tapBeenHere() async {
    if (_post.viewer.beenHere) return; // one-way action
    final original = _post;
    _sync(_post.copyWith(
      beenHereCount: _post.beenHereCount + 1,
      viewer: PostViewer(
        liked: _post.viewer.liked,
        beenHere: true,
        pulsed: _post.viewer.pulsed,
        saved: _post.viewer.saved,
      ),
    ));
    try {
      await ref.read(feedRepositoryProvider).beenHere(original.id);
    } catch (_) {
      _sync(original);
    }
  }

  Future<void> _tapPulse() async {
    if (_post.viewer.pulsed) return; // one-way action
    final original = _post;
    _sync(_post.copyWith(
      pulseCount: _post.pulseCount + 1,
      viewer: PostViewer(
        liked: _post.viewer.liked,
        beenHere: _post.viewer.beenHere,
        pulsed: true,
        saved: _post.viewer.saved,
      ),
    ));
    try {
      await ref.read(feedRepositoryProvider).pulse(original.id);
    } catch (_) {
      _sync(original);
    }
  }

  Future<void> _tapSave() async {
    final original = _post;
    final wasSaved = _post.viewer.saved;
    _sync(_post.copyWith(
      viewer: PostViewer(
        liked: _post.viewer.liked,
        beenHere: _post.viewer.beenHere,
        pulsed: _post.viewer.pulsed,
        saved: !wasSaved,
      ),
    ));
    try {
      await ref.read(feedRepositoryProvider).savePost(original.id);
      // Refresh saved posts list so it stays in sync
      ref.read(savedPostsProvider.notifier).refresh();
    } catch (_) {
      _sync(original);
    }
  }

  void _openDetail() {
    context.push('/posts/${_post.id}', extra: _post);
  }

  Duration? get _flashTimeLeft {
    if (!_post.isFlash || _post.flashExpiresAt == null) return null;
    final left = _post.flashExpiresAt!.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _post.isFlash && _flashTimeLeft == null && _post.flashExpiresAt != null;

    return Opacity(
      opacity: isExpired ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: _post.isFlash
              ? Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openDetail,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flash expiry banner
                if (_post.isFlash) _FlashExpiryBanner(timeLeft: _flashTimeLeft),

                // Media
                if (_post.mediaUrl != null) _MediaSection(post: _post),

                // Header: author + meta
                _AuthorRow(
                  post: _post,
                  onTap: () {
                    if (_post.isBusinessPost) {
                      context.push('/places/${_post.businessId}');
                    } else {
                      context.push('/creators/${_post.userId}');
                    }
                  },
                ),

                // Content
                if (_post.body != null && _post.body!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: RichContent(
                      text: _post.body!,
                      baseStyle: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.45),
                      accentColor: _typeColor(_post.postType),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Business profile tap chip
                if (_post.isBusinessPost)
                  GestureDetector(
                    onTap: () => context.push('/places/${_post.businessId}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HapaColors.ochre.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: HapaColors.ochre.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_rounded, size: 10, color: HapaColors.ochre),
                            const SizedBox(width: 4),
                            Text(
                              'View ${_post.businessName ?? 'business'} profile',
                              style: const TextStyle(
                                fontSize: 10,
                                color: HapaColors.ochre,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_ios, size: 9, color: HapaColors.ochre),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Action bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: Row(
                    children: [
                      // Flash: Pulse instead of Like
                      if (_post.isFlash) ...[
                        PostActionChip(
                          icon: _post.viewer.pulsed ? Icons.bolt : Icons.bolt_outlined,
                          label: _post.pulseCount > 0 ? '${_post.pulseCount}' : '',
                          color: const Color(0xFFEF4444),
                          active: _post.viewer.pulsed,
                          onTap: _tapPulse,
                          tooltip: 'Pulse — this is happening now',
                        ),
                      ] else ...[
                        PostActionChip(
                          icon: _post.viewer.liked ? Icons.favorite : Icons.favorite_border,
                          label: _post.likeCount > 0 ? '${_post.likeCount}' : '',
                          color: const Color(0xFFEF4444),
                          active: _post.viewer.liked,
                          onTap: _tapLike,
                        ),
                      ],
                      const SizedBox(width: 2),
                      // Been Here
                      PostActionChip(
                        icon: _post.viewer.beenHere
                            ? Icons.where_to_vote
                            : Icons.where_to_vote_outlined,
                        label: _post.beenHereCount > 0 ? '${_post.beenHereCount}' : '',
                        color: HapaColors.ochre,
                        active: _post.viewer.beenHere,
                        onTap: _tapBeenHere,
                        tooltip: 'Been Here',
                      ),
                      const SizedBox(width: 2),
                      // Comments
                      PostActionChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: _post.commentCount > 0 ? '${_post.commentCount}' : '',
                        color: const Color(0xFF6366F1),
                        active: false,
                        onTap: () => context.push('/posts/${_post.id}', extra: _post),
                      ),
                      const Spacer(),
                      // Save
                      PostActionChip(
                        icon: _post.viewer.saved ? Icons.bookmark : Icons.bookmark_border,
                        label: '',
                        color: HapaColors.deep,
                        active: _post.viewer.saved,
                        onTap: _tapSave,
                        tooltip: _post.viewer.saved ? 'Unsave' : 'Save',
                      ),
                      // Distance
                      if (_post.distanceM > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 4, left: 4),
                          child: Text(
                            _formatDist(_post.distanceM),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                        ),
                      Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade300),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDist(double m) {
    if (m < 1000) return '${m.round()}m';
    return '${(m / 1000).toStringAsFixed(1)}km';
  }
}

// ── Flash expiry banner ───────────────────────────────────────────────────────

class _FlashExpiryBanner extends StatelessWidget {
  final Duration? timeLeft;
  const _FlashExpiryBanner({this.timeLeft});

  Color get _color {
    if (timeLeft == null) return Colors.grey.shade400;
    if (timeLeft!.inMinutes < 30) return const Color(0xFFEF4444);
    return const Color(0xFFEF4444);
  }

  String get _label {
    if (timeLeft == null) return 'FLASH · ENDED';
    final h = timeLeft!.inHours;
    final m = timeLeft!.inMinutes % 60;
    if (h > 0) return 'FLASH · ${h}h ${m}m LEFT';
    return 'FLASH · ${timeLeft!.inMinutes}m LEFT';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: _color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.bolt, size: 11, color: _color),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _color,
              letterSpacing: 0.8,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaSection extends StatelessWidget {
  final Post post;
  const _MediaSection({required this.post});

  bool get _isVideo => isVideoUrl(post.mediaUrl!);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isVideo)
          HapaVideoPlayer(
            networkUrl: post.mediaUrl!,
            autoPlay: false,
            looping: true,
            aspectRatio: 16 / 9,
          )
        else
          Hero(
            tag: 'post-hero-${post.id}',
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: post.mediaUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFFF0EBE0)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFF0EBE0),
                  child: const Icon(Icons.image_outlined, color: Color(0xFFD0C9B8)),
                ),
              ),
            ),
          ),
        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x88000000), Colors.transparent],
              ),
            ),
          ),
        ),
        // Type badge
        Positioned(
          top: 10, left: 10,
          child: PostTypeBadge(type: post.postType),
        ),
        // Video badge
        if (_isVideo)
          Positioned(
            top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  const _AuthorRow({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PostAvatar(name: post.displayName, url: post.displayAvatar, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: HapaColors.deep,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.isBusinessPost) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.storefront_rounded, size: 11, color: HapaColors.ochre),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      if (post.isBusinessPost) ...[
                        const Icon(Icons.storefront_rounded, size: 9, color: HapaColors.ochre),
                        const SizedBox(width: 2),
                        Text('Business', style: TextStyle(fontSize: 10, color: HapaColors.ochre, fontWeight: FontWeight.w600)),
                        Text(' · ', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ] else if (post.neighbourhood != null) ...[
                        const Icon(Icons.location_on, size: 9, color: HapaColors.ochre),
                        const SizedBox(width: 2),
                        Text(
                          post.neighbourhood!,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                        Text(' · ', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ] else if (post.city != null) ...[
                        const Icon(Icons.location_on, size: 9, color: HapaColors.ochre),
                        const SizedBox(width: 2),
                        Text(
                          post.city!,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                        Text(' · ', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ],
                      Text(
                        _timeAgo(post.createdAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (post.mediaUrl == null) PostTypeBadge(type: post.postType),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class PostAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const PostAvatar({required this.name, this.url, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final validUrl = (url != null && url!.isNotEmpty) ? url : null;
    if (validUrl != null) {
      return CachedNetworkImage(
        imageUrl: validUrl,
        imageBuilder: (_, img) => CircleAvatar(radius: radius, backgroundImage: img),
        placeholder: (_, __) => _letterAvatar(),
        errorWidget: (_, __, ___) => _letterAvatar(),
        width: radius * 2,
        height: radius * 2,
      );
    }
    return _letterAvatar();
  }

  Widget _letterAvatar() {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: HapaColors.ochre.withValues(alpha: 0.12),
      child: Text(
        letter,
        style: TextStyle(
          color: HapaColors.ochre,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

class PostTypeBadge extends StatelessWidget {
  final String type;
  const PostTypeBadge({required this.type});

  static const _config = {
    'tip': (label: 'Tip', icon: Icons.lightbulb_outline, color: Color(0xFF10B981)),
    'review': (label: 'Review', icon: Icons.star_outline, color: Color(0xFF6366F1)),
    'flash': (label: 'Flash', icon: Icons.bolt, color: Color(0xFFEF4444)),
    'guide': (label: 'Guide', icon: Icons.map_outlined, color: HapaColors.ochre),
    'diary': (label: 'Diary', icon: Icons.book_outlined, color: Color(0xFF8B5CF6)),
    'cultural_note': (label: 'Culture', icon: Icons.language, color: HapaColors.sage),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _config[type];
    if (cfg == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 9, color: cfg.color),
          const SizedBox(width: 3),
          Text(
            cfg.label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: cfg.color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class PostActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  final String? tooltip;

  const PostActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? color : Colors.grey.shade400,
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? color : Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}

Color _typeColor(String postType) {
  switch (postType) {
    case 'tip': return const Color(0xFF10B981);
    case 'review': return const Color(0xFF6366F1);
    case 'flash': return const Color(0xFFEF4444);
    case 'cultural_note': return HapaColors.sage;
    default: return HapaColors.ochre;
  }
}
