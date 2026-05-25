import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../features/feed/domain/feed_repository.dart';
import '../../../../features/feed/presentation/providers/feed_providers.dart';
import '../../../../shared/widgets/hapa_video_player.dart';

// ── Post type config ──────────────────────────────────────────────────────────

const _postTypes = [
  _PostType('moment',       'Moment',  Icons.photo_camera_outlined,  HapaColors.ochre,      'What\'s happening right now?'),
  _PostType('tip',          'Tip',     Icons.lightbulb_outline,      Color(0xFF10B981),     'Share a useful local tip'),
  _PostType('review',       'Review',  Icons.star_outline,           Color(0xFF6366F1),     'Review a place or experience'),
  _PostType('flash',        'Flash',   Icons.bolt_outlined,          Color(0xFFEF4444),     'Time-sensitive alert (1–24h)'),
  _PostType('guide',        'Guide',   Icons.map_outlined,           HapaColors.ochre,      'Share local knowledge'),
  _PostType('cultural_note','Culture', Icons.language,               HapaColors.sage,       'Share a cultural insight'),
];

const _moods = [
  ('🔥', 'Trending'), ('😄', 'Fun'),        ('🙏', 'Grateful'),   ('🎉', 'Celebrating'),
  ('😤', 'Rant'),     ('💡', 'Insightful'), ('❤️', 'Loving it'),  ('😮', 'Surprising'),
];

const _tagOptions = [
  'food','nightlife','culture','sports','events','shopping',
  'travel','nature','music','art','tech','health','community','transport',
];

const _flashDurations = [
  (label: '1h',  hours: 1),  (label: '3h',  hours: 3),
  (label: '6h',  hours: 6),  (label: '12h', hours: 12),
  (label: '24h', hours: 24),
];

class _PostType {
  final String key, label, hint;
  final IconData icon;
  final Color color;
  const _PostType(this.key, this.label, this.icon, this.color, this.hint);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CreatePostScreen extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final (double, double)? feedCoords;

  const CreatePostScreen({super.key, this.initialLat, this.initialLng, this.feedCoords});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  String _selectedType = 'moment';
  String? _selectedMood;
  final _contentCtrl = TextEditingController();
  final _contentFocus = FocusNode();
  List<String> _selectedTags = [];
  int _flashHours = 3;
  bool _isPublic = true;
  bool _posting = false;
  double? _lat;
  double? _lng;
  String _locationLabel = 'Getting location…';
  final List<_MediaItem> _media = [];
  bool _uploadingMedia = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
    _detectLocation();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    if (_lat != null && _lng != null) {
      setState(() => _locationLabel = 'Near you');
      return;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationLabel = 'Location unavailable');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) setState(() {
        _lat = pos.latitude; _lng = pos.longitude; _locationLabel = 'Near you';
      });
    } catch (_) {
      if (mounted) setState(() => _locationLabel = 'Location unavailable');
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool video = false}) async {
    if (_media.length >= 6) { _showSnack('Maximum 6 media items', isError: true); return; }
    final picker = ImagePicker();

    if (!video && source == ImageSource.gallery) {
      final files = await picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;
      setState(() {
        for (final f in files.take(6 - _media.length)) _media.add(_MediaItem(f));
      });
    } else {
      final file = video
          ? await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 3))
          : await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      setState(() => _media.add(_MediaItem(file)));
    }
    _uploadPending();
  }

  Future<void> _uploadPending() async {
    final pending = _media.where((m) => m.url == null && !m.uploading && !m.error).toList();
    if (pending.isEmpty) return;
    setState(() => _uploadingMedia = true);
    final client = ref.read(apiClientProvider);

    for (final item in pending) {
      item.uploading = true;
      item.progress = 0.0;
      setState(() {});
      try {
        final fileSize = await File(item.file.path).length();
        item.bytesTotal = fileSize;

        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(item.file.path, filename: item.file.name),
        });
        final res = await client.uploadFile('/v1/media', form,
          onSendProgress: (sent, total) {
            if (!mounted) return;
            setState(() {
              item.bytesSent = sent;
              item.bytesTotal = total > 0 ? total : fileSize;
              item.progress = total > 0 ? sent / total : 0.0;
            });
          },
        );
        item.url = res['url'] as String?;
        item.progress = 1.0;
      } catch (e) {
        item.error = true;
        item.progress = 0.0;
      } finally {
        item.uploading = false;
      }
      if (mounted) setState(() {});
    }

    if (mounted) {
      setState(() => _uploadingMedia = false);
      final allDone = _media.every((m) => m.url != null || m.error);
      final hasVideo = _media.any((m) => m.isVideo && m.url != null);
      if (allDone && hasVideo) _showUploadCompleteNotification();
    }
  }

  void _showUploadCompleteNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: _UploadCompleteToast(),
      ),
    );
  }

  _PostType get _currentType => _postTypes.firstWhere((t) => t.key == _selectedType);

  bool get _canPost =>
      _contentCtrl.text.trim().length >= 3 &&
      _lat != null && !_posting && !_uploadingMedia &&
      _media.every((m) => m.url != null || m.error);

  Future<void> _post() async {
    if (!_canPost) return;
    HapticFeedback.mediumImpact();
    setState(() => _posting = true);

    try {
      final post = await ref.read(feedRepositoryProvider).createPost({
        'post_type': _selectedType,
        'content': _contentCtrl.text.trim(),
        'media_urls': _media.where((m) => m.url != null).map((m) => m.url!).toList(),
        'lat': _lat,
        'lng': _lng,
        'interest_tags': _selectedTags,
        if (_selectedMood != null) 'mood': _selectedMood,
        if (_selectedType == 'flash')
          'expires_at': DateTime.now().add(Duration(hours: _flashHours)).toUtc().toIso8601String(),
      });

      // Refresh feed and prepend post to user's own posts so it's immediately visible
      if (widget.feedCoords != null) {
        ref.read(feedNotifierProvider(widget.feedCoords!).notifier).refresh();
      }
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(userPostsProvider(user.id).notifier).prepend(post);
      }

      if (mounted) {
        // Navigate directly to the new post so the user can interact with it
        context.pushReplacement('/posts/${post.id}', extra: post);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Posted! Your post is live.'),
          backgroundColor: HapaColors.sage,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        _showSnack('Could not post: ${e.toString().split(': ').last}', isError: true);
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFEF4444) : HapaColors.sage,
        behavior: SnackBarBehavior.floating,
      ));

  void _showMediaPicker({bool video = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: HapaColors.ochre),
            title: Text(video ? 'Pick video from gallery' : 'Pick from gallery'),
            onTap: () { Navigator.pop(context); _pickMedia(ImageSource.gallery, video: video); },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: HapaColors.ochre),
            title: Text(video ? 'Record video' : 'Take a photo'),
            onTap: () { Navigator.pop(context); _pickMedia(ImageSource.camera, video: video); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final type = _currentType;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: const Text('New Post',
            style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _preview = !_preview),
            icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined,
                size: 16, color: HapaColors.muted),
            label: Text(_preview ? 'Edit' : 'Preview',
                style: const TextStyle(color: HapaColors.muted, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: _posting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: HapaColors.ochre))
                : FilledButton(
                    onPressed: _canPost ? _post : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: type.color,
                      disabledBackgroundColor: Colors.grey.shade200,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    ),
                    child: const Text('Post',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _preview
              ? _PreviewPane(type: type, content: _contentCtrl.text, media: _media,
                  user: user, locationLabel: _locationLabel, tags: _selectedTags, mood: _selectedMood)
              : _buildForm(type, user),
          if (_uploadingMedia)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _UploadProgressOverlay(media: _media),
            ),
        ],
      ),
      bottomNavigationBar: _buildToolbar(),
    );
  }

  Widget _buildForm(_PostType type, CurrentUser? user) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Post type selector
        _PostTypeBar(selected: _selectedType, onSelect: (k) => setState(() => _selectedType = k)),

        // Author + visibility
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: HapaColors.ochre.withValues(alpha: 0.12),
              backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
              child: user?.avatarUrl == null
                  ? Text((user?.displayName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: HapaColors.ochre, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.displayName ?? 'You',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Row(children: [
                const Icon(Icons.location_on, size: 10, color: HapaColors.ochre),
                const SizedBox(width: 2),
                Text(_locationLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
            ])),
            // Visibility pill
            GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _isPublic = !_isPublic); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isPublic ? const Color(0xFFEFF6FF) : const Color(0xFFF5F0FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _isPublic ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_isPublic ? Icons.public : Icons.lock_outline, size: 12,
                      color: _isPublic ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)),
                  const SizedBox(width: 4),
                  Text(_isPublic ? 'Public' : 'Followers',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: _isPublic ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6))),
                ]),
              ),
            ),
          ]),
        ),

        // Content input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Stack(alignment: Alignment.bottomRight, children: [
            TextField(
              controller: _contentCtrl,
              focusNode: _contentFocus,
              minLines: 4,
              maxLines: null,
              maxLength: 500,
              autofocus: true,
              style: const TextStyle(fontSize: 16, height: 1.55, color: HapaColors.deep),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: type.hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _CharCounter(count: _contentCtrl.text.length, max: 500),
            ),
          ]),
        ),

        // Media strip (always shown so user can add)
        const SizedBox(height: 6),
        _MediaStrip(
          media: _media,
          onAdd: _showMediaPicker,
          onRemove: (i) => setState(() => _media.removeAt(i)),
          uploading: _uploadingMedia,
        ),

        const Divider(height: 1, color: Color(0xFFF0EBE0)),

        // Mood
        _MoodBar(
          selected: _selectedMood,
          onSelect: (m) => setState(() => _selectedMood = _selectedMood == m ? null : m),
        ),

        const Divider(height: 1, color: Color(0xFFF0EBE0)),

        // Flash duration
        if (_selectedType == 'flash') ...[
          _FlashPicker(selected: _flashHours, onSelect: (h) => setState(() => _flashHours = h)),
          const Divider(height: 1, color: Color(0xFFF0EBE0)),
        ],

        // Tags
        _TagSelector(
          options: _tagOptions,
          selected: _selectedTags,
          typeColor: type.color,
          onToggle: (tag) => setState(() {
            if (_selectedTags.contains(tag)) _selectedTags.remove(tag);
            else if (_selectedTags.length < 5) _selectedTags.add(tag);
          }),
        ),

        const Divider(height: 1, color: Color(0xFFF0EBE0)),

        // Location
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Icon(_lat != null ? Icons.location_on : Icons.location_searching, size: 16,
                color: _lat != null ? HapaColors.ochre : Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(child: Text(
              _lat != null
                  ? '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
                  : 'Detecting location…',
              style: TextStyle(fontSize: 12,
                  color: _lat != null ? HapaColors.muted : Colors.grey.shade400),
            )),
            if (_lat == null)
              TextButton(onPressed: _detectLocation,
                  child: const Text('Retry', style: TextStyle(fontSize: 12))),
          ]),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildToolbar() {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0EBE0))),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: [
          _ToolbarBtn(Icons.photo_library_outlined, onTap: _showMediaPicker),
          _ToolbarBtn(Icons.camera_alt_outlined,
              onTap: () => _pickMedia(ImageSource.camera)),
          _ToolbarBtn(Icons.videocam_outlined,
              onTap: () => _showMediaPicker(video: true)),
          _ToolbarBtn(Icons.location_on_outlined,
              onTap: _detectLocation, active: _lat != null),
          const Spacer(),
        ]),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _MediaItem {
  final XFile file;
  String? url;
  bool uploading = false;
  bool error = false;
  double progress = 0.0; // 0.0–1.0 during upload
  int bytesSent = 0;
  int bytesTotal = 0;

  bool get isVideo => isVideoFile(file.path);

  _MediaItem(this.file);
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _PostTypeBar extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _PostTypeBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F5F0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text('POST TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
              color: Colors.grey.shade500, letterSpacing: 1.2)),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            itemCount: _postTypes.length,
            itemBuilder: (_, i) {
              final t = _postTypes[i];
              final active = selected == t.key;
              return GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); onSelect(t.key); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 76,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: active ? t.color.withValues(alpha: 0.09) : Colors.white,
                    border: Border.all(
                        color: active ? t.color : const Color(0xFFE0D8C8),
                        width: active ? 1.5 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(t.icon, size: 20, color: active ? t.color : Colors.grey.shade400),
                    const SizedBox(height: 3),
                    Text(t.label, style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: active ? t.color : Colors.grey.shade500)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  final List<_MediaItem> media;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final bool uploading;
  const _MediaStrip({required this.media, required this.onAdd,
      required this.onRemove, required this.uploading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        children: [
          if (media.length < 6)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 76,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5F0),
                  border: Border.all(color: const Color(0xFFE0D8C8), width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 22, color: Colors.grey.shade400),
                  const SizedBox(height: 4),
                  Text('Add media', style: TextStyle(fontSize: 9,
                      color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ...media.asMap().entries.map((e) {
            final idx = e.key; final item = e.value;
            return _MediaThumb(item: item, onRemove: () => onRemove(idx));
          }),
        ],
      ),
    );
  }
}

// ── Media thumbnail (image or video) ─────────────────────────────────────────

class _MediaThumb extends StatelessWidget {
  final _MediaItem item;
  final VoidCallback onRemove;
  const _MediaThumb({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 76,
          margin: const EdgeInsets.only(right: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
          child: item.isVideo ? _VideoThumb(item: item) : _ImageThumb(item: item),
        ),
        // Progress bar for uploading
        if (item.uploading)
          Positioned(
            bottom: 0, left: 0, right: 8,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
              child: LinearProgressIndicator(
                value: item.progress > 0 ? item.progress : null,
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(HapaColors.ochre),
              ),
            ),
          ),
        // Error overlay
        if (item.error)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(height: 2),
                const Text('Failed', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        // Done badge
        if (item.url != null)
          Positioned(
            top: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 8),
            ),
          ),
        // Remove button
        Positioned(
          top: 2, right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final _MediaItem item;
  const _ImageThumb({required this.item});
  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(item.file.path),
      fit: BoxFit.cover, width: 76, height: 80,
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final _MediaItem item;
  const _VideoThumb({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76, height: 80,
      decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.videocam_rounded, color: Colors.white54, size: 26),
            const SizedBox(height: 4),
            Text(
              item.isVideo ? 'Video' : 'Media',
              style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ]),
          if (!item.uploading && item.url == null && !item.error)
            const Positioned(
              bottom: 6, right: 6,
              child: Icon(Icons.upload_rounded, color: Colors.white30, size: 14),
            ),
          if (item.uploading && item.progress > 0)
            Positioned(
              bottom: 8,
              child: Text(
                '${(item.progress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Upload progress overlay ───────────────────────────────────────────────────

class _UploadProgressOverlay extends StatelessWidget {
  final List<_MediaItem> media;
  const _UploadProgressOverlay({required this.media});

  _MediaItem? get _activeVideo =>
      media.where((m) => m.isVideo && m.uploading).firstOrNull;

  _MediaItem? get _activeImage =>
      media.where((m) => !m.isVideo && m.uploading).firstOrNull;

  double get _overallProgress {
    final uploading = media.where((m) => m.uploading || m.url != null).toList();
    if (uploading.isEmpty) return 0;
    final sum = uploading.fold<double>(0, (a, m) => a + (m.url != null ? 1.0 : m.progress));
    return sum / uploading.length;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeVideo ?? _activeImage;
    if (active == null) return const SizedBox.shrink();

    final isVideo = active.isVideo;
    final progress = active.progress;
    final label = isVideo ? 'Uploading video' : 'Uploading image';
    final progressPct = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isVideo
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                        : HapaColors.ochre.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                    color: isVideo ? const Color(0xFFA78BFA) : HapaColors.ochre,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          if (progress > 0)
                            Text(
                              '$progressPct%',
                              style: TextStyle(
                                color: isVideo ? const Color(0xFFA78BFA) : HapaColors.ochre,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                fontFamily: 'JetBrainsMono',
                              ),
                            ),
                        ],
                      ),
                      if (active.bytesTotal > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_formatBytes(active.bytesSent)} / ${_formatBytes(active.bytesTotal)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(
                  isVideo ? const Color(0xFFA78BFA) : HapaColors.ochre,
                ),
              ),
            ),
            if (media.where((m) => m.uploading).length > 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${media.where((m) => m.url != null).length}/${media.length} done',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const Spacer(),
                  Text(
                    'Overall ${(_overallProgress * 100).toInt()}%',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Upload complete toast ─────────────────────────────────────────────────────

class _UploadCompleteToast extends StatelessWidget {
  const _UploadCompleteToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Video uploaded!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('Ready to post', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.videocam_rounded, color: Color(0xFF10B981), size: 20),
        ],
      ),
    );
  }
}

// ── MoodBar ───────────────────────────────────────────────────────────────────

class _MoodBar extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelect;
  const _MoodBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mood, size: 14, color: HapaColors.muted),
          const SizedBox(width: 6),
          Text('Vibe (optional)', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: _moods.map((m) {
            final active = selected == m.$1;
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); onSelect(m.$1); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? HapaColors.ochre.withValues(alpha: 0.12)
                      : const Color(0xFFF0EBE0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? HapaColors.ochre : Colors.transparent),
                ),
                child: Text('${m.$1} ${m.$2}', style: TextStyle(fontSize: 12,
                    color: active ? HapaColors.deep : Colors.grey.shade600,
                    fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _FlashPicker extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  const _FlashPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.timer_outlined, size: 14, color: Color(0xFFEF4444)),
          SizedBox(width: 6),
          Text('Expires in', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
        ]),
        const SizedBox(height: 8),
        Row(children: _flashDurations.map((d) {
          final active = selected == d.hours;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(d.hours),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFEF4444) : const Color(0xFFF0EBE0),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(d.label, style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : Colors.grey.shade600)),
              ),
            ),
          );
        }).toList()),
      ]),
    );
  }
}

class _TagSelector extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final Color typeColor;
  final void Function(String) onToggle;
  const _TagSelector({required this.options, required this.selected,
      required this.typeColor, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.tag, size: 14, color: HapaColors.muted),
          const SizedBox(width: 6),
          Text('Tags (optional, max 5)', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
          if (selected.isNotEmpty) ...[
            const Spacer(),
            Text('${selected.length}/5', style: TextStyle(fontSize: 11,
                color: typeColor, fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: options.map((tag) {
            final active = selected.contains(tag);
            final disabled = !active && selected.length >= 5;
            return GestureDetector(
              onTap: disabled ? null : () => onToggle(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? typeColor.withValues(alpha: 0.1)
                      : disabled ? const Color(0xFFF8F8F8) : const Color(0xFFF0EBE0),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: active ? typeColor : const Color(0xFFE0D8C8)),
                ),
                child: Text('#$tag', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: active ? typeColor
                        : disabled ? Colors.grey.shade300 : HapaColors.muted)),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _CharCounter extends StatelessWidget {
  final int count;
  final int max;
  const _CharCounter({required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    final ratio = count / max;
    final color = ratio > 0.9 ? const Color(0xFFEF4444)
        : ratio > 0.75 ? HapaColors.ochre : Colors.grey.shade300;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 20, height: 20,
        child: CircularProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          strokeWidth: 2.5,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(color),
        )),
      if (ratio > 0.75) ...[
        const SizedBox(width: 4),
        Text('${max - count}', style: TextStyle(fontSize: 11,
            color: color, fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _ToolbarBtn(this.icon, {required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 22,
            color: active ? HapaColors.ochre : Colors.grey.shade400),
      ),
    );
  }
}

// ── Preview pane ──────────────────────────────────────────────────────────────

class _PreviewPane extends StatelessWidget {
  final _PostType type;
  final String content;
  final List<_MediaItem> media;
  final CurrentUser? user;
  final String locationLabel;
  final List<String> tags;
  final String? mood;
  const _PreviewPane({required this.type, required this.content, required this.media,
      required this.user, required this.locationLabel, required this.tags, this.mood});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (media.isNotEmpty)
          SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: media.length,
              itemBuilder: (_, i) {
                final item = media[i];
                if (item.isVideo) {
                  return HapaVideoPlayer(
                    file: File(item.file.path),
                    aspectRatio: 16 / 9,
                    autoPlay: false,
                  );
                }
                return Image.file(File(item.file.path),
                    fit: BoxFit.cover, width: double.infinity);
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                color: type.color.withValues(alpha: 0.12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(type.icon, size: 11, color: type.color),
                  const SizedBox(width: 4),
                  Text(type.label.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: type.color, letterSpacing: 0.5)),
                ]),
              ),
              if (mood != null) ...[
                const SizedBox(width: 8),
                Text(mood!, style: const TextStyle(fontSize: 16)),
              ],
            ]),
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(radius: 16,
                backgroundColor: HapaColors.ochre.withValues(alpha: 0.12),
                backgroundImage: user?.avatarUrl != null
                    ? NetworkImage(user!.avatarUrl!) : null,
                child: user?.avatarUrl == null
                    ? Text((user?.displayName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: HapaColors.ochre,
                            fontWeight: FontWeight.bold, fontSize: 12))
                    : null),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.displayName ?? 'You',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Row(children: [
                  const Icon(Icons.location_on, size: 10, color: HapaColors.ochre),
                  const SizedBox(width: 2),
                  Text(locationLabel,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ]),
              ]),
            ]),
            const SizedBox(height: 12),
            Text(content.isEmpty ? '(no text yet)' : content,
                style: TextStyle(fontSize: 15, height: 1.5,
                    color: content.isEmpty ? Colors.grey.shade400 : HapaColors.deep)),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 4,
                  children: tags.map((t) => Text('#$t',
                      style: TextStyle(fontSize: 12, color: type.color,
                          fontWeight: FontWeight.w600))).toList()),
            ],
          ]),
        ),
      ]),
    );
  }
}
