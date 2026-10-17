import 'package:flutter/material.dart';

import 'youtube_player_widget.dart';

/// Legacy popup entry — delegates to fullscreen-safe [YoutubePlayerWidget].
class VideoPopupPlayer extends StatelessWidget {
  final String videoId;
  final String videoTitle;

  const VideoPopupPlayer({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  Widget build(BuildContext context) {
    // Replace dialog usage with the proper player route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      YoutubePlayerWidget.open(
        context,
        videoId: videoId,
        videoTitle: videoTitle,
      );
    });
    return const SizedBox.shrink();
  }
}
