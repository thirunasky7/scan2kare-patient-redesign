import 'package:flutter/material.dart';

import 'youtube_player_widget.dart';

/// Legacy alias — opens the fullscreen-safe player.
class FixedYoutubePlayer extends StatelessWidget {
  final String videoId;
  final String videoTitle;

  const FixedYoutubePlayer({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  Widget build(BuildContext context) {
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
