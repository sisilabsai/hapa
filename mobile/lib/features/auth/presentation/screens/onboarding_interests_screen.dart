import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/theme/app_theme.dart';

const _kInterests = [
  (tag: 'food_dining', label: 'Food & Dining', icon: '🍽️'),
  (tag: 'nightlife', label: 'Nightlife', icon: '🌙'),
  (tag: 'arts_culture', label: 'Arts & Culture', icon: '🎨'),
  (tag: 'business_networking', label: 'Business & Networking', icon: '💼'),
  (tag: 'sports_fitness', label: 'Sports & Fitness', icon: '⚽'),
  (tag: 'faith_community', label: 'Faith & Community', icon: '🕊️'),
  (tag: 'family_parenting', label: 'Family & Parenting', icon: '👨‍👩‍👧'),
  (tag: 'fashion_style', label: 'Fashion & Style', icon: '👗'),
  (tag: 'music_events', label: 'Music & Events', icon: '🎶'),
  (tag: 'street_life', label: 'Street Life', icon: '🏙️'),
  (tag: 'travel', label: 'Travel', icon: '✈️'),
  (tag: 'tech', label: 'Tech', icon: '💻'),
  (tag: 'nature_outdoors', label: 'Nature & Outdoors', icon: '🌿'),
];

const _kMinSelections = 3;
const _kMaxSelections = 7;

class OnboardingInterestsScreen extends ConsumerStatefulWidget {
  final String city;
  final String country;
  final bool isLaunched;
  final String userType;
  final String name;

  const OnboardingInterestsScreen({
    super.key,
    required this.city,
    required this.country,
    required this.isLaunched,
    required this.userType,
    required this.name,
  });

  @override
  ConsumerState<OnboardingInterestsScreen> createState() =>
      _OnboardingInterestsScreenState();
}

class _OnboardingInterestsScreenState
    extends ConsumerState<OnboardingInterestsScreen> {
  final Set<String> _selected = {};
  bool _submitting = false;
  String? _error;

  bool get _canSubmit => _selected.length >= _kMinSelections && !_submitting;

  void _toggle(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else if (_selected.length < _kMaxSelections) {
        _selected.add(tag);
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final client = ref.read(apiClientProvider);
      await client.post<void>(
        '/v1/users/me/onboarding',
        body: {
          'display_name': widget.name,
          'user_type': widget.userType,
          'interest_tags': _selected.toList(),
          'language': 'en',
        },
        fromJson: (_) {},
      );
      // Refresh user so the router redirect fires
      await ref.read(userNotifierProvider.notifier).load();
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    return Scaffold(
      backgroundColor: const Color(0xFF140F08),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    sliver: SliverToBoxAdapter(child: _buildHeader()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.7,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final interest = _kInterests[i];
                          final sel = _selected.contains(interest.tag);
                          final maxed = _selected.length >= _kMaxSelections && !sel;
                          return _InterestChip(
                            icon: interest.icon,
                            label: interest.label,
                            selected: sel,
                            dimmed: maxed,
                            onTap: maxed ? null : () => _toggle(interest.tag),
                          );
                        },
                        childCount: _kInterests.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildFooter(count),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Icon(Icons.arrow_back, color: Colors.grey.shade600, size: 22),
        ),
        const SizedBox(height: 32),
        Text(
          "WHAT'S YOUR SCENE IN",
          style: TextStyle(
            color: HapaColors.ochre.withValues(alpha: 0.55),
            fontSize: 11,
            fontFamily: 'JetBrainsMono',
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.city.toUpperCase()}?',
          style: const TextStyle(
            color: HapaColors.ochre,
            fontSize: 44,
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Pick $_kMinSelections–$_kMaxSelections things that matter to you.',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(int count) {
    final remaining = _kMinSelections - count;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF140F08),
        border: Border(top: BorderSide(color: Color(0xFF2A1E10))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count selected',
                      style: TextStyle(
                        color: count >= _kMinSelections
                            ? HapaColors.ochre
                            : Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (remaining > 0)
                      Text(
                        'Pick $remaining more',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                  ],
                ),
              ),
              SizedBox(
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HapaColors.ochre,
                    disabledBackgroundColor: const Color(0xFF3A2A18),
                    foregroundColor: const Color(0xFF140F08),
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF140F08),
                          ),
                        )
                      : const Row(
                          children: [
                            Text(
                              "LET'S GO",
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 15),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  const _InterestChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.dimmed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected
              ? HapaColors.ochre.withValues(alpha: 0.12)
              : const Color(0xFF1E1610),
          border: Border.all(
            color: selected
                ? HapaColors.ochre
                : dimmed
                    ? const Color(0xFF201810)
                    : const Color(0xFF2E2018),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                icon,
                style: TextStyle(
                  fontSize: 20,
                  color: dimmed ? Colors.grey.shade800 : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? HapaColors.ochre
                        : dimmed
                            ? Colors.grey.shade700
                            : Colors.white,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
