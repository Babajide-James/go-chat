import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/theme/app_theme.dart';

class FullscreenVideoView extends StatefulWidget {
  final String videoUrl;

  const FullscreenVideoView({super.key, required this.videoUrl});

  @override
  State<FullscreenVideoView> createState() => _FullscreenVideoViewState();
}

class _FullscreenVideoViewState extends State<FullscreenVideoView> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppTheme.primaryOrange,
        handleColor: AppTheme.darkOrange,
        backgroundColor: Colors.white24,
        bufferedColor: AppTheme.lightPeach.withOpacity(0.5),
      ),
    );

    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Video',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: _initialized && _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryOrange),
              ),
      ),
    );
  }
}
