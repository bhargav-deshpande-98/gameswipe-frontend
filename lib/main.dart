import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  {'id': 1, 'title': 'Video 1', 'color': Colors.purple},
  {'id': 2, 'title': 'Video 2', 'color': Colors.blue},
  {'id': 3, 'title': 'Video 3', 'color': Colors.teal},
  {'id': 4, 'title': 'Video 4', 'color': Colors.orange},
  {'id': 5, 'title': 'Video 5', 'color': Colors.pink},
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
      MaterialPageRoute(builder: (context) => const GameScreen()),
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
            final video = videos[index];
            return Container(
              color: video['color'] as Color,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      video['title'] as String,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40),
                    const Text('⬆️ Swipe up for next', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    const Text('⬅️ Swipe left to play game', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

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
        title: const Text('Game'),
      ),
      body: const Center(
        child: Text(
          'Destination App',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}