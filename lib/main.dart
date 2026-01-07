import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GameSwipeApp());
}

class GameSwipeApp extends StatelessWidget {
  const GameSwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameSwipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const FeedScreen(),
    );
  }
}

final videos = [
  {'id': 1, 'title': 'Slither.io', 'video': 'assets/videos/Game1.mov', 'gameUrl': 'https://slither.io/'},
  {'id': 2, 'title': 'Bloxd.io', 'video': 'assets/videos/Game2.mov', 'gameUrl': 'https://bloxd.io/'},
  {'id': 3, 'title': 'Circlify', 'video': 'assets/videos/Game3.mov', 'gameUrl': 'https://circlify-game.vercel.app/'},
  {'id': 4, 'title': 'aa-speed', 'video': 'assets/videos/Game4.mov', 'gameUrl': 'https://aa-game.vercel.app/'},
  {'id': 5, 'title': 'Agar', 'video': 'assets/videos/Game5.mov', 'gameUrl': 'https://agar-io-game-pc3l.vercel.app/'},
  {'id': 6, 'title': 'Crossy Road', 'video': 'assets/videos/Game6.mov', 'gameUrl': 'https://crossy-road-game-lo43.vercel.app/'},
];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int currentIndex = 0;

  void onSwipeLeft() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          title: videos[currentIndex]['title'] as String,
          gameUrl: videos[currentIndex]['gameUrl'] as String,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            onSwipeLeft();
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
            );
          },
        ),
      ),
    );
  }
}

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;

  const VideoCard({super.key, required this.video, required this.isActive});

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late VideoPlayerController controller;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.asset(widget.video['video'])
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
    } else if (!widget.isActive && oldWidget.isActive) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
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
        Positioned(
          bottom: 100,
          left: 16,
          child: Text(
            widget.video['title'],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
            child: const Column(
              children: [
                Icon(Icons.swipe_left, color: Colors.white70),
                Text('Swipe to\nplay', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1')
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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.reload(),
          ),
        ],
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