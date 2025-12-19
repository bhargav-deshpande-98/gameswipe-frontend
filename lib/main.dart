import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

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
  {'id': 1, 'title': 'Slither.io', 'video': 'assets/videos/Game1.mov', 'gameUrl': 'http://slither.io'},
  {'id': 2, 'title': 'Game 2', 'video': 'assets/videos/Game2.mov', 'gameUrl': 'http://example.com'},
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
      MaterialPageRoute(builder: (context) => GameScreen(title: videos[currentIndex]['title'] as String)),
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

        // Title overlay
        Positioned(
          bottom: 100,
          left: 16,
          child: Text(
            widget.video['title'],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),

        // Swipe hint
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

class GameScreen extends StatelessWidget {
  final String title;
  const GameScreen({super.key, required this.title});

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
        title: Text(title),
      ),
      body: const Center(
        child: Text('Destination App', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      ),
    );
  }
}