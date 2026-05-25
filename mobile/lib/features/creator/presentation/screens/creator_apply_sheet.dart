import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/theme/app_theme.dart';

// ── Content focus options ─────────────────────────────────────────────────────

const _focusOptions = [
  (key: 'Food & Drinks',       icon: Icons.restaurant_outlined),
  (key: 'Culture & Arts',      icon: Icons.palette_outlined),
  (key: 'Travel & Tourism',    icon: Icons.flight_outlined),
  (key: 'Nightlife',           icon: Icons.nightlife),
  (key: 'Events',              icon: Icons.event_outlined),
  (key: 'Sports & Fitness',    icon: Icons.sports_outlined),
  (key: 'Tech & Innovation',   icon: Icons.devices_outlined),
  (key: 'Fashion & Lifestyle', icon: Icons.checkroom_outlined),
  (key: 'Nature & Outdoors',   icon: Icons.park_outlined),
  (key: 'Community',           icon: Icons.groups_outlined),
];

// ── Entry point ───────────────────────────────────────────────────────────────

Future<bool> showCreatorApplySheet(BuildContext context, {String? prefillCity}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreatorApplySheet(prefillCity: prefillCity),
  );
  return result == true;
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _CreatorApplySheet extends ConsumerStatefulWidget {
  final String? prefillCity;
  const _CreatorApplySheet({this.prefillCity});

  @override
  ConsumerState<_CreatorApplySheet> createState() => _CreatorApplySheetState();
}

class _CreatorApplySheetState extends ConsumerState<_CreatorApplySheet> {
  final _formKey = GlobalKey<FormState>();
  final _bioCtrl = TextEditingController();

  String? _selectedCity;     // confirmed city name
  String? _selectedFocus;
  final List<TextEditingController> _portfolioCtrl = [];

  bool _submitting = false;
  bool _detectingCity = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _addPortfolioField();

    // Seed city: prefer prefill, then user profile city, then auto-detect
    final user = ref.read(currentUserProvider);
    final seeded = widget.prefillCity ?? user?.currentCity;
    if (seeded != null && seeded.isNotEmpty) {
      _selectedCity = seeded;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _detectCity());
    }
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    for (final c in _portfolioCtrl) c.dispose();
    super.dispose();
  }

  void _addPortfolioField() {
    if (_portfolioCtrl.length >= 3) return;
    setState(() => _portfolioCtrl.add(TextEditingController()));
  }

  // ── City detection ──────────────────────────────────────────────────────────

  Future<void> _detectCity() async {
    setState(() { _detectingCity = true; _errorMsg = null; });

    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _detectingCity = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      final info = await ref.read(apiClientProvider).get<_CityResult>(
        '/v1/location/city',
        queryParams: {'lat': pos.latitude.toString(), 'lng': pos.longitude.toString()},
        fromJson: (d) => _CityResult.fromJson(d as Map<String, dynamic>),
      );

      if (mounted) setState(() { _selectedCity = info.name; _detectingCity = false; });
    } catch (_) {
      if (mounted) setState(() => _detectingCity = false);
    }
  }

  Future<void> _openCitySearch() async {
    final city = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CitySearchSheet(apiClient: ref.read(apiClientProvider)),
    );
    if (city != null && mounted) {
      setState(() => _selectedCity = city);
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      setState(() => _errorMsg = 'Please select your city first');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedFocus == null) {
      setState(() => _errorMsg = 'Please select a content focus');
      return;
    }
    setState(() { _submitting = true; _errorMsg = null; });
    HapticFeedback.mediumImpact();

    final urls = _portfolioCtrl
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      await ref.read(apiClientProvider).post<void>(
        '/v1/creators/apply',
        body: {
          'city': _selectedCity,
          'content_focus': _selectedFocus,
          'bio': _bioCtrl.text.trim(),
          'portfolio_urls': urls,
        },
        fromJson: (_) {},
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() {
        _submitting = false;
        _errorMsg = 'Something went wrong. Please try again.';
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F5F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HapaColors.ochre.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.stars_rounded, color: HapaColors.ochre, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Become a Hapa Creator',
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: HapaColors.deep,
                            )),
                        Text('We review applications within 48 hours',
                            style: TextStyle(fontSize: 12, color: HapaColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomPad),
                  children: [
                    // ── City ─────────────────────────────────────────────────
                    _SectionLabel(label: 'YOUR CITY', icon: Icons.location_city_outlined),
                    const SizedBox(height: 8),
                    _CitySelector(
                      city: _selectedCity,
                      detecting: _detectingCity,
                      onDetect: _detectCity,
                      onSearch: _openCitySearch,
                    ),
                    const SizedBox(height: 20),

                    // ── Content focus ─────────────────────────────────────────
                    _SectionLabel(label: 'CONTENT FOCUS', icon: Icons.tune_outlined),
                    const SizedBox(height: 4),
                    Text('What do you create content about?',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _focusOptions.map((opt) {
                        final selected = _selectedFocus == opt.key;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedFocus = selected ? null : opt.key;
                              _errorMsg = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? HapaColors.ochre : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: selected ? HapaColors.ochre : const Color(0xFFE0D8C8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(opt.icon, size: 14,
                                    color: selected ? Colors.white : Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(opt.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? Colors.white : HapaColors.deep,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Bio ───────────────────────────────────────────────────
                    _SectionLabel(label: 'ABOUT YOU', icon: Icons.person_outline),
                    const SizedBox(height: 8),
                    _HapaField(
                      controller: _bioCtrl,
                      hint: 'Tell us about yourself and the kind of content you create...',
                      maxLines: 4,
                      validator: (v) {
                        if (v == null || v.trim().length < 20) {
                          return 'Write at least 20 characters about yourself';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Portfolio ─────────────────────────────────────────────
                    _SectionLabel(label: 'PORTFOLIO LINKS', icon: Icons.link_outlined),
                    const SizedBox(height: 4),
                    Text('Optional — share links to your work (up to 3)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 10),
                    ..._portfolioCtrl.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HapaField(
                              controller: e.value,
                              hint: 'https://instagram.com/yourhandle',
                              keyboardType: TextInputType.url,
                            ),
                          ),
                          if (e.key > 0) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                e.value.dispose();
                                _portfolioCtrl.removeAt(e.key);
                              }),
                              child: Icon(Icons.remove_circle_outline,
                                  size: 20, color: Colors.grey.shade400),
                            ),
                          ],
                        ],
                      ),
                    )),
                    if (_portfolioCtrl.length < 3)
                      TextButton.icon(
                        onPressed: _addPortfolioField,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add another link'),
                        style: TextButton.styleFrom(
                          foregroundColor: HapaColors.ochre,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    const SizedBox(height: 24),

                    // ── Error ─────────────────────────────────────────────────
                    if (_errorMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMsg!,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Submit ────────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: HapaColors.ochre,
                          disabledBackgroundColor: HapaColors.ochre.withValues(alpha: 0.5),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Submit Application',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
}

// ── City selector widget ──────────────────────────────────────────────────────

class _CitySelector extends StatelessWidget {
  final String? city;
  final bool detecting;
  final VoidCallback onDetect;
  final VoidCallback onSearch;

  const _CitySelector({
    required this.city,
    required this.detecting,
    required this.onDetect,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    if (detecting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE0D8C8)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: HapaColors.ochre),
            ),
            const SizedBox(width: 12),
            Text('Detecting your city...',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    if (city != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: HapaColors.ochre.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: HapaColors.ochre.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: HapaColors.ochre),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(city!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HapaColors.deep,
                      )),
                ),
                const Icon(Icons.check_circle_rounded, size: 16, color: HapaColors.ochre),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CityActionLink(
                icon: Icons.my_location_rounded,
                label: 'Re-detect',
                onTap: onDetect,
              ),
              Text(' · ', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              _CityActionLink(
                icon: Icons.search,
                label: 'Search for a different city',
                onTap: onSearch,
              ),
            ],
          ),
        ],
      );
    }

    // No city yet
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onDetect,
            icon: const Icon(Icons.my_location_rounded, size: 16),
            label: const Text('Detect my city',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: HapaColors.ochre,
              side: const BorderSide(color: HapaColors.ochre),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Search for my city',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: HapaColors.deep,
              side: const BorderSide(color: Color(0xFFE0D8C8)),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _CityActionLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CityActionLink({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: HapaColors.ochre),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: HapaColors.ochre,
              fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── City search bottom sheet ───────────────────────────────────────────────────

class _CitySearchSheet extends StatefulWidget {
  final ApiClient apiClient;
  const _CitySearchSheet({required this.apiClient});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _searchCtrl = TextEditingController();
  List<_CityResult> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
    _searchCtrl.addListener(() => _search(_searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final data = await widget.apiClient.get<List<_CityResult>>(
        '/v1/location/cities',
        queryParams: {'q': q.trim()},
        fromJson: (d) {
          final list = (d as Map<String, dynamic>)['cities'] as List? ?? [];
          return list.map((e) => _CityResult.fromJson(e as Map<String, dynamic>)).toList();
        },
      );
      if (mounted) setState(() { _results = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F5F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text('Select your city',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: HapaColors.deep,
                    )),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: HapaColors.deep),
              decoration: InputDecoration(
                hintText: 'Search cities...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 18, color: HapaColors.ochre),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE0D8C8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE0D8C8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: HapaColors.ochre, width: 1.5),
                ),
              ),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(color: HapaColors.ochre, minHeight: 2),
          Expanded(
            child: _results.isEmpty && !_loading
                ? Center(
                    child: Text(
                      _searchCtrl.text.isEmpty
                          ? 'Start typing to search cities'
                          : 'No cities found for "${_searchCtrl.text}"',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final city = _results[i];
                      return ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: city.isLaunched
                                ? HapaColors.ochre.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_city_outlined,
                            size: 16,
                            color: city.isLaunched ? HapaColors.ochre : Colors.grey.shade400,
                          ),
                        ),
                        title: Text(city.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: HapaColors.deep,
                            )),
                        subtitle: Text(city.country,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        trailing: city.isLaunched
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Text('LIVE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981),
                                      letterSpacing: 0.5,
                                    )),
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(city.name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── City model ────────────────────────────────────────────────────────────────

class _CityResult {
  final String name;
  final String country;
  final bool isLaunched;

  const _CityResult({required this.name, required this.country, required this.isLaunched});

  factory _CityResult.fromJson(Map<String, dynamic> j) => _CityResult(
    name: j['name'] as String? ?? '',
    country: j['country'] as String? ?? '',
    isLaunched: j['is_launched'] as bool? ?? false,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: HapaColors.ochre),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade400,
              letterSpacing: 1.2,
            )),
      ],
    );
  }
}

class _HapaField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _HapaField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: HapaColors.deep),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0D8C8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0D8C8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: HapaColors.ochre, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}
