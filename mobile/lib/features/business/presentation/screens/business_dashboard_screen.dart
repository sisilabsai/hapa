import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class Business {
  final String id;
  final String name;
  final String category;
  final String city;
  final String? coverUrl;
  final double ratingAvg;
  final int reviewCount;
  final String tier;
  final bool isVerified;
  final bool boostActive;

  const Business({
    required this.id,
    required this.name,
    required this.category,
    required this.city,
    this.coverUrl,
    required this.ratingAvg,
    required this.reviewCount,
    required this.tier,
    required this.isVerified,
    required this.boostActive,
  });

  factory Business.fromJson(Map<String, dynamic> j) => Business(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String? ?? '',
        city: j['city'] as String? ?? '',
        coverUrl: j['cover_url'] as String?,
        ratingAvg: (j['rating_avg'] as num?)?.toDouble() ?? 0.0,
        reviewCount: j['review_count'] as int? ?? 0,
        tier: j['tier'] as String? ?? 'basic',
        isVerified: j['is_verified'] as bool? ?? false,
        boostActive: j['boost_active'] as bool? ?? false,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _myBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get<Map<String, dynamic>>(
    '/v1/businesses/mine',
    fromJson: (d) => d as Map<String, dynamic>,
  );
  final list = data['businesses'] as List? ?? [];
  return list.map((e) => Business.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myBusinessesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: const Text(
          'My Businesses',
          style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: HapaColors.deep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: HapaColors.ochre,
            onPressed: () => _openAddBusiness(context, ref),
            tooltip: 'Register business',
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: HapaColors.ochre, strokeWidth: 2),
        ),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(_myBusinessesProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (businesses) => businesses.isEmpty
            ? _EmptyState(onAdd: () => _openAddBusiness(context, ref))
            : RefreshIndicator(
                color: HapaColors.ochre,
                onRefresh: () async => ref.invalidate(_myBusinessesProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: businesses.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BusinessCard(
                      business: businesses[i],
                      onBoostTap: () => _openBoost(context, ref, businesses[i]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _openAddBusiness(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddBusinessSheet(),
    ).then((_) => ref.invalidate(_myBusinessesProvider));
  }

  void _openBoost(BuildContext context, WidgetRef ref, Business biz) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateBoostSheet(business: biz),
    ).then((_) => ref.invalidate(_myBusinessesProvider));
  }
}

// ── Business card ─────────────────────────────────────────────────────────────

class _BusinessCard extends StatelessWidget {
  final Business business;
  final VoidCallback onBoostTap;

  const _BusinessCard({required this.business, required this.onBoostTap});

  @override
  Widget build(BuildContext context) {
    final b = business;
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.coverUrl != null && b.coverUrl!.isNotEmpty)
            Image.network(
              b.coverUrl!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  b.name,
                                  style: const TextStyle(
                                    fontFamily: 'Fraunces',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: HapaColors.deep,
                                  ),
                                ),
                              ),
                              if (b.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, size: 15, color: HapaColors.ochre),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${b.category} · ${b.city}',
                            style: TextStyle(color: HapaColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _TierBadge(tier: b.tier),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats row
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.star_outline,
                      value: b.ratingAvg > 0
                          ? b.ratingAvg.toStringAsFixed(1)
                          : '–',
                      label: 'Rating',
                    ),
                    const SizedBox(width: 20),
                    _MiniStat(
                      icon: Icons.rate_review_outlined,
                      value: '${b.reviewCount}',
                      label: 'Reviews',
                    ),
                    const Spacer(),
                    if (b.boostActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: HapaColors.ochre.withValues(alpha: 0.12),
                        child: const Text(
                          '⚡ BOOST LIVE',
                          style: TextStyle(
                            color: HapaColors.ochre,
                            fontSize: 9,
                            fontFamily: 'JetBrainsMono',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: b.boostActive ? null : onBoostTap,
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(b.boostActive ? 'BOOST ACTIVE' : 'LAUNCH BOOST'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: b.boostActive
                          ? Colors.grey.shade100
                          : HapaColors.ochre,
                      foregroundColor: b.boostActive
                          ? Colors.grey.shade400
                          : const Color(0xFF140F08),
                      elevation: 0,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
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
        ],
      ),
    );
  }
}

// ── Create Boost sheet ────────────────────────────────────────────────────────

const _kRadiusOptions = [
  (value: 500, label: '500 m'),
  (value: 1000, label: '1 km'),
  (value: 2000, label: '2 km'),
  (value: 5000, label: '5 km'),
];

const _kDurationOptions = [
  (value: 1, label: '1 hour'),
  (value: 3, label: '3 hours'),
  (value: 6, label: '6 hours'),
  (value: 24, label: '1 day'),
  (value: 72, label: '3 days'),
  (value: 168, label: '7 days'),
];

class _CreateBoostSheet extends ConsumerStatefulWidget {
  final Business business;
  const _CreateBoostSheet({required this.business});

  @override
  ConsumerState<_CreateBoostSheet> createState() => _CreateBoostSheetState();
}

class _CreateBoostSheetState extends ConsumerState<_CreateBoostSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _offerCtrl = TextEditingController();
  int _radiusM = 1000;
  int _durationHours = 6;
  double _budgetUSD = 5.0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _offerCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty && _offerCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final client = ref.read(apiClientProvider);
      await client.post<void>(
        '/v1/businesses/${widget.business.id}/boost',
        body: {
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'offer_text': _offerCtrl.text.trim(),
          'radius_m': _radiusM,
          'duration_hours': _durationHours,
          'budget_usd': _budgetUSD,
        },
        fromJson: (_) {},
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚡ Boost live! Reaching users within ${_formatRadius(_radiusM)}.',
            ),
            backgroundColor: HapaColors.deep,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not launch boost. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        color: Colors.white,
        child: Column(
          children: [
            _buildHandle(),
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                        ),
                      ),
                    _buildInfoBanner(),
                    const SizedBox(height: 20),
                    _buildLabel('BOOST TITLE'),
                    const SizedBox(height: 8),
                    _buildField(_titleCtrl, 'e.g. Happy Hour at Café Nile', maxLines: 1),
                    const SizedBox(height: 16),
                    _buildLabel('OFFER (WHAT NEARBY USERS WILL SEE)'),
                    const SizedBox(height: 8),
                    _buildField(_offerCtrl, 'e.g. 20% off all meals today only', maxLines: 2),
                    const SizedBox(height: 16),
                    _buildLabel('DESCRIPTION (OPTIONAL)'),
                    const SizedBox(height: 8),
                    _buildField(_descCtrl, 'More details about the offer...', maxLines: 3),
                    const SizedBox(height: 24),
                    _buildLabel('RADIUS'),
                    const SizedBox(height: 10),
                    _buildOptionRow<int>(
                      options: _kRadiusOptions.map((o) => (o.value, o.label)).toList(),
                      selected: _radiusM,
                      onSelect: (v) => setState(() => _radiusM = v),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('DURATION'),
                    const SizedBox(height: 10),
                    _buildOptionRow<int>(
                      options: _kDurationOptions.map((o) => (o.value, o.label)).toList(),
                      selected: _durationHours,
                      onSelect: (v) => setState(() => _durationHours = v),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('BUDGET (USD)'),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${_budgetUSD.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: HapaColors.ochre,
                          ),
                        ),
                        Text(
                          'max spend',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                    Slider(
                      value: _budgetUSD,
                      min: 1.0,
                      max: 100.0,
                      divisions: 99,
                      activeColor: HapaColors.ochre,
                      inactiveColor: HapaColors.ochre.withValues(alpha: 0.15),
                      onChanged: (v) => setState(() => _budgetUSD = v.roundToDouble()),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estimated reach: ${_estimateReach(_radiusM, _budgetUSD)} people',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canSubmit && !_submitting ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HapaColors.ochre,
                          disabledBackgroundColor: Colors.grey.shade100,
                          foregroundColor: const Color(0xFF140F08),
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'LAUNCH BOOST · \$${_budgetUSD.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 36,
        height: 3,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
      );

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hapa Boost',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: HapaColors.deep,
                    ),
                  ),
                  Text(
                    widget.business.name,
                    style: TextStyle(color: HapaColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildInfoBanner() => Container(
        padding: const EdgeInsets.all(12),
        color: HapaColors.ochre.withValues(alpha: 0.07),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: HapaColors.ochre),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Your offer appears instantly to nearby Hapa users within your chosen radius.',
                style: TextStyle(color: HapaColors.deep, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _buildLabel(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 10,
          fontFamily: 'JetBrainsMono',
          letterSpacing: 1.5,
        ),
      );

  Widget _buildField(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _buildOptionRow<T>({
    required List<(T, String)> options,
    required T selected,
    required void Function(T) onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt.$1 == selected;
        return GestureDetector(
          onTap: () => onSelect(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? HapaColors.ochre : Colors.transparent,
              border: Border.all(
                color: isSelected ? HapaColors.ochre : Colors.grey.shade200,
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                color: isSelected ? Colors.white : HapaColors.deep,
                fontSize: 12,
                fontFamily: 'JetBrainsMono',
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatRadius(int m) {
    if (m >= 1000) return '${m ~/ 1000} km';
    return '${m}m';
  }

  String _estimateReach(int radiusM, double budget) {
    final base = (radiusM / 500).round() * 50;
    final budgetMultiplier = (budget / 5).round();
    final reach = base * budgetMultiplier;
    if (reach >= 1000) return '${(reach / 1000).toStringAsFixed(1)}k+';
    return '$reach+';
  }
}

// ── Add Business sheet ────────────────────────────────────────────────────────

const _kBusinessCategories = [
  'Restaurant', 'Café & Coffee', 'Bar & Lounge', 'Hotel & Accommodation',
  'Retail & Shopping', 'Health & Beauty', 'Fitness & Sports', 'Education',
  'Entertainment', 'Services', 'Tech & Digital', 'Other',
];

class _AddBusinessSheet extends ConsumerStatefulWidget {
  const _AddBusinessSheet();

  @override
  ConsumerState<_AddBusinessSheet> createState() => _AddBusinessSheetState();
}

class _AddBusinessSheetState extends ConsumerState<_AddBusinessSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _category;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameCtrl.text.trim().length >= 3 && _category != null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final client = ref.read(apiClientProvider);
      await client.post<void>(
        '/v1/businesses',
        body: {
          'name': _nameCtrl.text.trim(),
          'category': _category,
          'phone': _phoneCtrl.text.trim(),
          'lat': 0.0,
          'lng': 0.0,
        },
        fromJson: (_) {},
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not register business. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        color: Colors.white,
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
                      'Register Business',
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
                            'REGISTER',
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                      ),
                    _buildLabel('BUSINESS NAME'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDeco('Official business name'),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('CATEGORY'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kBusinessCategories.map((cat) {
                        final selected = _category == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _category = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? HapaColors.ochre.withValues(alpha: 0.08) : Colors.transparent,
                              border: Border.all(
                                color: selected ? HapaColors.ochre : Colors.grey.shade200,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: selected ? HapaColors.ochre : HapaColors.deep,
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('PHONE (OPTIONAL)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _fieldDeco('+256 700 000 000'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xFFFAF8F5),
                      child: const Text(
                        'Your business will be visible on the Hapa map after review. You can add your location, photos, and hours after registration.',
                        style: TextStyle(color: HapaColors.muted, fontSize: 12, height: 1.5),
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

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = switch (tier) {
      'premium' => HapaColors.ochre,
      'verified' => HapaColors.sage,
      _ => HapaColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: color.withValues(alpha: 0.12),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontFamily: 'JetBrainsMono',
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: HapaColors.muted),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: HapaColors.deep,
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏪', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            const Text(
              'No businesses yet',
              style: TextStyle(
                color: HapaColors.deep,
                fontSize: 18,
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Register your business and start reaching\nnearby customers on Hapa.',
              style: TextStyle(color: HapaColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: HapaColors.ochre,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                elevation: 0,
                textStyle: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              child: const Text('REGISTER YOUR BUSINESS'),
            ),
          ],
        ),
      ),
    );
  }
}
