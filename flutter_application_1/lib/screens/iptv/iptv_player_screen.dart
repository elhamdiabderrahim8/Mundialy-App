import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../services/iptv_service.dart';
import '../../widgets/loading_skeletons.dart';

const Color _kGold = Color(0xFFE7C16A);
const Color _kDarkBg = Color(0xFF0E1A24);

class IptvPlayerScreen extends StatefulWidget {
  final IptvService iptvService;
  final int streamId;
  final String channelName;

  const IptvPlayerScreen({
    super.key,
    required this.iptvService,
    required this.streamId,
    required this.channelName,
  });

  @override
  State<IptvPlayerScreen> createState() => _IptvPlayerScreenState();
}

class _IptvPlayerScreenState extends State<IptvPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;
  bool _isLoading = true;
  bool _triedTs = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _initializePlayer(useM3u8: true);
  }

  Future<void> _initializePlayer({required bool useM3u8}) async {
    // Dispose previous controllers if retrying
    _chewieController?.dispose();
    _videoPlayerController?.dispose();

    final streamUrl = widget.iptvService.getStreamUrl(
      widget.streamId,
      useM3u8: useM3u8,
    );

    setState(() {
      _isLoading = true;
      _isError = false;
    });

    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
    );

    try {
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        isLive: true,
        allowFullScreen: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _kGold,
          handleColor: _kGold,
          bufferedColor: _kGold.withValues(alpha: 0.3),
          backgroundColor: Colors.white24,
        ),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget('Erreur: $errorMessage');
        },
      );
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Video Player Error (${useM3u8 ? "M3U8" : "TS"}): $e');
      // If M3U8 failed, try TS
      if (useM3u8 && !_triedTs) {
        _triedTs = true;
        _initializePlayer(useM3u8: false);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isError = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Widget _buildErrorWidget(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Impossible de charger le flux',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: _kDarkBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                _triedTs = false;
                _initializePlayer(useM3u8: true);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Réessayer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _kGold,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.channelName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isError
                        ? Colors.redAccent
                        : (_isLoading ? Colors.orange : Colors.greenAccent),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isError
                      ? 'Hors ligne'
                      : (_isLoading ? 'Connexion...' : 'En direct'),
                  style: TextStyle(
                    color: _isError
                        ? Colors.redAccent
                        : (_isLoading ? Colors.orange : Colors.greenAccent),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Center(
        child: _isLoading
            ? VideoPlayerSkeleton(channelName: widget.channelName)
            : _isError
            ? _buildErrorWidget(
                'Le flux vidéo n\'est pas accessible. Vérifiez votre connexion ou votre abonnement IPTV.',
              )
            : (_chewieController != null &&
                  _chewieController!.videoPlayerController.value.isInitialized)
            ? Chewie(controller: _chewieController!)
            : const SizedBox.shrink(),
      ),
    );
  }
}
