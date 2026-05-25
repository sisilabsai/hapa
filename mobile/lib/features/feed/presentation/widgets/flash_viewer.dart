import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/post.dart';

class FlashViewer extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;
  const FlashViewer({super.key, required this.posts, this.initialIndex = 0});

  @override
  State<FlashViewer> createState() => _FlashViewerState();
}

class _FlashViewerState extends State<FlashViewer>
    with SingleTickerProviderStateMixin {
  late int _index;
  late AnimationController _prog;
  late PageController _pc;

  static const _duration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pc = PageController(initialPage: _index);
    _prog = AnimationController(vsync: this, duration: _duration)
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _advance();
      });
    _prog.forward();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _prog.dispose();
    _pc.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _advance() {
    if (_index < widget.posts.length - 1) {
      _goTo(_index + 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _back() {
    if (_index > 0) {
      _goTo(_index - 1);
    } else {
      _prog.reset();
      _prog.forward();
    }
  }

  void _goTo(int i) {
    setState(() => _index = i);
    _pc.jumpToPage(i);
    _prog.reset();
    _prog.forward();
  }

  void _pause() => _prog.stop();
  void _resume() => _prog.forward();

  @override
  Widget build(BuildContext context) {
    final post = widget.posts[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w / 3) {
            _back();
          } else if (d.globalPosition.dx > w * 2 / 3) {
            _advance();
          }
        },
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity != null && d.primaryVelocity! > 400) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: image or gradient
            PageView.builder(
              controller: _pc,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.posts.length,
              itemBuilder: (_, i) => _StoryBackground(post: widget.posts[i]),
            ),

            // Dark gradient at top + bottom
            const _EdgeGradients(),

            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(widget.posts.length, (i) {
                  double value;
                  if (i < _index) {
                    value = 1.0;
                  } else if (i == _index) {
                    value = _prog.value;
                  } else {
                    value = 0.0;
                  }
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 2.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Header: avatar + name + time + close
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  _AvatarCircle(post: post),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.businessName ?? post.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (post.city != null)
                          Text(
                            post.city!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _TimeChip(post: post),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Footer: title + body + tags + action
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _StoryFooter(
                post: post,
                onViewPost: () {
                  Navigator.of(context).pop();
                  context.push('/posts/${post.id}');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StoryBackground extends StatelessWidget {
  final Post post;
  const _StoryBackground({required this.post});

  @override
  Widget build(BuildContext context) {
    final img = post.mediaUrl;
    if (img != null) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _GradientBg(post: post),
      );
    }
    return _GradientBg(post: post);
  }
}

class _GradientBg extends StatelessWidget {
  final Post post;
  const _GradientBg({required this.post});

  Color get _color {
    final palette = [
      const Color(0xFF1E1830),
      const Color(0xFF0D1F2D),
      const Color(0xFF1A200F),
      const Color(0xFF2D0F0F),
      const Color(0xFF0F1A2D),
    ];
    final hash = post.userId.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
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
    );
  }
}

class _EdgeGradients extends StatelessWidget {
  const _EdgeGradients();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Top fade
        Positioned(
          top: 0, left: 0, right: 0,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom fade
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 220,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final Post post;
  const _AvatarCircle({required this.post});

  @override
  Widget build(BuildContext context) {
    final img = post.displayAvatar;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: img != null
            ? Image.network(img, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initial(post.displayName))
            : _initial(post.displayName),
      ),
    );
  }

  Widget _initial(String name) => Container(
        color: HapaColors.ochre,
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      );
}

class _TimeChip extends StatelessWidget {
  final Post post;
  const _TimeChip({required this.post});

  String get _label {
    if (post.flashExpiresAt == null) return 'FLASH';
    final left = post.flashExpiresAt!.difference(DateTime.now());
    if (left.isNegative) return 'ENDED';
    if (left.inHours >= 1) return '${left.inHours}h left';
    return '${left.inMinutes}m left';
  }

  Color get _color {
    if (post.flashExpiresAt == null) return HapaColors.ochre;
    final left = post.flashExpiresAt!.difference(DateTime.now());
    if (left.isNegative) return Colors.grey;
    if (left.inMinutes < 30) return const Color(0xFFEF4444);
    return HapaColors.ochre;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StoryFooter extends StatelessWidget {
  final Post post;
  final VoidCallback onViewPost;
  const _StoryFooter({required this.post, required this.onViewPost});

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, safeBottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tags
          if (post.interestTags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              children: post.interestTags.take(3).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#$t',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              )).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Title
          if (post.title != null && post.title!.isNotEmpty) ...[
            Text(
              post.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
          ],

          // Body
          if (post.body != null && post.body!.isNotEmpty) ...[
            Text(
              post.body!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
          ],

          // View post button
          GestureDetector(
            onTap: onViewPost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'View Post',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.black),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
