import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';

class VideoScreen extends StatefulWidget {
  final String url;

  VideoScreen({this.url = ''});

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController _videoPlayerController;
  ChewieController _chewieController;
  String _url;

  @override
  void initState() {
    super.initState();
    _url = widget.url ??
        'https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_20mb.mp4';
    _initializePlayer();
  }

  Future<dynamic> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.network(_url);
    await _videoPlayerController.initialize();
    _chewieController = ChewieController(
      looping: true,
      autoPlay: true,
      allowMuting: true,
      autoInitialize: true,
      allowFullScreen: true,
      videoPlayerController: _videoPlayerController,
      aspectRatio: _videoPlayerController.value.aspectRatio,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _chewieController == null ||
                !_chewieController.videoPlayerController.value.isInitialized
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Loading'),
                ],
              )
            : Chewie(controller: _chewieController),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}
