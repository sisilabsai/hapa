import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

// ── Public helper ─────────────────────────────────────────────────────────────

bool isVideoUrl(String url) {
  final path = url.toLowerCase().split('?').first;
  return path.endsWith('.mp4') || path.endsWith('.mov') ||
      path.endsWith('.avi') || path.endsWith('.webm') ||
      path.endsWith('.mkv') || path.endsWith('.3gp');
}

bool isVideoFile(String filePath) {
  final ext = filePath.toLowerCase().split('.').last;
  return ['mp4', 'mov', 'avi', 'webm', 'mkv', '3gp'].contains(ext);
}

// ── HapaVideoPlayer ───────────────────────────────────────────────────────────

class HapaVideoPlayer extends StatefulWidget {
  final String? networkUrl;
  final File? file;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final double aspectRatio;

  const HapaVideoPlayer({
    super.key,
    this.networkUrl,
    this.file,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = true,
    this.aspectRatio = 16 / 9,
  }) : assert(networkUrl != null || file != null, 'provide networkUrl or file');

  @override
  State<HapaVideoPlayer> createState() => _HapaVideoPlayerState();
}

class _HapaVideoPlayerState extends State<HapaVideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _ctrl = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.networkUrl!));

    _ctrl.addListener(_onPlayerUpdate);

    try {
      await _ctrl.initialize();
      _ctrl.setLooping(widget.looping);
      if (widget.autoPlay) _ctrl.play();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ctrl.removeListener(_onPlayerUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl.value.isPlaying) {
      _ctrl.pause();
      _showControls = true;
      _hideTimer?.cancel();
    } else {
      _ctrl.play();
      _resetHideTimer();
    }
    setState(() {});
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _ctrl.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTap() {
    if (!_showControls) {
      _resetHideTimer();
    } else {
      _togglePlay();
    }
  }

  void _seekTo(double ratio) {
    final duration = _ctrl.value.duration;
    _ctrl.seekTo(duration * ratio);
    _resetHideTimer();
  }

  void _openFullscreen() {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _FullscreenPlayer(ctrl: _ctrl),
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: _hasError
          ? _ErrorView()
          : !_initialized
              ? _LoadingView()
              : GestureDetector(
                  onTap: _onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video
                      Center(
                        child: AspectRatio(
                          aspectRatio: _ctrl.value.aspectRatio,
                          child: VideoPlayer(_ctrl),
                        ),
                      ),

                      // Controls overlay
                      AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: _ControlsOverlay(
                          ctrl: _ctrl,
                          onPlayPause: _togglePlay,
                          onSeek: _seekTo,
                          onFullscreen: widget.showControls ? _openFullscreen : null,
                        ),
                      ),

                      // Center play/pause button
                      if (_showControls)
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlay,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _ctrl.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),

                      // Buffer indicator
                      if (_ctrl.value.isBuffering)
                        const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

// ── Controls overlay ──────────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController ctrl;
  final VoidCallback onPlayPause;
  final void Function(double ratio) onSeek;
  final VoidCallback? onFullscreen;

  const _ControlsOverlay({
    required this.ctrl,
    required this.onPlayPause,
    required this.onSeek,
    this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final position = ctrl.value.position;
    final duration = ctrl.value.duration;
    final ratio = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.transparent, Color(0xCC000000)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seek bar
              _SeekBar(ratio: ratio, onSeek: onSeek),
              const SizedBox(height: 4),
              // Time + fullscreen
              Row(
                children: [
                  Text(
                    _fmtTime(position),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  Text(
                    ' / ${_fmtTime(duration)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  const Spacer(),
                  if (onFullscreen != null)
                    GestureDetector(
                      onTap: onFullscreen,
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 22,
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

  String _fmtTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Seek bar ──────────────────────────────────────────────────────────────────

class _SeekBar extends StatefulWidget {
  final double ratio;
  final void Function(double) onSeek;
  const _SeekBar({required this.ratio, required this.onSeek});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = _dragging ?? widget.ratio;
    return LayoutBuilder(
      builder: (_, constraints) => GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _dragging = widget.ratio),
        onHorizontalDragUpdate: (d) {
          final r = ((_dragging ?? 0) + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
          setState(() => _dragging = r);
        },
        onHorizontalDragEnd: (_) {
          if (_dragging != null) {
            widget.onSeek(_dragging!);
            setState(() => _dragging = null);
          }
        },
        onTapUp: (d) {
          final r = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
          widget.onSeek(r);
        },
        child: SizedBox(
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Track
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              // Thumb
              Positioned(
                left: value * (constraints.maxWidth - 12),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
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

// ── Fullscreen player ─────────────────────────────────────────────────────────

class _FullscreenPlayer extends StatefulWidget {
  final VideoPlayerController ctrl;
  const _FullscreenPlayer({required this.ctrl});

  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    widget.ctrl.addListener(_onUpdate);
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.ctrl.removeListener(_onUpdate);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _onUpdate() { if (mounted) setState(() {}); }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.ctrl.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlay() {
    if (widget.ctrl.value.isPlaying) {
      widget.ctrl.pause();
      setState(() => _showControls = true);
      _hideTimer?.cancel();
    } else {
      widget.ctrl.play();
      _resetHideTimer();
    }
  }

  void _seekTo(double ratio) {
    widget.ctrl.seekTo(widget.ctrl.value.duration * ratio);
    _resetHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (!_showControls) {
            _resetHideTimer();
          } else {
            _togglePlay();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.ctrl.value.aspectRatio,
                child: VideoPlayer(widget.ctrl),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                children: [
                  _ControlsOverlay(
                    ctrl: widget.ctrl,
                    onPlayPause: _togglePlay,
                    onSeek: _seekTo,
                    onFullscreen: null,
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showControls)
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.ctrl.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            if (widget.ctrl.value.isBuffering)
              const Center(
                child: SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Loading / Error views ─────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(color: Colors.white60, strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 40),
          const SizedBox(height: 10),
          Text(
            'Video unavailable',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
