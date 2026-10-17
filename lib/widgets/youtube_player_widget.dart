import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Fullscreen-safe YouTube player.
///
/// Fullscreen locks to landscape only. Portrait is restored only when the user
/// exits fullscreen or closes the player — not during the rotate transition.
class YoutubePlayerWidget extends StatefulWidget {
  final String videoId;
  final String videoTitle;

  const YoutubePlayerWidget({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  /// Opens the player as a full route (preferred over a dialog for fullscreen).
  static Future<void> open(
    BuildContext context, {
    required String videoId,
    required String videoTitle,
  }) {
    if (videoId.trim().isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => YoutubePlayerWidget(
          videoId: videoId,
          videoTitle: videoTitle,
        ),
      ),
    );
  }

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  late final YoutubePlayerController _controller;
  bool _isFullScreen = false;

  /// True while the user has requested fullscreen. Used to ignore the package's
  /// premature "exit fullscreen" when metrics are still portrait mid-rotation.
  bool _userWantsFullscreen = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: false,
      ),
    )..addListener(_onPlayerValue);
  }

  Future<void> _lockLandscape() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreAppOrientation() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  void _onPlayerValue() {
    if (!mounted) return;

    final isFs = _controller.value.isFullScreen;
    final isPortrait =
        MediaQuery.maybeOf(context)?.orientation == Orientation.portrait;

    // Package clears isFullScreen when physical size is still portrait during
    // the rotate-to-landscape transition — push it back into fullscreen.
    if (!isFs && _userWantsFullscreen && isPortrait) {
      _lockLandscape();
      _controller.updateValue(
        _controller.value.copyWith(isFullScreen: true),
      );
      if (!_isFullScreen) {
        setState(() => _isFullScreen = true);
      }
      return;
    }

    if (isFs == _isFullScreen) return;

    setState(() => _isFullScreen = isFs);

    if (isFs) {
      _userWantsFullscreen = true;
      _lockLandscape();
    } else {
      _userWantsFullscreen = false;
      _restoreAppOrientation();
    }
  }

  Future<void> _close() async {
    _userWantsFullscreen = false;
    try {
      if (_controller.value.isFullScreen) {
        _controller.toggleFullScreenMode();
      }
    } catch (_) {}
    await _restoreAppOrientation();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerValue);
    _controller.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        _userWantsFullscreen = true;
        _lockLandscape();
        if (mounted && !_isFullScreen) {
          setState(() => _isFullScreen = true);
        }
      },
      onExitFullScreen: () {
        final isPortrait =
            MediaQuery.maybeOf(context)?.orientation == Orientation.portrait;

        // Ignore premature exit callbacks while rotating into landscape.
        if (_userWantsFullscreen && isPortrait) {
          _lockLandscape();
          if (!_controller.value.isFullScreen) {
            _controller.updateValue(
              _controller.value.copyWith(isFullScreen: true),
            );
          }
          if (mounted && !_isFullScreen) {
            setState(() => _isFullScreen = true);
          }
          return;
        }

        _userWantsFullscreen = false;
        _restoreAppOrientation();
        if (mounted && _isFullScreen) {
          setState(() => _isFullScreen = false);
        }
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF2B6F71),
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF2B6F71),
          handleColor: Color(0xFF2B6F71),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white70,
        ),
        bottomActions: const [
          SizedBox(width: 14),
          CurrentPosition(),
          SizedBox(width: 8),
          ProgressBar(isExpanded: true),
          RemainingDuration(),
          PlaybackSpeedButton(),
          FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        return PopScope(
          canPop: !_isFullScreen,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) {
              _userWantsFullscreen = false;
              await _restoreAppOrientation();
              return;
            }
            if (_isFullScreen || _userWantsFullscreen) {
              _userWantsFullscreen = false;
              try {
                if (_controller.value.isFullScreen) {
                  _controller.toggleFullScreenMode();
                }
              } catch (_) {}
              await _restoreAppOrientation();
              if (mounted) setState(() => _isFullScreen = false);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: _isFullScreen
                ? null
                : AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _close,
                    ),
                    title: Text(
                      widget.videoTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
            body: SafeArea(
              top: !_isFullScreen,
              bottom: !_isFullScreen,
              child: _isFullScreen
                  ? player
                  : Column(
                      children: [
                        player,
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            widget.videoTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
