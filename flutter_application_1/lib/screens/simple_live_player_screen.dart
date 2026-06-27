import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../utils/app_globals.dart';

class SimpleLivePlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const SimpleLivePlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  @override
  State<SimpleLivePlayerScreen> createState() => _SimpleLivePlayerScreenState();
}

class _SimpleLivePlayerScreenState extends State<SimpleLivePlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    enterLiveWatchMode(); // ► Bloquer les notifications pendant la lecture
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        isLive: true,
        showControls: true,
        allowFullScreen: true,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Erreur de lecture du flux.\n$errorMessage',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing live player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    exitLiveWatchMode(); // ► Réactiver les notifications (avec délai de 5s)
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: _hasError
              ? const Text(
                  'Impossible de charger ce flux live.',
                  style: TextStyle(color: Colors.white),
                )
              : _chewieController != null &&
                      _chewieController!.videoPlayerController.value.isInitialized
                  ? Chewie(controller: _chewieController!)
                  : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
