import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/post.dart';

class FlashBanner extends StatefulWidget {
  final List<Post> posts;
  const FlashBanner({super.key, required this.posts});

  @override
  State<FlashBanner> createState() => _FlashBannerState();
}

class _FlashBannerState extends State<FlashBanner> {
  int _current = 0;
  late final PageController _pc;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A0A0A),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: const Color(0xFFEF4444),
                  child: const Text(
                    'FLASH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Happening right now',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  '${_current + 1}/${widget.posts.length}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 80,
            child: PageView.builder(
              controller: _pc,
              itemCount: widget.posts.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => _FlashItem(post: widget.posts[i]),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _FlashItem extends StatelessWidget {
  final Post post;
  const _FlashItem({required this.post});

  Duration? _timeLeft() {
    if (post.flashExpiresAt == null) return null;
    final remaining = post.flashExpiresAt!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  @override
  Widget build(BuildContext context) {
    final left = _timeLeft();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (post.mediaUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                post.mediaUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (post.businessName != null)
                  Text(
                    post.businessName!,
                    style: const TextStyle(
                      color: HapaColors.ochre,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  post.title ?? post.body ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (left != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 10, color: Color(0xFFEF4444)),
                      const SizedBox(width: 3),
                      Text(
                        '${left.inHours}h ${left.inMinutes.remainder(60)}m left',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
        ],
      ),
    );
  }
}
