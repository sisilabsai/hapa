import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

const _kUserTypes = [
  (value: 'resident', label: 'Resident', sub: 'I live here', icon: '🏠'),
  (value: 'new_arrival', label: 'New Arrival', sub: 'Just moved here', icon: '🌱'),
  (value: 'traveller', label: 'Traveller', sub: 'Passing through', icon: '✈️'),
  (value: 'business_owner', label: 'Business Owner', sub: 'I run something here', icon: '💼'),
];

class OnboardingIdentityScreen extends StatefulWidget {
  final String city;
  final String country;
  final bool isLaunched;

  const OnboardingIdentityScreen({
    super.key,
    required this.city,
    required this.country,
    required this.isLaunched,
  });

  @override
  State<OnboardingIdentityScreen> createState() => _OnboardingIdentityScreenState();
}

class _OnboardingIdentityScreenState extends State<OnboardingIdentityScreen> {
  String? _selectedType;
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _nameError = 'Enter at least 2 characters');
      _nameFocus.requestFocus();
      return;
    }
    if (_selectedType == null) return;
    context.push('/auth/onboarding/interests', extra: {
      'city': widget.city,
      'country': widget.country,
      'is_launched': widget.isLaunched,
      'user_type': _selectedType!,
      'name': name,
    });
  }

  bool get _canContinue => _selectedType != null && _nameCtrl.text.trim().length >= 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140F08),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 36),
                    _buildNameField(),
                    const SizedBox(height: 36),
                    _buildTypeTiles(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
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
          'WHO ARE YOU IN',
          style: TextStyle(
            color: HapaColors.ochre.withValues(alpha: 0.55),
            fontSize: 11,
            fontFamily: 'JetBrainsMono',
            letterSpacing: 3.0,
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
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT SHOULD WE CALL YOU?',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
            fontFamily: 'JetBrainsMono',
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameCtrl,
          focusNode: _nameFocus,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _nameError = null),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          cursorColor: HapaColors.ochre,
          decoration: InputDecoration(
            fillColor: const Color(0xFF2A1E10),
            filled: true,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFF3A2A18)),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFF3A2A18)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: HapaColors.ochre),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFFEF4444)),
            ),
            hintText: 'Your name',
            hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            errorText: _nameError,
            errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeTiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR ROLE HERE',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
            fontFamily: 'JetBrainsMono',
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: _kUserTypes.map((t) => _TypeTile(
            icon: t.icon,
            label: t.label,
            sub: t.sub,
            selected: _selectedType == t.value,
            onTap: () => setState(() => _selectedType = t.value),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF140F08),
        border: Border(top: BorderSide(color: Color(0xFF2A1E10))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canContinue ? _continue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: HapaColors.ochre,
            disabledBackgroundColor: const Color(0xFF3A2A18),
            foregroundColor: const Color(0xFF140F08),
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CONTINUE',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final String icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? HapaColors.ochre.withValues(alpha: 0.12)
              : const Color(0xFF1E1610),
          border: Border.all(
            color: selected ? HapaColors.ochre : const Color(0xFF2E2018),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
                  if (selected)
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: HapaColors.ochre,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Color(0xFF140F08), size: 11),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? HapaColors.ochre : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
