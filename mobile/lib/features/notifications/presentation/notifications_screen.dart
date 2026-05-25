import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class HapaNotification {
  final String id, type, title, body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  const HapaNotification({
    required this.id, required this.type,
    required this.title, required this.body,
    required this.isRead, required this.createdAt,
    this.data = const {},
  });

  factory HapaNotification.fromJson(Map<String, dynamic> j) => HapaNotification(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'system',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? {},
      );

  HapaNotification copyWith({bool? isRead}) => HapaNotification(
        id: id, type: type, title: title, body: body,
        isRead: isRead ?? this.isRead, createdAt: createdAt, data: data,
      );
}

// ── State ─────────────────────────────────────────────────────────────────────

class _NotifsState {
  final List<HapaNotification> notifs;
  final bool isLoading;
  final String? error;
  const _NotifsState({this.notifs = const [], this.isLoading = false, this.error});
  _NotifsState copyWith({List<HapaNotification>? notifs, bool? isLoading, String? error}) =>
      _NotifsState(notifs: notifs ?? this.notifs, isLoading: isLoading ?? this.isLoading, error: error);
}

class _NotifsNotifier extends StateNotifier<_NotifsState> {
  final ApiClient _client;
  _NotifsNotifier(this._client) : super(const _NotifsState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final notifs = await _client.get<List<HapaNotification>>(
        '/v1/notifications',
        fromJson: (d) => ((d['notifications'] as List?) ?? [])
            .map((n) => HapaNotification.fromJson(n as Map<String, dynamic>))
            .toList(),
      );
      state = _NotifsState(notifs: notifs);
    } catch (e) {
      state = _NotifsState(error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _load();
  }

  Future<void> markRead(String id) async {
    state = state.copyWith(
      notifs: state.notifs.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
    );
    try {
      await _client.post<void>('/v1/notifications/read', body: {'ids': [id]}, fromJson: (_) {});
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    state = state.copyWith(
      notifs: state.notifs.map((n) => n.copyWith(isRead: true)).toList(),
    );
    try {
      await _client.post<void>('/v1/notifications/read', body: {'ids': <String>[]}, fromJson: (_) {});
    } catch (_) {}
  }
}

final _notifsProvider = StateNotifierProvider.autoDispose<_NotifsNotifier, _NotifsState>((ref) {
  return _NotifsNotifier(ref.watch(apiClientProvider));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_notifsProvider);
    final unread = state.notifs.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: Colors.grey.shade700,
          onPressed: () => context.pop(),
          splashRadius: 20,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            if (unread > 0)
              Text(
                '$unread unread',
                style: const TextStyle(fontSize: 11, color: HapaColors.ochre, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(_notifsProvider.notifier).markAllRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: HapaColors.ochre, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: state.isLoading
          ? _NotifSkeleton()
          : state.error != null
              ? _ErrorState(onRetry: () => ref.read(_notifsProvider.notifier).refresh())
              : state.notifs.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      color: HapaColors.ochre,
                      displacement: 16,
                      onRefresh: () => ref.read(_notifsProvider.notifier).refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 40),
                        itemCount: state.notifs.length,
                        itemBuilder: (ctx, i) {
                          final n = state.notifs[i];
                          final isToday = n.createdAt.day == DateTime.now().day &&
                              n.createdAt.year == DateTime.now().year;
                          final showHeader = i == 0 ||
                              (state.notifs[i - 1].createdAt.day != n.createdAt.day);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showHeader)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                  child: Text(
                                    isToday ? 'Today' : _formatDate(n.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              _NotifCard(
                                notif: n,
                                onTap: () {
                                  ref.read(_notifsProvider.notifier).markRead(n.id);
                                  _handleDeepLink(context, n);
                                },
                              )
                                  .animate(delay: Duration(milliseconds: (i % 10) * 40))
                                  .fadeIn(duration: 220.ms)
                                  .slideX(begin: 0.04, end: 0, duration: 220.ms),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }

  void _handleDeepLink(BuildContext context, HapaNotification n) {
    final data = n.data;
    switch (n.type) {
      case 'follow':
        final userId = data['follower_id'] as String?;
        if (userId != null) context.push('/creators/$userId');
      case 'like':
      case 'comment':
        final postId = data['post_id'] as String?;
        if (postId != null) context.push('/posts/$postId');
      case 'booking':
        final placeId = data['business_id'] as String?;
        if (placeId != null) context.push('/places/$placeId');
      case 'city_switch':
        context.go('/guide');
      default:
        break;
    }
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Notification Card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final HapaNotification notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  _NotifMeta get _meta => _metaFor(notif.type);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : HapaColors.ochre.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? Colors.grey.shade100 : HapaColors.ochre.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _meta.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(_meta.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 13.5,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notif.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: HapaColors.ochre,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _meta.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _meta.label,
                            style: TextStyle(fontSize: 10, color: _meta.color, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(notif.createdAt),
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

// ── Notification Meta ─────────────────────────────────────────────────────────

class _NotifMeta {
  final String emoji, label;
  final Color color;
  const _NotifMeta({required this.emoji, required this.label, required this.color});
}

_NotifMeta _metaFor(String type) {
  switch (type) {
    case 'follow':
      return const _NotifMeta(emoji: '👤', label: 'Follow', color: Color(0xFF7C3AED));
    case 'like':
      return const _NotifMeta(emoji: '❤️', label: 'Like', color: Color(0xFFEF4444));
    case 'comment':
      return const _NotifMeta(emoji: '💬', label: 'Comment', color: Color(0xFF2563EB));
    case 'booking':
      return const _NotifMeta(emoji: '📅', label: 'Booking', color: Color(0xFF059669));
    case 'city_switch':
      return const _NotifMeta(emoji: '🌍', label: 'City', color: Color(0xFFD97706));
    case 'flash':
      return const _NotifMeta(emoji: '⚡', label: 'Flash', color: Color(0xFFEF4444));
    case 'tip':
      return const _NotifMeta(emoji: '💡', label: 'Tip', color: Color(0xFFF59E0B));
    default:
      return const _NotifMeta(emoji: '🔔', label: 'Notice', color: Color(0xFF6B7280));
  }
}

// ── Empty / Error / Skeleton ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 18),
          const Text(
            'You\'re all caught up',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'New activity from people and places\nyou follow will appear here.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
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
          Text('Could not load notifications', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
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

class _NotifSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
