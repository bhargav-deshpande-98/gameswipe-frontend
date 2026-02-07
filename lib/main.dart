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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
  await LikedGamesService.init();
  await RecentlyPlayedService.init();
  await FriendsService.init();

  runApp(PlaybyteApp(showOnboarding: !onboardingComplete));
}

class PlaybyteApp extends StatelessWidget {
  final bool showOnboarding;
  const PlaybyteApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Playbyte',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: showOnboarding ? const OnboardingScreen() : const MainNavigationScreen(),
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
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _nicknameController = TextEditingController();
  String _nickname = '';

  late AnimationController _slideUpController;
  late Animation<Offset> _slideUpAnimation;
  late AnimationController _slideLeftController;
  late Animation<Offset> _slideLeftAnimation;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    // Slide up animation for page 2
    _slideUpController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideUpAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1), // Slide up off screen
    ).animate(CurvedAnimation(
      parent: _slideUpController,
      curve: Curves.easeInOut,
    ));

    // Slide left animation for page 3
    _slideLeftController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideLeftAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1, 0), // Slide left off screen
    ).animate(CurvedAnimation(
      parent: _slideLeftController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _slideUpController.dispose();
    _slideLeftController.dispose();
    _pageController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  bool _isAnimating = false;

  Future<void> _goToNextPageWithAnimation() async {
    if (_isAnimating) return;
    _isAnimating = true;

    await _slideUpController.forward();
    _pageController.jumpToPage(_pageController.page!.toInt() + 1);
    _slideUpController.reset();
    _isAnimating = false;
  }

  Future<void> _completeOnboarding() async {
    if (_isExiting) return;
    _isExiting = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('user_nickname', _nickname);

    // Animate slide left, then navigate
    await _slideLeftController.forward();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildNicknamePage(),
              _buildSwipeUpTutorialPage(),
              _buildSwipeLeftTutorialPage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNicknamePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom -
              64, // Account for SafeArea and padding
        ),
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
              'This is how your friends and followers will recognize you',
              textAlign: TextAlign.center,
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
                onPressed: _nickname.length >= 2 ? () {
                  // Dismiss keyboard before navigating
                  FocusScope.of(context).unfocus();
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } : null,
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
      ),
    );
  }

  Widget _buildSwipeUpTutorialPage() {
    return SlideTransition(
      position: _slideUpAnimation,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          // Detect swipe up (negative velocity means upward)
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            _goToNextPageWithAnimation();
          }
        },
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Stack(
            children: [
              // Main content - centered
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Spacer(flex: 2),
                    Text(
                      'Swipe up for\nnext game',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 48),
                    SwipeUpAnimation(),
                    Spacer(flex: 2),
                    // Chevrons at bottom center
                    PulsingChevrons(),
                    Spacer(flex: 1),
                  ],
                ),
              ),
              // Back button
              Positioned(
                top: 16,
                left: 0,
                child: GestureDetector(
                  onTap: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black54,
                      size: 24,
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

  Widget _buildSwipeLeftTutorialPage() {
    return SlideTransition(
      position: _slideLeftAnimation,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Stack(
          children: [
            // Main content - centered
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  const Text(
                    'Tap play to\nstart a game',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const TapPlayAnimation(),
                  const Spacer(flex: 2),
                  // "Get Started" button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
            // Back button
            Positioned(
              top: 16,
              left: 0,
              child: GestureDetector(
                onTap: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.black54,
                    size: 24,
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

// ============================================
// TAP PLAY ANIMATION (for onboarding)
// ============================================

class TapPlayAnimation extends StatefulWidget {
  const TapPlayAnimation({super.key});

  @override
  State<TapPlayAnimation> createState() => _TapPlayAnimationState();
}

class _TapPlayAnimationState extends State<TapPlayAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Finger taps: scales down then back up
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
    ]).animate(_controller);

    // Ripple fades in then out
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.6), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
    ]).animate(_controller);
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
              // Play button inside phone
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ripple effect
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black45, width: 2),
                          ),
                        ),
                      ),
                      // Play button
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey[500],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Animated hand tapping
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                right: 55,
                bottom: 50,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
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
// LOADING DOTS ANIMATION
// ============================================

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
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
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Stagger the animation for each dot
            final delay = index * 0.2;
            final animValue = ((_controller.value + delay) % 1.0);
            // Create a bounce effect
            final scale = animValue < 0.5
                ? 1.0 + (animValue * 0.6)
                : 1.0 + ((1.0 - animValue) * 0.6);
            final opacity = animValue < 0.5
                ? 0.4 + (animValue * 1.2)
                : 0.4 + ((1.0 - animValue) * 1.2);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF667EEA).withValues(alpha: opacity),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ============================================
// MAIN NAVIGATION SCREEN (Bottom Nav Bar)
// ============================================

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<_ProfileScreenState> _profileKey = GlobalKey<_ProfileScreenState>();

  // Theme colors based on current tab
  bool get _isDarkTheme => true; // All tabs use dark theme

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Refresh profile screen when navigating to it
    if (index == 2) {
      _profileKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkTheme ? Colors.black : Colors.white;
    final borderColor = _isDarkTheme ? Colors.white12 : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(isTabActive: _currentIndex == 0),
          const FriendsScreen(),
          ProfileScreen(key: _profileKey),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Friends',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Me',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = _isDarkTheme ? Colors.white : Colors.black;
    final inactiveColor = _isDarkTheme ? Colors.white60 : Colors.grey;

    return GestureDetector(
      onTap: () => _onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// PROFILE SCREEN (Me Tab)
// ============================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _nickname = '';
  int _gamesPlayed = 0;
  int _selectedTab = 0; // 0 = Created, 1 = Recent

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Called when navigating to this screen to refresh data
  void refresh() {
    _loadUserData();
    setState(() {}); // Trigger rebuild for liked games count and recent games
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nickname = prefs.getString('user_nickname') ?? 'Player';
      _gamesPlayed = RecentlyPlayedService.getUniqueGamesPlayedCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedGamesCount = LikedGamesService.getLikedGames().length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _nickname,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Picture
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: ClipOval(
                  child: SvgPicture.asset(
                    'assets/logo/playbite_app_icon.svg',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Username
            Text(
              '@${_nickname.toLowerCase().replaceAll(' ', '_')}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 24),
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatColumn('$_gamesPlayed', 'Played'),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                ),
                _buildStatColumn('$likedGamesCount', 'Liked'),
              ],
            ),
            const SizedBox(height: 24),
            // Edit Profile Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () {
                    _showEditProfileDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Edit profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Bio placeholder
            const Text(
              'Tap to add bio',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 24),
            // Tab Bar
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 0 ? Colors.white : Colors.white12,
                            width: _selectedTab == 0 ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: _selectedTab == 0 ? Colors.white : Colors.white38,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Created',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                              color: _selectedTab == 0 ? Colors.white : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 1 ? Colors.white : Colors.white12,
                            width: _selectedTab == 1 ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 20,
                            color: _selectedTab == 1 ? Colors.white : Colors.white38,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Recent',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                              color: _selectedTab == 1 ? Colors.white : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Tab Content
            _selectedTab == 0
                ? _buildCreatedGamesContent()
                : _buildRecentlyPlayedContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedContent() {
    final recentGames = RecentlyPlayedService.getRecentGames();

    if (recentGames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white12,
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  size: 40,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No games played yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap play on games to start playing',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
        ),
        itemCount: recentGames.length,
        itemBuilder: (context, index) {
          return _buildGameThumbnail(recentGames[index]);
        },
      ),
    );
  }

  Widget _buildGameThumbnail(Map<String, dynamic> game) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              title: game['title'] as String,
              gameUrl: game['gameUrl'] as String,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _GameThumbnailVideo(
                  videoPath: game['video'] as String,
                  isNetworkVideo: game['isFirebaseGame'] == true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            game['title'] as String,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white60,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedGamesContent() {
    // Always show empty state - games will be added manually for MVP
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.rocket_launch_rounded,
              size: 48,
              color: Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 20),
            const Text(
              'Build your first game',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No code. Just prompt, create, play.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _showMakeGameOptions(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Create a Game',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog() {
    final controller = TextEditingController(text: _nickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Nickname'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new nickname',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.length >= 2) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_nickname', controller.text);
                setState(() {
                  _nickname = controller.text;
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMakeGameOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create a Game',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Option 1: Create with Playbyte Creator
            _buildOptionTile(
              icon: Icons.auto_awesome,
              title: 'Create with Playbyte Creator',
              subtitle: 'Use AI to build your game',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GameScreen(
                      title: 'Playbyte Creator',
                      gameUrl: 'https://lovable-games.fly.dev/',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Option 2: Submit a game
            _buildOptionTile(
              icon: Icons.link,
              title: 'Submit a Game',
              subtitle: 'Add your Vercel-hosted game',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubmitGameScreen(creatorName: '@${_nickname.toLowerCase().replaceAll(' ', '_')}'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

}

// ============================================
// GAME THUMBNAIL VIDEO WIDGET
// ============================================

class _GameThumbnailVideo extends StatefulWidget {
  final String videoPath;
  final bool isNetworkVideo;

  const _GameThumbnailVideo({
    required this.videoPath,
    this.isNetworkVideo = false,
  });

  @override
  State<_GameThumbnailVideo> createState() => _GameThumbnailVideoState();
}

class _GameThumbnailVideoState extends State<_GameThumbnailVideo> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isYouTube = false;
  String? _youTubeThumbnailUrl;

  @override
  void initState() {
    super.initState();

    // Check for YouTube URL
    if (widget.isNetworkVideo) {
      final videoId = YouTubeHelper.extractVideoId(widget.videoPath);
      if (videoId != null) {
        _isYouTube = true;
        _youTubeThumbnailUrl = YouTubeHelper.getThumbnailUrl(videoId);
        _isInitialized = true;
        return;
      }
    }

    if (widget.isNetworkVideo) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller!.seekTo(Duration.zero);
            _controller!.pause();
          }
        }).catchError((e) {
          if (mounted) setState(() => _isInitialized = true);
        });
    } else {
      _controller = VideoPlayerController.asset(widget.videoPath)
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller!.seekTo(Duration.zero);
            _controller!.pause();
          }
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(
            Icons.videogame_asset,
            color: Colors.grey[500],
            size: 24,
          ),
        ),
      );
    }

    if (_isYouTube) {
      return Image.network(
        _youTubeThumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: Center(
            child: Icon(Icons.videogame_asset, color: Colors.grey[500], size: 24),
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

// ============================================
// RECENTLY PLAYED SERVICE
// ============================================

class RecentlyPlayedService {
  static const String _key = 'recently_played_games';
  static const String _uniquePlayedKey = 'unique_played_game_ids';
  static List<int> _recentGameIds = [];
  static Set<int> _uniquePlayedGameIds = {};
  static const int _maxGames = 10;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];
    _recentGameIds = stored.map((e) => int.parse(e)).toList();
    // Load unique played games
    final uniquePlayed = prefs.getStringList(_uniquePlayedKey) ?? [];
    _uniquePlayedGameIds = uniquePlayed.map((e) => int.parse(e)).toSet();
    _initialized = true;
  }

  static Future<void> addGame(int gameId) async {
    final prefs = await SharedPreferences.getInstance();

    // Track unique games played
    if (!_uniquePlayedGameIds.contains(gameId)) {
      _uniquePlayedGameIds.add(gameId);
      await prefs.setStringList(
        _uniquePlayedKey,
        _uniquePlayedGameIds.map((e) => e.toString()).toList(),
      );
      // Update the games_played counter
      await prefs.setInt('games_played', _uniquePlayedGameIds.length);
    }

    // Remove if already exists (to move to front)
    _recentGameIds.remove(gameId);
    // Add to front
    _recentGameIds.insert(0, gameId);
    // Keep only last 10
    if (_recentGameIds.length > _maxGames) {
      _recentGameIds = _recentGameIds.sublist(0, _maxGames);
    }
    // Persist recent games
    await prefs.setStringList(_key, _recentGameIds.map((e) => e.toString()).toList());
  }

  static int getUniqueGamesPlayedCount() {
    return _uniquePlayedGameIds.length;
  }

  static List<Map<String, dynamic>> getRecentGames() {
    final List<Map<String, dynamic>> result = [];
    for (final id in _recentGameIds) {
      final game = GameService.findGameById(id);
      if (game != null) {
        result.add(game);
      }
    }
    return result;
  }
}

// ============================================
// LIKED GAMES SERVICE
// ============================================

class LikedGamesService {
  static const String _key = 'liked_games';
  static Set<int> _likedGameIds = {};
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final likedList = prefs.getStringList(_key) ?? [];
    _likedGameIds = likedList.map((e) => int.parse(e)).toSet();
    _initialized = true;
  }

  static bool isLiked(int gameId) {
    return _likedGameIds.contains(gameId);
  }

  static Future<void> toggleLike(int gameId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_likedGameIds.contains(gameId)) {
      _likedGameIds.remove(gameId);
    } else {
      _likedGameIds.add(gameId);
    }
    await prefs.setStringList(_key, _likedGameIds.map((e) => e.toString()).toList());
  }

  static List<Map<String, dynamic>> getLikedGames() {
    final allGames = GameService.getAllGames();
    return allGames.where((v) => _likedGameIds.contains(v['id'])).toList();
  }
}

// ============================================
// FRIENDS SERVICE
// ============================================

class FriendsService {
  static const String _friendsKey = 'friend_ids';
  static const String _pendingKey = 'pending_friend_ids';
  static Set<String> _friendIds = {};
  static Set<String> _pendingIds = {};
  static bool _initialized = false;

  static final List<Map<String, dynamic>> mockUsers = [
    {
      'id': 'u1',
      'name': 'Alex Chen',
      'username': '@alex_chen',
      'avatarColor': 0xFF8B5CF6,
      'avatarEmoji': '🎮',
      'isOnline': true,
      'gamesPlayed': 42,
      'gamesInCommon': 3,
    },
    {
      'id': 'u2',
      'name': 'Maya Patel',
      'username': '@maya_p',
      'avatarColor': 0xFFEF4444,
      'avatarEmoji': '🕹️',
      'isOnline': true,
      'gamesPlayed': 38,
      'gamesInCommon': 5,
    },
    {
      'id': 'u3',
      'name': 'Jordan Lee',
      'username': '@jlee99',
      'avatarColor': 0xFF3B82F6,
      'avatarEmoji': '🏆',
      'isOnline': false,
      'gamesPlayed': 27,
      'gamesInCommon': 2,
    },
    {
      'id': 'u4',
      'name': 'Sam Rivera',
      'username': '@sam_r',
      'avatarColor': 0xFF10B981,
      'avatarEmoji': '⚡',
      'isOnline': true,
      'gamesPlayed': 55,
      'gamesInCommon': 4,
    },
    {
      'id': 'u5',
      'name': 'Taylor Kim',
      'username': '@tkim',
      'avatarColor': 0xFFF59E0B,
      'avatarEmoji': '🎯',
      'isOnline': false,
      'gamesPlayed': 19,
      'gamesInCommon': 1,
    },
    {
      'id': 'u6',
      'name': 'Riley Brooks',
      'username': '@riley_b',
      'avatarColor': 0xFFEC4899,
      'avatarEmoji': '🔥',
      'isOnline': false,
      'gamesPlayed': 33,
      'gamesInCommon': 3,
    },
    {
      'id': 'u7',
      'name': 'Casey Wu',
      'username': '@casey_w',
      'avatarColor': 0xFF6366F1,
      'avatarEmoji': '🚀',
      'isOnline': true,
      'gamesPlayed': 45,
      'gamesInCommon': 6,
    },
    {
      'id': 'u8',
      'name': 'Drew Martinez',
      'username': '@drew_m',
      'avatarColor': 0xFF14B8A6,
      'avatarEmoji': '🎲',
      'isOnline': false,
      'gamesPlayed': 21,
      'gamesInCommon': 2,
    },
    {
      'id': 'u9',
      'name': 'Priya Sharma',
      'username': '@priya_s',
      'avatarColor': 0xFFE11D48,
      'avatarEmoji': '🌟',
      'isOnline': true,
      'gamesPlayed': 36,
      'gamesInCommon': 4,
    },
    {
      'id': 'u10',
      'name': 'Nate Collins',
      'username': '@nate_c',
      'avatarColor': 0xFF0EA5E9,
      'avatarEmoji': '🎧',
      'isOnline': false,
      'gamesPlayed': 29,
      'gamesInCommon': 3,
    },
    {
      'id': 'u11',
      'name': 'Zoe Nakamura',
      'username': '@zoe_n',
      'avatarColor': 0xFFD946EF,
      'avatarEmoji': '✨',
      'isOnline': true,
      'gamesPlayed': 48,
      'gamesInCommon': 5,
    },
    {
      'id': 'u12',
      'name': 'Leo Fernandez',
      'username': '@leo_f',
      'avatarColor': 0xFFF97316,
      'avatarEmoji': '🦁',
      'isOnline': false,
      'gamesPlayed': 15,
      'gamesInCommon': 1,
    },
    {
      'id': 'u13',
      'name': 'Ava Thompson',
      'username': '@ava_t',
      'avatarColor': 0xFF22D3EE,
      'avatarEmoji': '💎',
      'isOnline': true,
      'gamesPlayed': 52,
      'gamesInCommon': 7,
    },
    {
      'id': 'u14',
      'name': 'Kai Johansson',
      'username': '@kai_j',
      'avatarColor': 0xFF84CC16,
      'avatarEmoji': '🏅',
      'isOnline': false,
      'gamesPlayed': 31,
      'gamesInCommon': 2,
    },
  ];

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final friends = prefs.getStringList(_friendsKey) ?? [];
    _friendIds = friends.toSet();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    _pendingIds = pending.toSet();
    final seedVersion = prefs.getInt('friends_seed_version') ?? 0;
    if (seedVersion < 2) {
      _friendIds = {'u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'u11'};
      await prefs.setInt('friends_seed_version', 2);
      await _save();
    }
    _initialized = true;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_friendsKey, _friendIds.toList());
    await prefs.setStringList(_pendingKey, _pendingIds.toList());
  }

  static bool isFriend(String userId) => _friendIds.contains(userId);
  static bool isPending(String userId) => _pendingIds.contains(userId);

  static List<Map<String, dynamic>> getFriends() {
    return mockUsers.where((u) => _friendIds.contains(u['id'])).toList();
  }

  static Future<void> addFriend(String userId) async {
    _pendingIds.add(userId);
    await _save();
  }

  static Future<void> removeFriend(String userId) async {
    _friendIds.remove(userId);
    _pendingIds.remove(userId);
    await _save();
  }

  static Future<void> cancelPending(String userId) async {
    _pendingIds.remove(userId);
    await _save();
  }

  static List<Map<String, dynamic>> getSuggestedFriends() {
    return mockUsers.where((u) =>
      !_friendIds.contains(u['id']) && !_pendingIds.contains(u['id'])
    ).toList();
  }

  static List<Map<String, dynamic>> searchUsers(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return mockUsers.where((u) =>
      (u['name'] as String).toLowerCase().contains(q) ||
      (u['username'] as String).toLowerCase().contains(q)
    ).toList();
  }

  static List<Map<String, dynamic>> getLeaderboard() {
    final all = List<Map<String, dynamic>>.from(getFriends());
    all.add({
      'id': 'current_user',
      'name': 'You',
      'username': '@you',
      'avatarColor': 0xFF8B5CF6,
      'avatarEmoji': '👤',
      'isOnline': true,
      'gamesPlayed': RecentlyPlayedService.getUniqueGamesPlayedCount(),
      'gamesInCommon': 0,
    });
    all.sort((a, b) => (b['gamesPlayed'] as int).compareTo(a['gamesPlayed'] as int));
    return all;
  }
}

// ============================================
// FRIENDS SCREEN
// ============================================

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _selectedTab = 0; // 0 = My Friends, 1 = Find Friends, 2 = Leaderboard
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildTabBar(),
            const SizedBox(height: 8),
            Expanded(
              child: _selectedTab == 0
                  ? _buildMyFriendsTab()
                  : _selectedTab == 1
                      ? _buildFindFriendsTab()
                      : _buildLeaderboardTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTabLabel('My Friends', 0),
        const SizedBox(width: 8),
        const Text('|', style: TextStyle(color: Colors.white60)),
        const SizedBox(width: 8),
        _buildTabLabel('Find Friends', 1),
        const SizedBox(width: 8),
        const Text('|', style: TextStyle(color: Colors.white60)),
        const SizedBox(width: 8),
        _buildTabLabel('Leaderboard', 2),
      ],
    );
  }

  Widget _buildTabLabel(String text, int tabIndex) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabIndex),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: _selectedTab == tabIndex ? FontWeight.bold : FontWeight.normal,
          color: _selectedTab == tabIndex ? Colors.white : Colors.white60,
        ),
      ),
    );
  }

  // ---- My Friends Tab ----

  Widget _buildMyFriendsTab() {
    final friends = FriendsService.getFriends();

    if (friends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(fontSize: 18, color: Colors.white60),
            ),
            SizedBox(height: 8),
            Text(
              'Find friends to play with!',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return _buildFriendListTile(friend);
      },
    );
  }

  Widget _buildFriendListTile(Map<String, dynamic> friend) {
    return GestureDetector(
      onTap: () => _showFriendProfile(friend),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(friend['avatarColor'] as int),
              ),
              child: Center(
                child: Text(
                  friend['avatarEmoji'] as String,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friend['username'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (friend['isOnline'] as bool) ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendProfile(Map<String, dynamic> friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(friend['avatarColor'] as int),
              ),
              child: Center(
                child: Text(
                  friend['avatarEmoji'] as String,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              friend['name'] as String,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              friend['username'] as String,
              style: const TextStyle(fontSize: 16, color: Colors.white60),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${friend['gamesInCommon']} games in common',
                style: const TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showComingSoonDialog('Challenge');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_esports, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Challenge',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await FriendsService.removeFriend(friend['id'] as String);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_remove, size: 20, color: Colors.white70),
                          SizedBox(width: 8),
                          Text(
                            'Remove',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon!'),
        content: Text(
          '$feature feature is currently in development. Stay tuned!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---- Find Friends Tab ----

  Widget _buildFindFriendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.white60),
                hintText: 'Search by name or username',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            _buildSearchResults(),
          ] else ...[
            _buildSuggestedFriendsSection(),
            const SizedBox(height: 24),
            _buildPeopleYouMayKnowSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = FriendsService.searchUsers(_searchQuery);
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(
          child: Text(
            'No users found',
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
        ),
      );
    }
    return Column(
      children: results.map((user) => _buildUserCard(user)).toList(),
    );
  }

  Widget _buildSuggestedFriendsSection() {
    final suggested = FriendsService.getSuggestedFriends();
    if (suggested.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested Friends',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...suggested.map((user) => _buildUserCard(user)),
      ],
    );
  }

  Widget _buildPeopleYouMayKnowSection() {
    final friends = FriendsService.getFriends();
    if (friends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'People You May Know',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Based on games you play',
          style: TextStyle(fontSize: 14, color: Colors.white38),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _buildCompactUserCard(friend);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isFriend = FriendsService.isFriend(user['id'] as String);
    final isPending = FriendsService.isPending(user['id'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(user['avatarColor'] as int),
            ),
            child: Center(
              child: Text(user['avatarEmoji'] as String, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] as String,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  user['username'] as String,
                  style: const TextStyle(fontSize: 14, color: Colors.white60),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              if (!isFriend && !isPending) {
                await FriendsService.addFriend(user['id'] as String);
                setState(() {});
              } else if (isPending) {
                await FriendsService.cancelPending(user['id'] as String);
                setState(() {});
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isFriend
                    ? Colors.white.withValues(alpha: 0.1)
                    : isPending
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(20),
                border: isFriend || isPending
                    ? Border.all(color: Colors.white24)
                    : null,
              ),
              child: Text(
                isFriend ? 'Friends' : isPending ? 'Pending' : 'Add Friend',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isFriend || isPending ? Colors.white60 : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactUserCard(Map<String, dynamic> user) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(user['avatarColor'] as int),
            ),
            child: Center(
              child: Text(user['avatarEmoji'] as String, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user['name'] as String,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '${user['gamesPlayed']} games',
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  // ---- Leaderboard Tab ----

  Widget _buildLeaderboardTab() {
    final leaderboard = FriendsService.getLeaderboard();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: leaderboard.length,
      itemBuilder: (context, index) {
        final user = leaderboard[index];
        final isCurrentUser = user['id'] == 'current_user';
        final rank = index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentUser ? const Color(0xFF8B5CF6) : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rank <= 3
                      ? ['🥇', '🥈', '🥉'][rank - 1]
                      : '#$rank',
                  style: TextStyle(
                    fontSize: rank <= 3 ? 22 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(user['avatarColor'] as int),
                ),
                child: Center(
                  child: Text(
                    user['avatarEmoji'] as String,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCurrentUser ? 'You' : user['name'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                        color: isCurrentUser ? const Color(0xFF8B5CF6) : Colors.white,
                      ),
                    ),
                    if (!isCurrentUser)
                      Text(
                        user['username'] as String,
                        style: const TextStyle(fontSize: 13, color: Colors.white60),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user['gamesPlayed']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'games',
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================
// HOME SCREEN WITH TABS
// ============================================

class HomeScreen extends StatefulWidget {
  final bool isTabActive;
  const HomeScreen({super.key, this.isTabActive = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0; // 0 = Feed, 1 = Liked Games
  Key _feedKey = UniqueKey(); // Key to force FeedScreen recreation on tab switch

  void _onLikeChanged() {
    setState(() {});
  }

  void _selectFeedTab() {
    setState(() {
      _selectedTab = 0;
      _feedKey = UniqueKey(); // Generate new key to reshuffle games
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content
        _selectedTab == 0
            ? FeedScreen(key: _feedKey, onLikeChanged: _onLikeChanged, isTabActive: widget.isTabActive)
            : LikedGamesScreen(onLikeChanged: _onLikeChanged, isTabActive: widget.isTabActive),
        // Top tabs
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _selectFeedTab,
                child: Text(
                  'Feed',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                    color: _selectedTab == 0 ? Colors.white : Colors.white60,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('|', style: TextStyle(color: Colors.white60)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: Text(
                  'Liked Games',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                    color: _selectedTab == 1 ? Colors.white : Colors.white60,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================
// GAME SERVICE (Supabase)
// ============================================

class GameService {
  static final _supabase = Supabase.instance.client;
  static List<Map<String, dynamic>> _supabaseGames = [];


  /// Fetches all games from Supabase and caches them locally.
  static Future<void> fetchGames() async {
    try {
      final response = await _supabase
          .from('games')
          .select()
          .order('created_at', ascending: false);

      _supabaseGames = (response as List).map((game) {
        return <String, dynamic>{
          'id': game['id'] as int,
          'title': game['title'] as String,
          'video': game['video_url'] as String,
          'gameUrl': game['game_url'] as String,
          'creator': game['creator'] as String? ?? '@anonymous',
          'description': game['description'] as String?,
          'isFirebaseGame': true, // Triggers network video player
        };
      }).toList();
    } catch (e) {
      // On error, keep empty list - hardcoded games still work
      _supabaseGames = [];
    }
  }

  /// Returns all games: hardcoded + Supabase, merged into one list.
  static List<Map<String, dynamic>> getAllGames() {
    return [...videos, ..._supabaseGames];
  }

  /// Returns only Supabase-sourced games.
  static List<Map<String, dynamic>> getSupabaseGames() {
    return List.unmodifiable(_supabaseGames);
  }

  /// Submits a new game to Supabase.
  /// Returns the formatted game map, or null on failure.
  static Future<Map<String, dynamic>?> submitGame({
    required String title,
    required String gameUrl,
    required String videoUrl,
    required String creator,
    String? description,
  }) async {
    try {
      final response = await _supabase.from('games').insert({
        'title': title,
        'game_url': gameUrl,
        'video_url': videoUrl,
        'creator': creator,
        'description': description,
      }).select().single();

      // Add to local cache immediately so it appears in feed
      final newGame = <String, dynamic>{
        'id': response['id'] as int,
        'title': response['title'] as String,
        'video': response['video_url'] as String,
        'gameUrl': response['game_url'] as String,
        'creator': response['creator'] as String? ?? '@anonymous',
        'description': response['description'] as String?,
        'isFirebaseGame': true,
      };
      _supabaseGames.insert(0, newGame);

      return newGame;
    } catch (e) {
      return null;
    }
  }

  /// Finds a game by ID across both hardcoded and Supabase games.
  static Map<String, dynamic>? findGameById(int id) {
    for (final v in videos) {
      if (v['id'] == id) return v;
    }
    for (final v in _supabaseGames) {
      if (v['id'] == id) return v;
    }
    return null;
  }
}

// ============================================
// YOUTUBE URL HELPERS
// ============================================

class YouTubeHelper {
  /// Extracts the video ID from various YouTube URL formats.
  /// Returns null if the URL is not a recognized YouTube URL.
  static String? extractVideoId(String url) {
    final patterns = [
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Returns true if the URL is a YouTube URL.
  static bool isYouTubeUrl(String url) {
    return extractVideoId(url) != null;
  }

  /// Returns a high-quality thumbnail URL for a YouTube video.
  static String getThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }
}

final videos = [
  {'id': 3, 'title': 'Circlify', 'video': 'assets/videos/circlify_with_sound.mov', 'gameUrl': 'https://circlify-game.vercel.app/', 'creator': '@borg'},
  {'id': 4, 'title': 'aa-speed', 'video': 'assets/videos/aa_with_sound.mov', 'gameUrl': 'https://aa-game.vercel.app/', 'creator': '@varin'},
  {'id': 5, 'title': 'Agar', 'video': 'assets/videos/agar-io.mov', 'gameUrl': 'https://agar-io-game-pc3l.vercel.app/', 'creator': '@borg'},
  {'id': 6, 'title': 'Crossy Road', 'video': 'assets/videos/crossy_road_with_sound.mov', 'gameUrl': 'https://crossy-road-game-lo43.vercel.app/', 'creator': '@varin'},
  {'id': 7, 'title': 'Jumping Cube', 'video': 'assets/videos/cube_jump_with_sound.mov', 'gameUrl': 'https://cube-jump-game.vercel.app/', 'creator': '@borg'},
  {'id': 8, 'title': 'Beware of Spikes', 'video': 'assets/videos/beware_of_spikes.mov', 'gameUrl': 'https://dont-touch-spikes-game.vercel.app/', 'creator': '@varin'},
  {'id': 9, 'title': 'Duet', 'video': 'assets/videos/duet_with_sound.mov', 'gameUrl': 'https://duet-game.vercel.app/', 'creator': '@borg'},
  {'id': 10, 'title': 'GSwitch', 'video': 'assets/videos/gravity_switch_with_sound.mov', 'gameUrl': 'https://gravity-switch-game-kappa.vercel.app/', 'creator': '@varin'},
  {'id': 11, 'title': 'Snake', 'video': 'assets/videos/Game11.mov', 'gameUrl': 'https://slither-io-game.vercel.app/', 'creator': '@borg'},
  {'id': 12, 'title': 'Hero Stick', 'video': 'assets/videos/stick_hero_with_sound.mov', 'gameUrl': 'https://stick-hero-game-ten.vercel.app/', 'creator': '@varin'},
  {'id': 13, 'title': 'Jelly Jump', 'video': 'assets/videos/jelly_jump_2_with_sound.mov', 'gameUrl': 'https://jelly-jump-reborn.vercel.app/', 'creator': '@borg'},
  {'id': 14, 'title': 'Swing Copters', 'video': 'assets/videos/swing_copters_2_with_sound.mov', 'gameUrl': 'https://sky-hopper-clone.vercel.app/', 'creator': '@varin'},
  {'id': 15, 'title': 'Masked Escape', 'video': 'assets/videos/masked_escape_2_with_sound.mov', 'gameUrl': 'https://masked-escape.vercel.app/', 'creator': '@borg'},
  {'id': 16, 'title': 'Helix Jump', 'video': 'assets/videos/helix_bounce_blitz_2_with_sound.mov', 'gameUrl': 'https://helix-bounce-blitz.vercel.app/', 'creator': '@varin'},
  {'id': 17, 'title': 'Icy Tower', 'video': 'assets/videos/icy_tower_2_with_sound.mov', 'gameUrl': 'https://tower-jump-mania.vercel.app/', 'creator': '@borg'},
  {'id': 18, 'title': 'Falldown', 'video': 'assets/videos/falldown_2_with_sound.mov', 'gameUrl': 'https://fall-down-fun.vercel.app/', 'creator': '@varin'},
  {'id': 19, 'title': 'Color Switch', 'video': 'assets/videos/color_switch_2_with_sound.mov', 'gameUrl': 'https://color-tap-mania.vercel.app/', 'creator': '@borg'},
  {'id': 20, 'title': 'Stack Master', 'video': 'assets/videos/stack_master_2.mov', 'gameUrl': 'https://stack-master-seven.vercel.app/', 'creator': '@varin'},
];

class FeedScreen extends StatefulWidget {
  final VoidCallback? onLikeChanged;
  final bool isTabActive;
  const FeedScreen({super.key, this.onLikeChanged, this.isTabActive = true});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int currentIndex = 0;
  List<Map<String, dynamic>> shuffledVideos = [];
  bool _isGameOpen = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _refreshGames();
    }
  }

  void _loadGames() async {
    await GameService.fetchGames();
    if (!mounted) return;
    setState(() {
      shuffledVideos = List<Map<String, dynamic>>.from(GameService.getAllGames())
        ..shuffle();
      _isLoading = false;
    });
  }

  Future<void> _refreshGames() async {
    await GameService.fetchGames();
    if (!mounted) return;
    final supabaseGames = GameService.getSupabaseGames();
    final hardcodedGames = List<Map<String, dynamic>>.from(videos)..shuffle();
    setState(() {
      shuffledVideos = [...supabaseGames, ...hardcodedGames];
      currentIndex = 0;
    });
  }

  void onSwipeLeft() async {
    final rawId = shuffledVideos[currentIndex]['id'];
    final gameId = rawId is int ? rawId : int.tryParse(rawId.toString());
    if (gameId != null) {
      await RecentlyPlayedService.addGame(gameId);
    }

    if (!mounted) return;

    // Pause video before navigating
    setState(() => _isGameOpen = true);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GameScreen(
          title: shuffledVideos[currentIndex]['title'] as String,
          gameUrl: shuffledVideos[currentIndex]['gameUrl'] as String,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide in from right (new screen)
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      // Resume video when returning from game
      if (mounted) setState(() => _isGameOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    if (shuffledVideos.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'No games available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshGames,
      color: const Color(0xFF8B5CF6),
      backgroundColor: Colors.grey[900],
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: shuffledVideos.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          return VideoCard(
            video: shuffledVideos[index],
            isActive: index == currentIndex && !_isGameOpen && widget.isTabActive,
            onPlayTap: onSwipeLeft,
            onLikeChanged: () {
              setState(() {});
              widget.onLikeChanged?.call();
            },
          );
        },
      ),
    );
  }
}

// ============================================
// LIKED GAMES SCREEN
// ============================================

class LikedGamesScreen extends StatefulWidget {
  final VoidCallback? onLikeChanged;
  final bool isTabActive;
  const LikedGamesScreen({super.key, this.onLikeChanged, this.isTabActive = true});

  @override
  State<LikedGamesScreen> createState() => _LikedGamesScreenState();
}

class _LikedGamesScreenState extends State<LikedGamesScreen> {
  int currentIndex = 0;
  bool _isGameOpen = false;

  void onSwipeLeft() async {
    final likedGames = LikedGamesService.getLikedGames();
    if (likedGames.isEmpty) return;

    final gameId = likedGames[currentIndex]['id'] as int;
    await RecentlyPlayedService.addGame(gameId);

    if (!mounted) return;

    // Pause video before navigating
    setState(() => _isGameOpen = true);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GameScreen(
          title: likedGames[currentIndex]['title'] as String,
          gameUrl: likedGames[currentIndex]['gameUrl'] as String,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide in from right (new screen)
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      // Resume video when returning from game
      if (mounted) setState(() => _isGameOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedGames = LikedGamesService.getLikedGames();

    if (likedGames.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No liked games yet',
              style: TextStyle(fontSize: 18, color: Colors.white60),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the heart on games you love!',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: likedGames.length,
      onPageChanged: (index) => setState(() => currentIndex = index),
      itemBuilder: (context, index) {
        return VideoCard(
          video: likedGames[index],
          isActive: index == currentIndex && !_isGameOpen && widget.isTabActive,
          onPlayTap: onSwipeLeft,
          onLikeChanged: () {
            setState(() {});
            widget.onLikeChanged?.call();
          },
        );
      },
    );
  }
}

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final VoidCallback? onLikeChanged;
  final VoidCallback? onPlayTap;

  const VideoCard({
    super.key,
    required this.video,
    required this.isActive,
    this.onLikeChanged,
    this.onPlayTap,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? controller;
  bool isInitialized = false;
  bool _isYouTube = false;
  String? _youTubeThumbnailUrl;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final videoPath = widget.video['video'] as String;
    final isNetworkVideo = widget.video['isFirebaseGame'] == true;

    // Check if this is a YouTube URL
    if (isNetworkVideo) {
      final videoId = YouTubeHelper.extractVideoId(videoPath);
      if (videoId != null) {
        _isYouTube = true;
        _youTubeThumbnailUrl = YouTubeHelper.getThumbnailUrl(videoId);
        setState(() => isInitialized = true);
        return;
      }
    }

    // Use network URL for non-YouTube network videos, asset path for hardcoded games
    if (isNetworkVideo) {
      controller = VideoPlayerController.networkUrl(Uri.parse(videoPath))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => isInitialized = true);
            controller!.setLooping(true);
            if (widget.isActive) controller!.play();
          }
        }).catchError((e) {
          // Handle network video load error
          if (mounted) {
            setState(() => isInitialized = true); // Show black screen instead of spinner
          }
        });
    } else {
      controller = VideoPlayerController.asset(videoPath)
        ..initialize().then((_) {
          if (mounted) {
            setState(() => isInitialized = true);
            controller!.setLooping(true);
            if (widget.isActive) controller!.play();
          }
        });
    }
  }

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller == null) return;
    if (widget.isActive && !oldWidget.isActive) {
      controller!.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      controller!.pause();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _toggleLike() async {
    final rawId = widget.video['id'];
    // Handle both int (hardcoded) and String (Firebase) IDs
    final gameId = rawId is int ? rawId : int.tryParse(rawId.toString());
    if (gameId != null) {
      await LikedGamesService.toggleLike(gameId);
      setState(() {});
      widget.onLikeChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawId = widget.video['id'];
    final gameId = rawId is int ? rawId : int.tryParse(rawId.toString());
    final isLiked = gameId != null ? LikedGamesService.isLiked(gameId) : false;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Get creator name from video data
    final creatorName = widget.video['creator'] as String? ?? '@borg';

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Space for the notch/status bar and tabs
          SizedBox(height: topPadding + 35),
          // Video container with rounded corners - tile style
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.black,
                        width: double.infinity,
                        height: double.infinity,
                        child: isInitialized
                            ? _isYouTube
                                ? Image.network(
                                    _youTubeThumbnailUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(child: Icon(Icons.videogame_asset, color: Colors.white54, size: 48)),
                                  )
                                : Align(
                                    alignment: Alignment.topCenter,
                                    child: AspectRatio(
                                      aspectRatio: controller!.value.aspectRatio,
                                      child: VideoPlayer(controller!),
                                    ),
                                  )
                            : const Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                      if (isInitialized)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => widget.onPlayTap?.call(),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.black.withValues(alpha: 0.85),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Play',
                                        style: TextStyle(
                                          color: Colors.black.withValues(alpha: 0.85),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Game title, creator, and like button row
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: bottomPadding + 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Game title and creator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      creatorName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                // Like button
                GestureDetector(
                  onTap: _toggleLike,
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late WebViewController controller;
  bool isLoading = true;
  final ScreenshotController screenshotController = ScreenshotController();
  bool showShareDialog = false;
  int? gameScore;
  int? highScore;
  late AnimationController _loadingAnimationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Setup loading animation
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _loadingAnimationController, curve: Curves.easeInOut),
    );

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
      ));

    _loadGameWithNickname();
  }

  Future<void> _loadGameWithNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString('user_nickname') ?? 'Player';
    final uri = Uri.parse(widget.gameUrl);
    final gameUri = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'nickname': nickname,
    });
    controller.loadRequest(gameUri);
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
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
            if (isLoading)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated logo
                      AnimatedBuilder(
                        animation: _loadingAnimationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF667EEA).withValues(alpha: 0.3 + (_pulseAnimation.value - 0.8) * 1.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: SvgPicture.asset(
                                  'assets/logo/playbite_app_icon.svg',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      // Game title
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Loading text
                      Text(
                        'Loading ${widget.title}...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Loading dots animation
                      const LoadingDots(),
                    ],
                  ),
                ),
              ),

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

// ============================================
// SUBMIT GAME SCREEN (Email-based submission)
// ============================================

class SubmitGameScreen extends StatefulWidget {
  final String creatorName;

  const SubmitGameScreen({super.key, required this.creatorName});

  @override
  State<SubmitGameScreen> createState() => _SubmitGameScreenState();
}

class _SubmitGameScreenState extends State<SubmitGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _videoUrlController = TextEditingController();

  bool _isVerifying = false;
  bool _isUrlVerified = false;
  bool _isSubmitting = false;
  String? _verificationError;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _verifyUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _isUrlVerified = false;
      _verificationError = null;
    });

    try {
      // Simple HTTP check to verify the URL is accessible
      final response = await http.head(Uri.parse(url));

      setState(() {
        _isVerifying = false;
        if (response.statusCode >= 200 && response.statusCode < 400) {
          _isUrlVerified = true;
          _verificationError = null;

          // Auto-fill title from URL if empty
          if (_titleController.text.isEmpty) {
            final uri = Uri.parse(url);
            final name = uri.host.split('.').first;
            _titleController.text = _formatName(name);
          }
        } else {
          _isUrlVerified = false;
          _verificationError = 'URL returned status ${response.statusCode}';
        }
      });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _isUrlVerified = false;
        _verificationError = 'Could not reach URL. Please check the link.';
      });
    }
  }

  String _formatName(String name) {
    return name
        .split('-')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }

  Future<void> _submitGame() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isUrlVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your game URL first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await GameService.submitGame(
      title: _titleController.text.trim(),
      gameUrl: _urlController.text.trim(),
      videoUrl: _videoUrlController.text.trim(),
      creator: widget.creatorName,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result != null) {
      _showSuccessDialog(
        'Your game "${_titleController.text.trim()}" is now live on Playbyte! Swipe through the feed to find it.',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit game. Please check your connection and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submission Ready!'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Submit a Game',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Game URL input
              const Text(
                'Game URL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'https://your-game.vercel.app',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _isUrlVerified
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                      ),
                      style: const TextStyle(color: Colors.black),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a URL';
                        }
                        if (!value.startsWith('http')) {
                          return 'Please enter a valid URL';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (_isUrlVerified) {
                          setState(() {
                            _isUrlVerified = false;
                            _verificationError = null;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Verify'),
                  ),
                ],
              ),
              if (_verificationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _verificationError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (_isUrlVerified)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'URL verified!',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),

              // Game Title input
              const Text(
                'Game Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter game title',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.black),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Description input (optional)
              const Text(
                'Description (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Tell players about your game',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.black),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // Video URL input
              const Text(
                'Gameplay Video URL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _videoUrlController,
                decoration: InputDecoration(
                  hintText: 'Direct link to .mp4 or .mov video',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.black),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide a gameplay video URL';
                  }
                  if (!value.startsWith('http')) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Provide a direct link to a .mp4 or .mov gameplay video (15-20 seconds). YouTube links are not supported.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),

              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: (_isUrlVerified && !_isSubmitting) ? _submitGame : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Game',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Info text
              Text(
                'Your game will appear in the feed immediately for all players!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}