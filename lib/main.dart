import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(GameSwipeApp(showOnboarding: !onboardingComplete));
}

class GameSwipeApp extends StatelessWidget {
  final bool showOnboarding;
  const GameSwipeApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameSwipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: showOnboarding ? const OnboardingScreen() : const FeedScreen(),
    );
  }
}

// ============================================
// ONBOARDING SCREEN
// ============================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _nicknameController = TextEditingController();
  String _nickname = '';

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1), // Slide up off screen
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pageController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isExiting) return;
    _isExiting = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('user_nickname', _nickname);

    // Animate slide up, then navigate
    await _slideController.forward();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const FeedScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildNicknamePage(),
            _buildSwipeTutorialPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildNicknamePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Create Your\nNickname',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This will be shown on leaderboards',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _nicknameController,
            onChanged: (value) => setState(() => _nickname = value),
            style: const TextStyle(color: Colors.black, fontSize: 18),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter nickname...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nickname.length >= 2 ? _goToNextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeTutorialPage() {
    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          // Detect swipe up (negative velocity means upward)
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            _completeOnboarding();
          }
        },
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Text(
                'Swipe up to start\nwatching',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 48),
              const SwipeUpAnimation(),
              const Spacer(flex: 3),
              // Chevrons at bottom center
              const PulsingChevrons(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// SWIPE UP ANIMATION
// ============================================

class SwipeUpAnimation extends StatefulWidget {
  const SwipeUpAnimation({super.key});

  @override
  State<SwipeUpAnimation> createState() => _SwipeUpAnimationState();
}

class _SwipeUpAnimationState extends State<SwipeUpAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Hand moves UP: starts at bottom (0) and moves up (60)
    _slideAnimation = Tween<double>(begin: 0, end: 60).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Fade out as hand moves up
    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Phone mockup
          Container(
            width: 100,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(Icons.play_arrow, size: 40, color: Colors.grey[500]),
            ),
          ),
          // Animated hand
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                right: 60,
                bottom: 20 + _slideAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: const Icon(
                    Icons.touch_app,
                    size: 48,
                    color: Colors.black87,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================
// PULSING CHEVRONS
// ============================================

class PulsingChevrons extends StatefulWidget {
  const PulsingChevrons({super.key});

  @override
  State<PulsingChevrons> createState() => _PulsingChevronsState();
}

class _PulsingChevronsState extends State<PulsingChevrons>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.7),
          child: Transform.translate(
            offset: Offset(0, -_controller.value * 5),
            child: const Column(
              children: [
                Icon(Icons.keyboard_arrow_up, size: 32, color: Colors.grey),
                Icon(Icons.keyboard_arrow_up, size: 32, color: Colors.grey),
              ],
            ),
          ),
        );
      },
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
  {'id': 7, 'title': 'Jumping Cube', 'video': 'assets/videos/Game7.mov', 'gameUrl': 'https://cube-jump-game.vercel.app/'},
  {'id': 8, 'title': 'Beware of Spikes', 'video': 'assets/videos/Game8.mov', 'gameUrl': 'https://dont-touch-spikes-game.vercel.app/'},
  {'id': 9, 'title': 'Duet', 'video': 'assets/videos/Game9.mov', 'gameUrl': 'https://duet-game.vercel.app/'},
  {'id': 10, 'title': 'GSwitch', 'video': 'assets/videos/Game10.mov', 'gameUrl': 'https://gravity-switch-game-kappa.vercel.app/'},
  {'id': 11, 'title': 'Snake', 'video': 'assets/videos/Game11.mov', 'gameUrl': 'https://slither-io-game.vercel.app/'},
  {'id': 12, 'title': 'Hero Stick', 'video': 'assets/videos/Game12.mov', 'gameUrl': 'https://stick-hero-game-ten.vercel.app/'},
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
  final ScreenshotController screenshotController = ScreenshotController();
  bool showShareDialog = false;
  int? gameScore;
  int? highScore;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1')
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleGameMessage(message.message);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => isLoading = false),
      ))
      ..loadRequest(Uri.parse(widget.gameUrl));
  }

  void _handleGameMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['event'] == 'gameEnd') {
        setState(() {
          gameScore = data['score'];
          highScore = data['highScore'];
          showShareDialog = true;
        });
      }
    } catch (e) {
      print('Error parsing game message: $e');
    }
  }

  Future<void> _shareScore() async {
    try {
      final image = await screenshotController.capture();
      if (image == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/game_score_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'I scored $gameScore in ${widget.title}! 🎮',
      );

      setState(() {
        showShareDialog = false;
      });
    } catch (e) {
      print('Error sharing: $e');
    }
  }

  void _playAgain() {
    setState(() {
      showShareDialog = false;
    });
    controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: screenshotController,
      child: Scaffold(
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

            if (showShareDialog)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Game Over!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Score: $gameScore',
                          style: const TextStyle(fontSize: 24, color: Colors.white),
                        ),
                        if (gameScore == highScore)
                          const Text(
                            '🏆 New High Score!',
                            style: TextStyle(fontSize: 20, color: Colors.amber),
                          ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _playAgain,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            minimumSize: const Size(200, 50),
                          ),
                          child: const Text(
                            'Play Again',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _shareScore,
                          icon: const Icon(Icons.share),
                          label: const Text('Share to Instagram'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            minimumSize: const Size(200, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}