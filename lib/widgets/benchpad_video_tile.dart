import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/neumorphic_theme.dart';

/// BenchPad presentation video — the logo/bench showcase clip, ported
/// from index.html's #videoTile (assets/benchpad-video.mp4): autoplay,
/// looping, muted by default with a tap-to-unmute button in the corner.
class BenchPadVideoTile extends StatefulWidget {
  const BenchPadVideoTile({super.key});

  @override
  State<BenchPadVideoTile> createState() => _BenchPadVideoTileState();
}

class _BenchPadVideoTileState extends State<BenchPadVideoTile> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/video/benchpad-video.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSound() {
    setState(() {
      _muted = !_muted;
      _controller.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return NeumorphicBox(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              Positioned(
                right: 10,
                bottom: 10,
                child: Material(
                  color: Colors.black.withOpacity(0.45),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleSound,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 18),
                    ),
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
