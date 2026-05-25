import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/post_card.dart';

const _interestOptions = [
  'food', 'nightlife', 'culture', 'sports', 'events', 'shopping',
  'travel', 'nature', 'music', 'art', 'tech', 'education', 'health', 'community',
];

const _userTypes = {
  'resident': 'Resident',
  'new_arrival': 'New Arrival',
  'traveller': 'Traveller',
  'business_owner': 'Business Owner',
};

const _languages = {
  'en': 'English',
  'lg': 'Luganda',
  'sw': 'Swahili',
  'fr': 'French',
};

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _cityCtrl;
  String? _editUserType;
  String? _editLanguage;
  List<String> _editTags = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _startEdit(CurrentUser user) {
    _nameCtrl.text = user.displayName;
    _bioCtrl.text = user.bio ?? '';
    _cityCtrl.text = user.homeCity ?? '';
    _editUserType = user.userType;
    _editLanguage = user.language;
    _editTags = List.from(user.interestTags);
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref.read(userNotifierProvider.notifier).updateProfile(
      displayName: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      userType: _editUserType,
      homeCity: _cityCtrl.text.trim(),
      language: _editLanguage,
      interestTags: _editTags,
    );
    if (mounted) {
      setState(() { _saving = false; _editing = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Profile updated!' : 'Update failed. Try again.'),
          backgroundColor: ok ? HapaColors.sage : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancelEdit() => setState(() => _editing = false);

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!_editing)
            userAsync.whenOrNull(
              data: (user) => TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: HapaColors.ochre),
                onPressed: () => _startEdit(user),
              ),
            ) ?? const SizedBox.shrink()
          else ...[
            TextButton(
              onPressed: _cancelEdit,
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancel'),
            ),
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: HapaColors.ochre),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    style: TextButton.styleFrom(foregroundColor: HapaColors.ochre),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ],
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: HapaColors.ochre)),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load profile'),
              TextButton(
                onPressed: () => ref.read(userNotifierProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (user) => ListView(
          children: [
            _ProfileHeader(user: user),
            _StatsRow(user: user),
            const SizedBox(height: 12),
            if (_editing)
              _EditForm(
                user: user,
                nameCtrl: _nameCtrl,
                bioCtrl: _bioCtrl,
                cityCtrl: _cityCtrl,
                editUserType: _editUserType,
                editLanguage: _editLanguage,
                editTags: _editTags,
                onUserTypeChanged: (v) => setState(() => _editUserType = v),
                onLanguageChanged: (v) => setState(() => _editLanguage = v),
                onTagToggled: (tag) => setState(() {
                  if (_editTags.contains(tag)) {
                    _editTags.remove(tag);
                  } else {
                    _editTags.add(tag);
                  }
                }),
              )
            else
              _ProfileInfo(user: user),
            if (!_editing) _UserPostsSection(userId: user.id),
            if (!_editing) _SavedPostsSection(),
            const SizedBox(height: 12),
            if (user.userType == 'business_owner') _BusinessSection(),
            _SettingsSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Profile header ──────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerStatefulWidget {
  final CurrentUser user;
  const _ProfileHeader({required this.user});

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final client = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: file.name),
      });
      final res = await client.uploadFile('/v1/media', form);
      final url = res['url'] as String?;
      if (url != null && mounted) {
        await ref.read(userNotifierProvider.notifier).updateProfile(avatarUrl: url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update avatar. Try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          // Avatar with upload button
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: HapaColors.ochre.withValues(alpha: 0.12),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!) : null,
                  child: _uploadingAvatar
                      ? const CircularProgressIndicator(
                          color: HapaColors.ochre, strokeWidth: 2)
                      : user.avatarUrl == null
                          ? Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold,
                                color: HapaColors.ochre,
                              ),
                            )
                          : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: _uploadingAvatar ? Colors.grey : HapaColors.ochre,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: HapaColors.deep, fontFamily: 'Fraunces',
                  ),
                ),
                if (user.username != null && user.username!.isNotEmpty)
                  Text(
                    '@${user.username}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: [
                    if (user.isVerified) _Badge('✓ Verified', HapaColors.ochre),
                    _Badge(_userTypes[user.userType] ?? user.userType, HapaColors.sage),
                    if (user.tier == 'pro') _Badge('Pro', const Color(0xFF6366F1)),
                    if (user.tier == 'verified_local')
                      _Badge('Local Expert', HapaColors.ochre),
                  ],
                ),
                if (user.currentCity != null && user.currentCity!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 11, color: HapaColors.ochre),
                        const SizedBox(width: 2),
                        Text(
                          user.currentCity!,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Stats row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final CurrentUser user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          _Stat(count: user.trustScore, label: 'Trust Score'),
          _Divider(),
          _Stat(count: user.followerCount, label: 'Followers'),
          _Divider(),
          _Stat(count: user.followingCount, label: 'Following'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int count;
  final String label;
  const _Stat({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: HapaColors.deep,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: const Color(0xFFF0EBE0));
  }
}

// ── Profile info (view mode) ────────────────────────────────────────────────

class _ProfileInfo extends StatelessWidget {
  final CurrentUser user;
  const _ProfileInfo({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('ABOUT'),
          const SizedBox(height: 10),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            Text(
              user.bio!,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              'No bio yet. Tap Edit to add one.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
          ],
          _InfoRow(Icons.home_outlined, 'Home city', user.homeCity ?? '—'),
          _InfoRow(Icons.language, 'Language', _languages[user.language] ?? user.language),
          if (user.interestTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel('INTERESTS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: user.interestTags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBE0),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(
                    fontSize: 12, color: HapaColors.muted, fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade400,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HapaColors.deep),
          ),
        ],
      ),
    );
  }
}

// ── Edit form ───────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final CurrentUser user;
  final TextEditingController nameCtrl;
  final TextEditingController bioCtrl;
  final TextEditingController cityCtrl;
  final String? editUserType;
  final String? editLanguage;
  final List<String> editTags;
  final ValueChanged<String?> onUserTypeChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String> onTagToggled;

  const _EditForm({
    required this.user,
    required this.nameCtrl,
    required this.bioCtrl,
    required this.cityCtrl,
    required this.editUserType,
    required this.editLanguage,
    required this.editTags,
    required this.onUserTypeChanged,
    required this.onLanguageChanged,
    required this.onTagToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('EDIT PROFILE'),
          const SizedBox(height: 14),

          _FieldLabel('Display Name'),
          _Field(controller: nameCtrl, hint: 'Your name', maxLines: 1),
          const SizedBox(height: 12),

          _FieldLabel('Bio'),
          _Field(controller: bioCtrl, hint: 'Tell people about yourself...', maxLines: 3),
          const SizedBox(height: 12),

          _FieldLabel('Home City'),
          _Field(controller: cityCtrl, hint: 'Kampala, Nairobi...', maxLines: 1),
          const SizedBox(height: 12),

          _FieldLabel('I am a'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _userTypes.entries.map((e) {
              final active = editUserType == e.key;
              return GestureDetector(
                onTap: () => onUserTypeChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? HapaColors.ochre : const Color(0xFFF0EBE0),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: active ? HapaColors.ochre : const Color(0xFFE0D8C8),
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : HapaColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          _FieldLabel('Language'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languages.entries.map((e) {
              final active = editLanguage == e.key;
              return GestureDetector(
                onTap: () => onLanguageChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? HapaColors.deep : const Color(0xFFF0EBE0),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: active ? HapaColors.deep : const Color(0xFFE0D8C8),
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : HapaColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          _FieldLabel('Interests'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interestOptions.map((tag) {
              final active = editTags.contains(tag);
              return GestureDetector(
                onTap: () => onTagToggled(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? HapaColors.ochre.withValues(alpha: 0.1) : const Color(0xFFF0EBE0),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: active ? HapaColors.ochre : const Color(0xFFE0D8C8),
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: active ? HapaColors.ochre : HapaColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _Field({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: HapaColors.deep),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8F5F0),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFFE0D8C8)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFFE0D8C8)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: HapaColors.ochre),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── User posts section ──────────────────────────────────────────────────────

class _UserPostsSection extends ConsumerWidget {
  final String userId;
  const _UserPostsSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userPostsProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            children: [
              Container(width: 3, height: 14, color: HapaColors.ochre),
              const SizedBox(width: 8),
              const Text(
                'My Posts',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HapaColors.deep,
                ),
              ),
              const Spacer(),
              if (state.posts.isNotEmpty)
                Text(
                  '${state.posts.length}${state.hasMore ? '+' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontFamily: 'JetBrainsMono',
                  ),
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
        else if (state.posts.isEmpty)
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              'No posts yet. Share what\'s happening near you!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...state.posts.map(
            (post) => PostCard(post: post)
                .animate()
                .fadeIn(duration: 200.ms),
          ),
      ],
    );
  }
}

// ── Saved posts section ─────────────────────────────────────────────────────

class _SavedPostsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedPostsProvider);

    if (!state.isLoading && state.posts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            children: [
              Container(width: 3, height: 14, color: HapaColors.deep),
              const SizedBox(width: 8),
              const Text(
                'Saved',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HapaColors.deep,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.bookmark_rounded, size: 14, color: HapaColors.deep.withValues(alpha: 0.5)),
              const Spacer(),
              if (state.posts.isNotEmpty)
                Text(
                  '${state.posts.length}${state.hasMore ? '+' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
            ],
          ),
        ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: HapaColors.deep, strokeWidth: 2),
            ),
          )
        else
          ...state.posts.map(
            (post) => PostCard(post: post)
                .animate()
                .fadeIn(duration: 200.ms),
          ),
      ],
    );
  }
}

// ── Settings section ────────────────────────────────────────────────────────

class _BusinessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: _SectionLabel('BUSINESS'),
          ),
          const Divider(height: 1, color: Color(0xFFF5F0E8)),
          ListTile(
            leading: Container(
              width: 34,
              height: 34,
              color: HapaColors.ochre.withValues(alpha: 0.10),
              child: const Icon(Icons.store_outlined, size: 18, color: HapaColors.ochre),
            ),
            title: const Text(
              'My Businesses',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: HapaColors.deep),
            ),
            subtitle: Text(
              'Manage listings and launch Boosts',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            trailing: const Icon(Icons.chevron_right, color: HapaColors.muted),
            onTap: () => context.push('/business/dashboard'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: _SectionLabel('SETTINGS'),
          ),
          const Divider(height: 1, color: Color(0xFFF5F0E8)),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () {},
          ),
          const Divider(height: 1, color: Color(0xFFF5F0E8), indent: 56),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Privacy',
            onTap: () {},
          ),
          const Divider(height: 1, color: Color(0xFFF5F0E8), indent: 56),
          _SettingsTile(
            icon: Icons.help_outline,
            label: 'Help & feedback',
            onTap: () {},
          ),
          const Divider(height: 1, color: Color(0xFFF5F0E8), indent: 56),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'About Hapa',
            onTap: () {},
          ),
          const Divider(height: 1, color: Color(0xFFF0EBE0)),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Sign out',
            color: const Color(0xFFEF4444),
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You\'ll need your phone number to sign back in.'),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(apiClientProvider).clearTokens();
              if (context.mounted) context.go('/auth/phone');
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? HapaColors.deep;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: c),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: c, fontWeight: FontWeight.w500),
      ),
      trailing: color == null
          ? Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300)
          : null,
      onTap: onTap,
    );
  }
}
