import 'dart:math' as math;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:humanai/models/game_item.dart';
import 'package:humanai/utils/app_colors.dart';
import 'package:video_player/video_player.dart';

/// The big card in the middle of the screen: shows the image, video or music
/// of the current round and, once answered, the verdict stamp.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.item,
    required this.revealed,
    required this.wasCorrect,
    required this.videoController,
    required this.audioPlaying,
    required this.audioReady,
    required this.audioPosition,
    required this.audioDuration,
    required this.onToggleAudio,
    required this.onSeekAudio,
    required this.onToggleVideo,
    required this.onMediaError,
    required this.onMediaLoaded,
    required this.onZoom,
  });

  final GameItem item;
  final bool revealed;
  final bool wasCorrect;
  final VideoPlayerController? videoController;
  final bool audioPlaying;
  final bool audioReady;
  final Duration audioPosition;
  final Duration audioDuration;
  final VoidCallback onToggleAudio;
  final ValueChanged<Duration> onSeekAudio;
  final VoidCallback onToggleVideo;
  final VoidCallback onMediaError;

  /// An image finished loading; videos and music report this themselves.
  final VoidCallback onMediaLoaded;
  final VoidCallback onZoom;

  @override
  Widget build(BuildContext context) {
    final verdictColor = wasCorrect ? AppColors.correct : AppColors.wrong;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: revealed ? verdictColor : AppColors.outline, width: revealed ? 3 : 1),
        boxShadow: [
          BoxShadow(
            color: revealed ? verdictColor.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35),
            blurRadius: revealed ? 28 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          fit: StackFit.expand,
          children: [
            switch (item.type) {
              MediaType.image => _ImageView(item: item, onError: onMediaError, onLoaded: onMediaLoaded, onZoom: onZoom),
              MediaType.video => _VideoView(controller: videoController, onToggle: onToggleVideo),
              MediaType.music => _MusicView(
                  item: item,
                  revealed: revealed,
                  playing: audioPlaying,
                  ready: audioReady,
                  position: audioPosition,
                  duration: audioDuration,
                  onToggle: onToggleAudio,
                  onSeek: onSeekAudio,
                ),
            },
            Positioned(top: 12, left: 12, child: _TypeBadge(type: item.type)),
            if (item.type == MediaType.image)
              Positioned(
                top: 12,
                right: 12,
                child: _RoundIconButton(icon: Icons.zoom_out_map_rounded, tooltip: 'Zoom in', onTap: onZoom),
              ),
            if (revealed)
              // Images and videos get the stamp at the bottom; for music it sits in the
              // top corner so it covers neither the equalizer nor the revealed title.
              switch (item.type) {
                MediaType.image => Positioned(left: 0, right: 0, bottom: 20, child: Center(child: _VerdictStamp(isAi: item.isAi))),
                MediaType.video => Positioned(left: 0, right: 0, bottom: 76, child: Center(child: _VerdictStamp(isAi: item.isAi))),
                MediaType.music => Positioned(top: 10, right: 10, child: _VerdictStamp(isAi: item.isAi)),
              },
            // The panel below the card (with the credit) only opens after a
            // miss, but CC licences need the author shown after a hit as well.
            if (revealed && wasCorrect && item.credit != null)
              Positioned(left: 12, right: 12, top: 62, child: _CreditLabel(credit: item.credit!)),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final MediaType type;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (type) {
      MediaType.image => (Icons.image_rounded, 'IMAGE'),
      MediaType.video => (Icons.videocam_rounded, 'VIDEO'),
      MediaType.music => (Icons.music_note_rounded, 'MUSIC'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: IconButton(icon: Icon(icon, color: Colors.white, size: 20), tooltip: tooltip, onPressed: onTap),
    );
  }
}

class _CreditLabel extends StatelessWidget {
  const _CreditLabel({required this.credit});
  final String credit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)),
        child: Text(credit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }
}

class _VerdictStamp extends StatelessWidget {
  const _VerdictStamp({required this.isAi});
  final bool isAi;

  @override
  Widget build(BuildContext context) {
    final color = isAi ? AppColors.ai : AppColors.human;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(scale: 0.6 + 0.4 * t, child: Opacity(opacity: t.clamp(0, 1), child: child)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isAi ? Icons.smart_toy_rounded : Icons.person_rounded, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              isAi ? 'AI-GENERATED' : 'HUMAN-MADE',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageView extends StatelessWidget {
  const _ImageView({required this.item, required this.onError, required this.onLoaded, required this.onZoom});
  final GameItem item;
  final VoidCallback onError;
  final VoidCallback onLoaded;
  final VoidCallback onZoom;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onZoom,
      child: CachedNetworkImage(
        imageUrl: item.url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        imageBuilder: (context, image) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onLoaded());
          return Image(image: image, fit: BoxFit.cover);
        },
        placeholder: (context, url) => const _Loading(),
        errorWidget: (context, url, error) {
          // A dead link should never cost the player a life: move on.
          WidgetsBinding.instance.addPostFrameCallback((_) => onError());
          return const _Loading();
        },
      ),
    );
  }
}

class _VideoView extends StatelessWidget {
  const _VideoView({required this.controller, required this.onToggle});
  final VideoPlayerController? controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null || !c.value.isInitialized) return const _Loading();
    return GestureDetector(
      onTap: onToggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, value, _) => Stack(
              fit: StackFit.expand,
              children: [
                if (!value.isPlaying)
                  Center(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                      padding: const EdgeInsets.all(14),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _ProgressPill(
                    child: ProgressBar(
                      progress: value.position,
                      total: value.duration,
                      onSeek: c.seekTo,
                      barHeight: 5,
                      thumbRadius: 7,
                      baseBarColor: Colors.white24,
                      progressBarColor: Colors.white,
                      thumbColor: Colors.white,
                      timeLabelLocation: TimeLabelLocation.sides,
                      timeLabelTextStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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

class _MusicView extends StatelessWidget {
  const _MusicView({
    required this.item,
    required this.revealed,
    required this.playing,
    required this.ready,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onSeek,
  });

  final GameItem item;
  final bool revealed;
  final bool playing;
  final bool ready;
  final Duration position;
  final Duration duration;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final title = [item.title, item.artist].whereType<String>().join(' — ');
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [Color(0xFF3B2F7A), Color(0xFF141A38)]),
          ),
        ),
        // The cover and title would give the answer away, so they only appear after it.
        if (revealed && item.cover != null)
          Opacity(
            opacity: 0.35,
            child: CachedNetworkImage(imageUrl: item.cover!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox.shrink()),
          ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 90, child: Equalizer(active: playing && ready)),
            const SizedBox(height: 20),
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 6,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onToggle,
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: !ready && playing
                      ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.background))
                      : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 46, color: AppColors.background),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  revealed && title.isNotEmpty ? title : 'Listen closely…',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: revealed ? Colors.white : AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _ProgressPill(
            child: ProgressBar(
              progress: position > duration ? duration : position,
              total: duration,
              onSeek: onSeek,
              barHeight: 5,
              thumbRadius: 7,
              baseBarColor: Colors.white24,
              progressBarColor: Colors.white,
              thumbColor: Colors.white,
              timeLabelLocation: TimeLabelLocation.sides,
              timeLabelTextStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(18)),
      child: child,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.textMuted))),
    );
  }
}

/// Animated bars that move while music is playing.
class Equalizer extends StatefulWidget {
  const Equalizer({super.key, required this.active});
  final bool active;

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(Equalizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) _controller.repeat();
    if (!widget.active && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _EqualizerPainter(_controller, active: widget.active), size: const Size(220, 90));
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter(this.animation, {required this.active}) : super(repaint: animation);
  final Animation<double> animation;
  final bool active;

  static const _bars = 17;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * 2 * math.pi;
    final slot = size.width / _bars;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [AppColors.human, AppColors.ai],
      ).createShader(Offset.zero & size);
    for (var i = 0; i < _bars; i++) {
      // Several sine waves per bar so the movement does not look mechanical.
      final wave = (math.sin(t * 3 + i * 0.9) + math.sin(t * 5 + i * 1.7) + math.sin(t * 2 + i * 0.4)) / 3;
      final level = active ? 0.18 + 0.82 * (0.5 + 0.5 * wave).abs() : 0.12;
      final h = size.height * level;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * slot + slot * 0.2, (size.height - h) / 2, slot * 0.6, h),
        Radius.circular(slot * 0.3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter oldDelegate) => oldDelegate.active != active;
}

/// Full-screen, pinch-to-zoom view of an image so details can be inspected.
class ZoomView extends StatelessWidget {
  const ZoomView({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 6,
                child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: _RoundIconButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: () => Navigator.of(context).pop()),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Text('Pinch to zoom', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
