import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart'; // Make sure you have this dependency

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerItem({required this.videoUrl, Key? key}) : super(key: key);

  @override
  _VideoPlayerItemState createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isPlaying = false;
  bool _isBuffering = false; // Optional: track buffering state
  String? _error; // To store potential errors

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    // Dispose previous controller if exists (e.g., if URL changes dynamically, though less likely here)
    _controller?.dispose();
    _controller = null;
    _initializeVideoPlayerFuture = null;
    _isPlaying = false;
    _isBuffering = false;
    _error = null;

    if (widget.videoUrl.isEmpty) {
      setState(() {
        _error = "Video URL is empty.";
      });
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      // Add listener for state changes (playing, buffering, errors)
      _controller!.addListener(() {
        if (!mounted) return; // Check if the widget is still in the tree

        final bool isPlaying = _controller!.value.isPlaying;
        final bool isBuffering = _controller!.value.isBuffering;
        final bool hasError = _controller!.value.hasError;

        // Update state only if it changed to avoid unnecessary rebuilds
        if (isPlaying != _isPlaying || isBuffering != _isBuffering || hasError) {
          setState(() {
            _isPlaying = isPlaying;
            _isBuffering = isBuffering;
            if (hasError) {
              _error = _controller!.value.errorDescription ?? "An unknown video error occurred.";
              print("Video Error: $_error");
            }
          });
        }
      });

      _initializeVideoPlayerFuture = _controller!.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        if (mounted) {
          // Check again if mounted after async operation
          setState(() {});
        }
      }).catchError((error) {
        print("Error initializing video player: $error");
        if (mounted) {
          setState(() {
            _error = "Could not load video: $error";
          });
        }
      });
    } catch (e) {
      print("Error creating video controller (Invalid URL?): $e");
      setState(() {
        _error = "Invalid video URL or format.";
      });
    }
  }

  @override
  void dispose() {
    // Ensure disposing the controller when the widget is disposed.
    _controller?.removeListener(() {}); // Remove listener first
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false; // Explicitly set state
      } else {
        // If playback finished, seek to beginning before playing
        if (_controller!.value.position >= _controller!.value.duration) {
          _controller!.seekTo(Duration.zero);
        }
        _controller!.play();
        _isPlaying = true; // Explicitly set state
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        // Handle explicit errors first
        if (_error != null) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: $_error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          ));
        }
        // Handle future-based errors
        if (snapshot.hasError) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading video: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          ));
        }
        // Handle loading state
        if (snapshot.connectionState != ConnectionState.done || _controller == null || !_controller!.value.isInitialized) {
          // Show a loading indicator while waiting for initialization
          return const Center(child: CircularProgressIndicator());
        }

        // If initialization is done and no errors, show the player
        return Stack(
          alignment: Alignment.center,
          children: [
            // Video Player Widget
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),

            // Buffering Indicator (optional)
            if (_isBuffering) const Center(child: CircularProgressIndicator()),

            // Play/Pause Button Overlay
            // Only show button if not buffering and video is initialized
            if (!_isBuffering)
              GestureDetector(
                // Use GestureDetector to make the whole area tappable if desired, or just keep IconButton
                onTap: _togglePlayPause,
                child: Container(
                  // Optional: Add a semi-transparent background to make tap area clearer
                  color: Colors.transparent, // Or Colors.black.withOpacity(0.1)
                  child: Center(
                    child: IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        size: 60.0,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ),
                ),
              ),

            // Progress Bar at the bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                // Use ValueListenableBuilder to update progress without rebuilding the whole stack
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller!,
                  builder: (context, value, child) {
                    return ProgressBar(
                      progress: value.position,
                      buffered: value.buffered.isNotEmpty ? value.buffered.last.end : Duration.zero, // Show buffered position
                      total: value.duration,
                      onSeek: (duration) {
                        _controller!.seekTo(duration);
                      },
                      barHeight: 8,
                      baseBarColor: Colors.grey[600],
                      progressBarColor: Theme.of(context).colorScheme.primary, // Use theme color
                      bufferedBarColor: Colors.white.withOpacity(0.4), // Lighter color for buffer
                      thumbColor: Theme.of(context).colorScheme.primary,
                      timeLabelTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      timeLabelLocation: TimeLabelLocation.below, // Adjust label location if needed
                      timeLabelPadding: 4.0,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
