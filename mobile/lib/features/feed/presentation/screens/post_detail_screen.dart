import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/widgets/rich_content.dart';
import '../../../../shared/widgets/hapa_video_player.dart';
import '../../domain/feed_repository.dart';
import '../providers/feed_providers.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final Post? initialPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  Post? _post;
  bool _sendingComment = false;
  PostComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startReply(PostComment comment) {
    setState(() => _replyingTo = comment);
    _commentController.clear();
    FocusScope.of(context).requestFocus(FocusNode());
    Future.delayed(const Duration(milliseconds: 50), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
    _commentController.clear();
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    final parentId = _replyingTo?.id;
    _commentController.clear();
    setState(() => _replyingTo = null);
    FocusScope.of(context).unfocus();
    await ref.read(commentsProvider(widget.postId).notifier).addComment(
          content,
          parentId: parentId,
        );
    if (mounted) setState(() => _sendingComment = false);
  }

  @override
  Widget build(BuildContext context) {
    final freshAsync = ref.watch(postDetailProvider(widget.postId));
    final post = freshAsync.value ?? _post;

    if (post == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F5F0),
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: HapaColors.ochre)),
      );
    }

    // Update local state when fresh data arrives
    if (freshAsync.value != null && freshAsync.value!.id == post.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _post?.id != freshAsync.value?.id) {
          setState(() => _post = freshAsync.value);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _HeroAppBar(post: post),
          SliverToBoxAdapter(child: _AuthorSection(post: post)),
          SliverToBoxAdapter(child: _ContentSection(post: post)),
          if (post.business != null)
            SliverToBoxAdapter(child: _BusinessCard(post: post)),
          if (post.interestTags.isNotEmpty)
            SliverToBoxAdapter(child: _TagsRow(tags: post.interestTags)),
          SliverToBoxAdapter(child: _ActionsBar(post: post, postId: widget.postId)),
          SliverToBoxAdapter(
            child: _CommentsSection(
              postId: widget.postId,
              onReply: _startReply,
            ),
          ),
          if (post.lat != null && post.lng != null)
            SliverToBoxAdapter(
              child: _RelatedSection(
                postId: widget.postId,
                lat: post.lat!,
                lng: post.lng!,
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      bottomNavigationBar: _CommentInputBar(
        controller: _commentController,
        sending: _sendingComment,
        onSend: _sendComment,
        replyingTo: _replyingTo,
        onCancelReply: _cancelReply,
      ),
    );
  }
}

// ── Hero app bar with image ─────────────────────────────────────────────────

class _HeroAppBar extends StatelessWidget {
  final Post post;
  const _HeroAppBar({required this.post});

  @override
  Widget build(BuildContext context) {
    final hasImage = post.mediaUrl != null;
    return SliverAppBar(
      expandedHeight: hasImage ? 280.0 : 0,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: HapaColors.deep,
      elevation: 0,
      leading: _BackButton(),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, size: 20),
          onPressed: () => SharePlus.instance.share(
            ShareParams(text: 'Check out this post on Hapa: ${post.body ?? post.title ?? ''}'),
          ),
        ),
      ],
      flexibleSpace: hasImage
          ? FlexibleSpaceBar(
              background: _buildMediaBackground(post),
            )
          : null,
    );
  }

  Widget _buildMediaBackground(Post post) {
    final url = post.mediaUrl!;
    if (isVideoUrl(url)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          HapaVideoPlayer(
            networkUrl: url,
            autoPlay: true,
            looping: true,
            aspectRatio: 16 / 9,
          ),
          const Positioned(
            bottom: 0, left: 0, right: 0,
            child: _GradientOverlay(),
          ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: 'post-hero-${post.id}',
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFFF0EBE0)),
            errorWidget: (_, __, ___) => Container(color: const Color(0xFFF0EBE0)),
          ),
        ),
        const Positioned(
          bottom: 0, left: 0, right: 0,
          child: _GradientOverlay(),
        ),
      ],
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xBB000000), Colors.transparent],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.black.withOpacity(0.2),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
          onPressed: () => context.pop(),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

// ── Author section ──────────────────────────────────────────────────────────

class _AuthorSection extends StatelessWidget {
  final Post post;
  const _AuthorSection({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          PostAvatar(name: post.displayName, url: post.displayAvatar, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: HapaColors.deep,
                      ),
                    ),
                    if (author?.isVerified == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: HapaColors.ochre),
                    ],
                  ],
                ),
                if (author?.bio != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      author!.bio!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (post.city != null)
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 10, color: HapaColors.ochre),
                          const SizedBox(width: 2),
                          Text(
                            post.neighbourhood ?? post.city!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          Text(' · ', style: TextStyle(fontSize: 11, color: Colors.grey.shade300)),
                        ],
                      ),
                    Text(
                      _timeAgo(post.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (author?.trustScore != null && author!.trustScore > 0)
            _TrustBadge(score: author.trustScore),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _TrustBadge extends StatelessWidget {
  final int score;
  const _TrustBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HapaColors.ochre.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: HapaColors.ochre.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: HapaColors.ochre,
            ),
          ),
          Text(
            'trust',
            style: TextStyle(fontSize: 8, color: Colors.grey.shade500, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ── Post content ────────────────────────────────────────────────────────────

class _ContentSection extends StatefulWidget {
  final Post post;
  const _ContentSection({required this.post});

  @override
  State<_ContentSection> createState() => _ContentSectionState();
}

class _ContentSectionState extends State<_ContentSection> {
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post type badge
          Row(
            children: [
              PostTypeBadge(type: post.postType),
              if (post.distanceM > 0) ...[
                const SizedBox(width: 8),
                Row(
                  children: [
                    Icon(Icons.near_me, size: 10, color: Colors.grey.shade400),
                    const SizedBox(width: 2),
                    Text(
                      _formatDist(post.distanceM),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (post.title != null) ...[
            const SizedBox(height: 8),
            Text(
              post.title!,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: HapaColors.deep,
                height: 1.2,
              ),
            ),
          ],
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 10),
            RichContent(
              text: post.body!,
              baseStyle: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade800,
                height: 1.55,
              ),
              accentColor: _postTypeColor(post.postType),
            ),
          ],
          // Media carousel (if multiple images)
          if (post.mediaUrls.length > 1) ...[
            const SizedBox(height: 14),
            _MediaCarousel(urls: post.mediaUrls),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 80.ms).slideY(begin: 0.05, end: 0);
  }

  String _formatDist(double m) {
    if (m < 1000) return '${m.round()}m away';
    return '${(m / 1000).toStringAsFixed(1)}km away';
  }
}

class _MediaCarousel extends StatefulWidget {
  final List<String> urls;
  const _MediaCarousel({required this.urls});

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _current = 0;
  final _controller = PageController(viewportFraction: 0.92);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: isVideoUrl(widget.urls[i])
                    ? HapaVideoPlayer(
                        networkUrl: widget.urls[i],
                        autoPlay: i == _current,
                        looping: true,
                        aspectRatio: 16 / 9,
                      )
                    : CachedNetworkImage(
                        imageUrl: widget.urls[i],
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.urls.length, (i) => Container(
            width: i == _current ? 16 : 6,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i == _current ? HapaColors.ochre : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        ),
      ],
    );
  }
}

// ── Business card ───────────────────────────────────────────────────────────

class _BusinessCard extends StatelessWidget {
  final Post post;
  const _BusinessCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final biz = post.business!;
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            color: HapaColors.ochre.withOpacity(0.08),
            child: const Icon(Icons.storefront_rounded, color: HapaColors.ochre, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  biz.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: HapaColors.deep,
                  ),
                ),
                if (biz.category != null)
                  Text(
                    biz.category!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                if (biz.address != null)
                  Text(
                    biz.address!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (biz.ratingAvg != null && biz.ratingAvg! > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 13, color: HapaColors.ochre),
                    const SizedBox(width: 2),
                    Text(
                      biz.ratingAvg!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: HapaColors.deep,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 120.ms);
  }
}

// ── Tags row ────────────────────────────────────────────────────────────────

class _TagsRow extends StatelessWidget {
  final List<String> tags;
  const _TagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags.map((tag) => _Tag(label: tag)).toList(),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBE0),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(
          fontSize: 11,
          color: HapaColors.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Actions bar ─────────────────────────────────────────────────────────────

class _ActionsBar extends ConsumerStatefulWidget {
  final Post post;
  final String postId;
  const _ActionsBar({required this.post, required this.postId});

  @override
  ConsumerState<_ActionsBar> createState() => _ActionsBarState();
}

class _ActionsBarState extends ConsumerState<_ActionsBar> {
  late int _likeCount;
  late int _beenHereCount;
  late int _pulseCount;
  late bool _liked;
  late bool _beenHere;
  late bool _pulsed;
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _beenHereCount = widget.post.beenHereCount;
    _pulseCount = widget.post.pulseCount;
    _liked = widget.post.viewer.liked;
    _beenHere = widget.post.viewer.beenHere;
    _pulsed = widget.post.viewer.pulsed;
    _saved = widget.post.viewer.saved;
  }

  @override
  void didUpdateWidget(_ActionsBar old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id) {
      _likeCount = widget.post.likeCount;
      _beenHereCount = widget.post.beenHereCount;
      _pulseCount = widget.post.pulseCount;
      _liked = widget.post.viewer.liked;
      _beenHere = widget.post.viewer.beenHere;
      _pulsed = widget.post.viewer.pulsed;
      _saved = widget.post.viewer.saved;
    }
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      final result = await ref.read(feedRepositoryProvider).likePost(widget.postId);
      if (mounted) setState(() {
        _liked = result.liked;
        _likeCount = result.count;
      });
    } catch (_) {
      if (mounted) setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
      });
    }
  }

  Future<void> _markBeenHere() async {
    if (_beenHere) return;
    HapticFeedback.lightImpact();
    setState(() { _beenHere = true; _beenHereCount++; });
    try {
      await ref.read(feedRepositoryProvider).beenHere(widget.postId);
    } catch (_) {
      if (mounted) setState(() { _beenHere = false; _beenHereCount--; });
    }
  }

  Future<void> _tapPulse() async {
    if (_pulsed) return;
    HapticFeedback.lightImpact();
    setState(() { _pulsed = true; _pulseCount++; });
    try {
      await ref.read(feedRepositoryProvider).pulse(widget.postId);
    } catch (_) {
      if (mounted) setState(() { _pulsed = false; _pulseCount--; });
    }
  }

  Future<void> _tapSave() async {
    HapticFeedback.lightImpact();
    setState(() => _saved = !_saved);
    try {
      await ref.read(feedRepositoryProvider).savePost(widget.postId);
      ref.read(savedPostsProvider.notifier).refresh();
    } catch (_) {
      if (mounted) setState(() => _saved = !_saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFlash = widget.post.isFlash;
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF0EBE0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Flash posts show Pulse instead of Like
                if (isFlash)
                  _StatBtn(
                    icon: _pulsed ? Icons.bolt : Icons.bolt_outlined,
                    count: _pulseCount,
                    label: 'Pulse',
                    color: const Color(0xFFEF4444),
                    active: _pulsed,
                    onTap: _tapPulse,
                  )
                else
                  _StatBtn(
                    icon: _liked ? Icons.favorite : Icons.favorite_border,
                    count: _likeCount,
                    label: 'Like',
                    color: const Color(0xFFEF4444),
                    active: _liked,
                    onTap: _toggleLike,
                  ),
                _StatBtn(
                  icon: _beenHere ? Icons.where_to_vote : Icons.where_to_vote_outlined,
                  count: _beenHereCount,
                  label: 'Been Here',
                  color: HapaColors.ochre,
                  active: _beenHere,
                  onTap: _markBeenHere,
                ),
                _StatBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: widget.post.commentCount,
                  label: 'Comment',
                  color: const Color(0xFF6366F1),
                  active: false,
                  onTap: () {},
                ),
                _StatBtn(
                  icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                  count: 0,
                  label: _saved ? 'Saved' : 'Save',
                  color: HapaColors.deep,
                  active: _saved,
                  onTap: _tapSave,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EBE0)),
        ],
      ),
    );
  }
}

class _StatBtn extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _StatBtn({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 22, color: active ? color : Colors.grey.shade400),
              const SizedBox(height: 3),
              Text(
                count > 0 ? '$count' : label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? color : Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Comments section ────────────────────────────────────────────────────────

class _CommentsSection extends ConsumerWidget {
  final String postId;
  final void Function(PostComment) onReply;
  const _CommentsSection({required this.postId, required this.onReply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(commentsProvider(postId));
    final notifier = ref.read(commentsProvider(postId).notifier);

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sort toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Container(width: 3, height: 14, color: HapaColors.ochre),
                const SizedBox(width: 8),
                Text(
                  state.comments.isEmpty ? 'Comments' : '${state.comments.length} Comments',
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                // Sort pills
                _SortPill(
                  label: 'New',
                  active: state.sort == 'new',
                  onTap: () => notifier.load(sort: 'new'),
                ),
                const SizedBox(width: 6),
                _SortPill(
                  label: 'Top',
                  active: state.sort == 'top',
                  onTap: () => notifier.load(sort: 'top'),
                ),
              ],
            ),
          ),

          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: HapaColors.ochre, strokeWidth: 2),
              ),
            )
          else if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load comments',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            )
          else if (state.comments.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Text(
                'Be the first to comment ✨',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...state.comments.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              return _CommentThread(
                comment: c,
                postId: postId,
                onReply: onReply,
                isLast: i == state.comments.length - 1,
              ).animate(delay: Duration(milliseconds: i * 30)).fadeIn(duration: 200.ms);
            }),

          if (state.hasMore && state.comments.isNotEmpty)
            TextButton(
              onPressed: notifier.loadMore,
              child: Text(
                'Load more comments',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SortPill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: active ? HapaColors.ochre : const Color(0xFFF0EBE0),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : HapaColors.muted,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _CommentThread extends ConsumerStatefulWidget {
  final PostComment comment;
  final String postId;
  final void Function(PostComment) onReply;
  final bool isLast;
  const _CommentThread({
    required this.comment,
    required this.postId,
    required this.onReply,
    this.isLast = false,
  });

  @override
  ConsumerState<_CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends ConsumerState<_CommentThread> {
  bool _expanded = false;
  bool _loadingReplies = false;

  Future<void> _loadMore() async {
    if (_loadingReplies) return;
    setState(() => _loadingReplies = true);
    await ref.read(commentsProvider(widget.postId).notifier).loadReplies(widget.comment.id);
    if (mounted) setState(() { _loadingReplies = false; _expanded = true; });
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final hasReplies = comment.replyCount > 0;
    final shownReplies = comment.replies;
    final hiddenCount = comment.replyCount - shownReplies.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thread line column
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  PostAvatar(name: comment.displayName, url: comment.avatarUrl, radius: 14),
                  if (hasReplies || !widget.isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.only(top: 4),
                        color: hasReplies ? HapaColors.ochre.withValues(alpha: 0.2) : const Color(0xFFF0EBE0),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Comment content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CommentBubble(
                    comment: comment,
                    postId: widget.postId,
                    onReply: () => widget.onReply(comment),
                  ),
                  // Replies
                  if (_expanded || shownReplies.isNotEmpty) ...[
                    ...shownReplies.map((reply) => _ReplyBubble(
                          reply: reply,
                          postId: widget.postId,
                          onReply: () => widget.onReply(reply),
                        )),
                  ],
                  // Load more / expand
                  if (!_expanded && hiddenCount > 0)
                    GestureDetector(
                      onTap: _loadMore,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Row(
                          children: [
                            if (_loadingReplies)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: HapaColors.ochre),
                              )
                            else
                              const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: HapaColors.ochre),
                            const SizedBox(width: 6),
                            Text(
                              _loadingReplies ? 'Loading…' : 'View $hiddenCount ${hiddenCount == 1 ? 'reply' : 'replies'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: HapaColors.ochre,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentBubble extends ConsumerWidget {
  final PostComment comment;
  final String postId;
  final VoidCallback onReply;
  const _CommentBubble({required this.comment, required this.postId, required this.onReply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (comment.isDeleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          '[deleted]',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + time
        Row(
          children: [
            Text(
              comment.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: HapaColors.deep,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _timeAgo(comment.createdAt),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
        const SizedBox(height: 3),
        // Content bubble
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5F0),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichContent(
                text: comment.content,
                baseStyle: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                accentColor: HapaColors.ochre,
              ),
              // Media attachments
              if (comment.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                _CommentMedia(urls: comment.mediaUrls),
              ],
            ],
          ),
        ),
        // Action row
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Row(
            children: [
              _CommentAction(
                icon: comment.viewerLiked ? Icons.favorite : Icons.favorite_border,
                label: comment.likeCount > 0 ? '${comment.likeCount}' : 'Like',
                active: comment.viewerLiked,
                onTap: () => ref.read(commentsProvider(postId).notifier).likeComment(comment.id),
              ),
              const SizedBox(width: 12),
              _CommentAction(
                icon: Icons.reply_rounded,
                label: 'Reply',
                active: false,
                onTap: onReply,
              ),
              const Spacer(),
              _CommentMoreMenu(comment: comment, postId: postId),
            ],
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}

class _ReplyBubble extends ConsumerWidget {
  final PostComment reply;
  final String postId;
  final VoidCallback onReply;
  const _ReplyBubble({required this.reply, required this.postId, required this.onReply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostAvatar(name: reply.displayName, url: reply.avatarUrl, radius: 11),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: HapaColors.deep,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _timeAgo(reply.createdAt),
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (!reply.isDeleted) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EBE0),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichContent(
                          text: reply.content,
                          baseStyle: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                          accentColor: HapaColors.ochre,
                        ),
                        if (reply.mediaUrls.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _CommentMedia(urls: reply.mediaUrls),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 2),
                    child: Row(
                      children: [
                        _CommentAction(
                          icon: reply.viewerLiked ? Icons.favorite : Icons.favorite_border,
                          label: reply.likeCount > 0 ? '${reply.likeCount}' : 'Like',
                          active: reply.viewerLiked,
                          onTap: () => ref.read(commentsProvider(postId).notifier).likeComment(reply.id),
                        ),
                        const SizedBox(width: 10),
                        _CommentAction(
                          icon: Icons.reply_rounded,
                          label: 'Reply',
                          active: false,
                          onTap: onReply,
                        ),
                      ],
                    ),
                  ),
                ] else
                  Text(
                    '[deleted]',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}

class _CommentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CommentAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: active ? const Color(0xFFEF4444) : Colors.grey.shade400,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? const Color(0xFFEF4444) : Colors.grey.shade500,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentMoreMenu extends ConsumerWidget {
  final PostComment comment;
  final String postId;
  const _CommentMoreMenu({required this.comment, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.read(currentUserProvider);
    final isOwner = currentUser?.id == comment.userId;
    if (!isOwner) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(commentsProvider(postId).notifier).deleteComment(comment.id);
                },
              ),
            ],
          ),
        ),
      ),
      child: Icon(Icons.more_horiz, size: 14, color: Colors.grey.shade400),
    );
  }
}

class _CommentMedia extends StatelessWidget {
  final List<String> urls;
  const _CommentMedia({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: urls.first,
          width: 200,
          height: 140,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(width: 200, height: 140, color: const Color(0xFFEEE8DC)),
          errorWidget: (_, __, ___) => Container(width: 200, height: 140, color: const Color(0xFFEEE8DC)),
        ),
      );
    }
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: urls[i],
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

// ── Related posts swiper ────────────────────────────────────────────────────

class _RelatedSection extends ConsumerWidget {
  final String postId;
  final double lat, lng;

  const _RelatedSection({
    required this.postId,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedAsync = ref.watch(relatedPostsProvider((postId, lat, lng)));

    return relatedAsync.whenOrNull(
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();
        return Container(
          color: Colors.white,
          margin: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(width: 3, height: 14, color: HapaColors.ochre),
                    const SizedBox(width: 8),
                    Text(
                      'Nearby posts',
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  itemCount: posts.length,
                  itemBuilder: (_, i) => _RelatedPostCard(post: posts[i]),
                ),
              ),
            ],
          ),
        );
      },
    ) ?? const SizedBox.shrink();
  }
}

class _RelatedPostCard extends StatelessWidget {
  final Post post;
  const _RelatedPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/posts/${post.id}', extra: post),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5F0),
          border: Border.all(color: const Color(0xFFE8E0D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.mediaUrl != null)
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: post.mediaUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFFF0EBE0)),
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFFF0EBE0)),
                ),
              )
            else
              Expanded(
                child: Container(
                  color: const Color(0xFFF0EBE0),
                  child: const Center(
                    child: Icon(Icons.location_on, color: HapaColors.ochre, size: 28),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.body ?? post.title ?? '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    post.neighbourhood ?? post.city ?? '',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
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

Color _postTypeColor(String postType) {
  switch (postType) {
    case 'tip': return const Color(0xFF10B981);
    case 'review': return const Color(0xFF6366F1);
    case 'flash': return const Color(0xFFEF4444);
    case 'cultural_note': return HapaColors.sage;
    default: return HapaColors.ochre;
  }
}

// ── Comment input bar ───────────────────────────────────────────────────────

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final PostComment? replyingTo;
  final VoidCallback onCancelReply;

  const _CommentInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    this.replyingTo,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply banner
          if (replyingTo != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              color: HapaColors.ochre.withValues(alpha: 0.06),
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 14, color: HapaColors.ochre),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replying to ${replyingTo!.displayName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: HapaColors.ochre,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: const Icon(Icons.close, size: 16, color: HapaColors.ochre),
                  ),
                ],
              ),
            ),
          // Input row
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: replyingTo != null
                          ? 'Reply to ${replyingTo!.displayName}…'
                          : 'Add a comment…',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFF8F5F0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: sending
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HapaColors.ochre,
                          ),
                        )
                      : IconButton(
                          onPressed: onSend,
                          icon: const Icon(Icons.send_rounded),
                          color: HapaColors.ochre,
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

