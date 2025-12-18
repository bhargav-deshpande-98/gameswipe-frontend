import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

// Change this based on your setup
const apiUrl = 'http://10.0.2.2:8000'; // Android emulator
// const apiUrl = 'http://localhost:8000'; // iOS simulator
// const apiUrl = 'http://192.168.x.x:8000'; // Physical device

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const GameSwipeApp());
}

class GameSwipeApp extends StatelessWidget {
  const GameSwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameSwipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const FeedScreen(),
    );
  }
}

// ==================== FEED SCREEN ====================

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> videos = [];
  int currentIndex = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadVideos();
  }

  Future<void> loadVideos() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/api/videos'));
      if (response.statusCode == 200) {
        setState(() {
          videos = List<Map<String, dynamic>>.from(json.decode(response.body));
          isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('API not available, using mock data');
    }

    // Fallback mock data
    setState(() {
      videos = [
        {
          "id": 1,
          "video_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
          "title": "2048 - Satisfying Merge!",
          "game": {"title": "2048", "game_url": "https://play2048.co/"}
        },
        {
          "id": 2,
          "video_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
          "title": "Flappy Bird High Score",
          "game": {"title": "Flappy Bird", "game_url": "https://flappybird.io/"}
        },
        {
          "id": 3,
          "video_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
          "title": "Pacman Perfect Run",
          "game": {"title": "Pacman", "game_url": "https://www.google.com/logos/2010/pacman10-i.html"}
        },
      ];
      isLoading = false;
    });
  }

  void launchGame(Map<String, dynamic> game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(title: game['title'], gameUrl: game['game_url']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.purple)),
      );
    }

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            launchGame(videos[currentIndex]['game']);
          }
        },
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: videos.length,
          onPageChanged: (index) => setState(() => currentIndex = index),
          itemBuilder: (context, index) {
            return VideoCard(
              video: videos[index],
              isActive: index == currentIndex,
              onPlayGame: () => launchGame(videos[index]['game']),
            );
          },
        ),
      ),
    );
  }
}

// ==================== VIDEO CARD ====================

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final VoidCallback onPlayGame;

  const VideoCard({
    super.key,
    required this.video,
    required this.isActive,
    required this.onPlayGame,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late VideoPlayerController controller;
  bool isInitialized = false;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.video['video_url']))
      ..initialize().then((_) {
        setState(() => isInitialized = true);
        controller.setLooping(true);
        if (widget.isActive) controller.play();
      });
  }

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      controller.play();
      isPaused = false;
    } else if (!widget.isActive && oldWidget.isActive) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void togglePlayPause() {
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        isPaused = true;
      } else {
        controller.play();
        isPaused = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.video['game'];

    return GestureDetector(
      onTap: togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          Container(
            color: Colors.black,
            child: isInitialized
                ? Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  )
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),

          // Pause icon
          if (isPaused)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, size: 50, color: Colors.white),
              ),
            ),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // Video info
          Positioned(
            bottom: 100,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(game['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(widget.video['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // Play button
          Positioned(
            right: 16,
            bottom: 120,
            child: GestureDetector(
              onTap: widget.onPlayGame,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow, size: 30, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  const Text('Play', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),

          // Swipe hint
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.4,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
              child: const Column(
                children: [
                  Icon(Icons.swipe_left, color: Colors.white70, size: 24),
                  Text('Swipe to\nplay', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
          ),

          // Progress bar
          if (isInitialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.purple,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== GAME SCREEN ====================

class GameScreen extends StatefulWidget {
  final String title;
  final String gameUrl;

  const GameScreen({super.key, required this.title, required this.gameUrl});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => isLoading = false),
      ))
      ..loadRequest(Uri.parse(widget.gameUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(widget.title),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => controller.reload())],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading) const Center(child: CircularProgressIndicator(color: Colors.purple)),
        ],
      ),
    );
  }
}
