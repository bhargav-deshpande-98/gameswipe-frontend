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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
  await LikedGamesService.init();
  await RecentlyPlayedService.init();

  runApp(PlaybiteApp(showOnboarding: !onboardingComplete));
}

class PlaybiteApp extends StatelessWidget {
  final bool showOnboarding;
  const PlaybiteApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Playbite',
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
                onPressed: _nickname.length >= 2 ? () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ) : null,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const Text(
                'Swipe up for\nnext game',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 48),
              const SwipeUpAnimation(),
              const Spacer(flex: 2),
              // Chevrons at bottom center
              const PulsingChevrons(),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeLeftTutorialPage() {
    return SlideTransition(
      position: _slideLeftAnimation,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Detect swipe left (negative velocity means leftward)
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            _completeOnboarding();
          }
        },
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const Text(
                'Swipe left to\nstart playing',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 48),
              const SwipeLeftAnimation(),
              const Spacer(flex: 2),
              // Chevrons at left center
              const PulsingLeftChevrons(),
              const Spacer(flex: 1),
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

// ============================================
// SWIPE LEFT ANIMATION
// ============================================

class SwipeLeftAnimation extends StatefulWidget {
  const SwipeLeftAnimation({super.key});

  @override
  State<SwipeLeftAnimation> createState() => _SwipeLeftAnimationState();
}

class _SwipeLeftAnimationState extends State<SwipeLeftAnimation>
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

    // Hand moves LEFT: starts at right (0) and moves left (60)
    _slideAnimation = Tween<double>(begin: 0, end: 60).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Fade out as hand moves left
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
              child: Icon(Icons.videogame_asset, size: 40, color: Colors.grey[500]),
            ),
          ),
          // Animated hand
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                right: 30 + _slideAnimation.value,
                bottom: 60,
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
// PULSING LEFT CHEVRONS
// ============================================

class PulsingLeftChevrons extends StatefulWidget {
  const PulsingLeftChevrons({super.key});

  @override
  State<PulsingLeftChevrons> createState() => _PulsingLeftChevronsState();
}

class _PulsingLeftChevronsState extends State<PulsingLeftChevrons>
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
            offset: Offset(-_controller.value * 5, 0),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_arrow_left, size: 32, color: Colors.grey),
                Icon(Icons.keyboard_arrow_left, size: 32, color: Colors.grey),
              ],
            ),
          ),
        );
      },
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
  bool get _isDarkTheme => _currentIndex == 0; // Home tab is dark, Me tab is light

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Refresh profile screen when navigating to it
    if (index == 1) {
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
          const HomeScreen(),
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
      _gamesPlayed = prefs.getInt('games_played') ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedGamesCount = LikedGamesService.getLikedGames().length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _nickname,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 20),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                  border: Border.all(color: Colors.grey[300]!, width: 1),
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
                color: Colors.black87,
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
                  color: Colors.grey[300],
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
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Edit profile',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Bio placeholder
            Text(
              'Tap to add bio',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
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
                            color: _selectedTab == 0 ? Colors.black : Colors.grey[300]!,
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
                            color: _selectedTab == 0 ? Colors.black : Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Created',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                              color: _selectedTab == 0 ? Colors.black : Colors.grey[500],
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
                            color: _selectedTab == 1 ? Colors.black : Colors.grey[300]!,
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
                            color: _selectedTab == 1 ? Colors.black : Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Recent',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                              color: _selectedTab == 1 ? Colors.black : Colors.grey[500],
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
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  size: 40,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No games played yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Swipe left on games to play them',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _GameThumbnailVideo(videoPath: game['video'] as String),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            game['title'] as String,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
              child: Icon(
                Icons.add,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Build your first game',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No code. Just prompt, create, play.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                // Future functionality
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Make a Game',
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
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
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
}

// ============================================
// GAME THUMBNAIL VIDEO WIDGET
// ============================================

class _GameThumbnailVideo extends StatefulWidget {
  final String videoPath;

  const _GameThumbnailVideo({required this.videoPath});

  @override
  State<_GameThumbnailVideo> createState() => _GameThumbnailVideoState();
}

class _GameThumbnailVideoState extends State<_GameThumbnailVideo> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          // Seek to first frame and pause
          _controller.seekTo(Duration.zero);
          _controller.pause();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
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

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

// ============================================
// RECENTLY PLAYED SERVICE
// ============================================

class RecentlyPlayedService {
  static const String _key = 'recently_played_games';
  static List<int> _recentGameIds = [];
  static const int _maxGames = 10;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];
    _recentGameIds = stored.map((e) => int.parse(e)).toList();
    _initialized = true;
  }

  static Future<void> addGame(int gameId) async {
    // Remove if already exists (to move to front)
    _recentGameIds.remove(gameId);
    // Add to front
    _recentGameIds.insert(0, gameId);
    // Keep only last 3
    if (_recentGameIds.length > _maxGames) {
      _recentGameIds = _recentGameIds.sublist(0, _maxGames);
    }
    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _recentGameIds.map((e) => e.toString()).toList());
  }

  static List<Map<String, dynamic>> getRecentGames() {
    final List<Map<String, dynamic>> result = [];
    for (final id in _recentGameIds) {
      final game = videos.where((v) => v['id'] == id).toList();
      if (game.isNotEmpty) {
        result.add(game.first);
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
    return videos.where((v) => _likedGameIds.contains(v['id'])).toList();
  }
}

// ============================================
// HOME SCREEN WITH TABS
// ============================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
            ? FeedScreen(key: _feedKey, onLikeChanged: _onLikeChanged)
            : LikedGamesScreen(onLikeChanged: _onLikeChanged),
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

final videos = [
  {'id': 1, 'title': 'Slither.io', 'video': 'assets/videos/Game1.mov', 'gameUrl': 'https://slither.io/', 'creator': '@borg'},
  {'id': 2, 'title': 'Bloxd.io', 'video': 'assets/videos/Game2.mov', 'gameUrl': 'https://bloxd.io/', 'creator': '@varin'},
  {'id': 3, 'title': 'Circlify', 'video': 'assets/videos/Game3.mov', 'gameUrl': 'https://circlify-game.vercel.app/', 'creator': '@borg'},
  {'id': 4, 'title': 'aa-speed', 'video': 'assets/videos/Game4.mov', 'gameUrl': 'https://aa-game.vercel.app/', 'creator': '@varin'},
  {'id': 5, 'title': 'Agar', 'video': 'assets/videos/Game5.mov', 'gameUrl': 'https://agar-io-game-pc3l.vercel.app/', 'creator': '@borg'},
  {'id': 6, 'title': 'Crossy Road', 'video': 'assets/videos/Game6.mov', 'gameUrl': 'https://crossy-road-game-lo43.vercel.app/', 'creator': '@varin'},
  {'id': 7, 'title': 'Jumping Cube', 'video': 'assets/videos/Game7.mov', 'gameUrl': 'https://cube-jump-game.vercel.app/', 'creator': '@borg'},
  {'id': 8, 'title': 'Beware of Spikes', 'video': 'assets/videos/Game8.mov', 'gameUrl': 'https://dont-touch-spikes-game.vercel.app/', 'creator': '@varin'},
  {'id': 9, 'title': 'Duet', 'video': 'assets/videos/Game9.mov', 'gameUrl': 'https://duet-game.vercel.app/', 'creator': '@borg'},
  {'id': 10, 'title': 'GSwitch', 'video': 'assets/videos/Game10.mov', 'gameUrl': 'https://gravity-switch-game-kappa.vercel.app/', 'creator': '@varin'},
  {'id': 11, 'title': 'Snake', 'video': 'assets/videos/Game11.mov', 'gameUrl': 'https://slither-io-game.vercel.app/', 'creator': '@borg'},
  {'id': 12, 'title': 'Hero Stick', 'video': 'assets/videos/Game12.mov', 'gameUrl': 'https://stick-hero-game-ten.vercel.app/', 'creator': '@varin'},
  {'id': 13, 'title': 'Jelly Jump', 'video': 'assets/videos/jellyjump.mov', 'gameUrl': 'https://jelly-jump-reborn.vercel.app/', 'creator': '@borg'},
  {'id': 14, 'title': 'Swing Copters', 'video': 'assets/videos/swing_copters.mov', 'gameUrl': 'https://sky-hopper-clone.vercel.app/', 'creator': '@varin'},
  {'id': 15, 'title': 'Masked Escape', 'video': 'assets/videos/masked_escape.mov', 'gameUrl': 'https://masked-escape.vercel.app/', 'creator': '@borg'},
  {'id': 16, 'title': 'Helix Jump', 'video': 'assets/videos/helix_bounce_blitz.mov', 'gameUrl': 'https://helix-bounce-blitz.vercel.app/', 'creator': '@varin'},
  {'id': 17, 'title': 'Icy Tower', 'video': 'assets/videos/icy_tower.mov', 'gameUrl': 'https://tower-jump-mania.vercel.app/', 'creator': '@borg'},
  {'id': 18, 'title': 'Falldown', 'video': 'assets/videos/falldown.mov', 'gameUrl': 'https://fall-down-fun.vercel.app/', 'creator': '@varin'},
  {'id': 19, 'title': 'Color Switch', 'video': 'assets/videos/color_switch.mov', 'gameUrl': 'https://color-tap-mania.vercel.app/', 'creator': '@borg'},
  {'id': 20, 'title': 'Stack Master', 'video': 'assets/videos/stack_master.mov', 'gameUrl': 'https://stack-master-seven.vercel.app/', 'creator': '@varin'},
];

class FeedScreen extends StatefulWidget {
  final VoidCallback? onLikeChanged;
  const FeedScreen({super.key, this.onLikeChanged});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int currentIndex = 0;
  late List<Map<String, dynamic>> shuffledVideos;

  @override
  void initState() {
    super.initState();
    // Create a shuffled copy of videos for randomized feed order
    shuffledVideos = List<Map<String, dynamic>>.from(videos)..shuffle();
  }

  void onSwipeLeft() async {
    final gameId = shuffledVideos[currentIndex]['id'] as int;
    await RecentlyPlayedService.addGame(gameId);

    if (!mounted) return;
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
          onSwipeLeft();
        }
      },
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: shuffledVideos.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          return VideoCard(
            video: shuffledVideos[index],
            isActive: index == currentIndex,
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
  const LikedGamesScreen({super.key, this.onLikeChanged});

  @override
  State<LikedGamesScreen> createState() => _LikedGamesScreenState();
}

class _LikedGamesScreenState extends State<LikedGamesScreen> {
  int currentIndex = 0;

  void onSwipeLeft() async {
    final likedGames = LikedGamesService.getLikedGames();
    if (likedGames.isEmpty) return;

    final gameId = likedGames[currentIndex]['id'] as int;
    await RecentlyPlayedService.addGame(gameId);

    if (!mounted) return;
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
    );
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

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
          onSwipeLeft();
        }
      },
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: likedGames.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          return VideoCard(
            video: likedGames[index],
            isActive: index == currentIndex,
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

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final VoidCallback? onLikeChanged;

  const VideoCard({
    super.key,
    required this.video,
    required this.isActive,
    this.onLikeChanged,
  });

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

  void _toggleLike() async {
    final gameId = widget.video['id'] as int;
    await LikedGamesService.toggleLike(gameId);
    setState(() {});
    widget.onLikeChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final gameId = widget.video['id'] as int;
    final isLiked = LikedGamesService.isLiked(gameId);
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
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    child: isInitialized
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child: VideoPlayer(controller),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator(color: Colors.white)),
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
      ))
      ..loadRequest(Uri.parse(widget.gameUrl));
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
                        'Loading game...',
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