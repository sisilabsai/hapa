import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/post.dart';
import 'flash_viewer.dart';

class FlashStories extends StatelessWidget {
  final List<Post> posts;
  const FlashStories({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: posts.length,
        itemBuilder: (ctx, i) => _StoryBubble(
          post: posts[i],
          onTap: () => _openViewer(context, i),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int startIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => FlashViewer(
          posts: posts,
          initialIndex: startIndex,
        ),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  const _StoryBubble({required this.post, required this.onTap});

  String get _label {
    if (post.businessName != null) return post.businessName!;
    return post.displayName;
  }

  Duration? get _timeLeft {
    if (post.flashExpiresAt == null) return null;
    final r = post.flashExpiresAt!.difference(DateTime.now());
    return r.isNegative ? null : r;
  }

  Color get _ringColor {
    final left = _timeLeft;
    if (left == null) return Colors.grey.shade600;
    if (left.inMinutes < 30) return const Color(0xFFEF4444);
    return HapaColors.ochre;
  }

  String get _timeLabel {
    final left = _timeLeft;
    if (left == null) return 'ended';
    if (left.inHours >= 1) return '${left.inHours}h';
    return '${left.inMinutes}m';
  }

  // Deterministic pastel color from post id
  Color get _fallbackColor {
    final palette = [
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFDC2626),
      const Color(0xFF2563EB),
    ];
    final hash = post.userId.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Gradient ring
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [_ringColor, _ringColor.withValues(alpha: 0.3), _ringColor],
                    ),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: _buildAvatar(),
                    ),
                  ),
                ),
                // Time badge
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _ringColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      _timeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 66,
              child: Text(
                _label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final thumb = post.mediaUrl ?? post.displayAvatar;
    if (thumb != null) {
      return Image.network(
        thumb,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Initials(
          text: _label,
          color: _fallbackColor,
        ),
      );
    }
    return _Initials(text: _label, color: _fallbackColor);
  }
}

class _Initials extends StatelessWidget {
  final String text;
  final Color color;
  const _Initials({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        text.isNotEmpty ? text[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
