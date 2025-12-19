# GameSwipe 🎮

TikTok for Games - Swipe through gameplay videos, swipe left to play instantly.

## How It Works

- **Swipe up/down** → Next/previous video
- **Swipe left** → Play the game instantly (no download)
- **Tap** → Pause/play video

---

## Prerequisites

### 1. Install Flutter SDK

```bash
# Download Flutter
cd ~/dev
git clone https://github.com/flutter/flutter.git -b stable

# Add to PATH (add this line to your ~/.zshrc file)
export PATH="$HOME/dev/flutter/bin:$PATH"

# Apply changes
source ~/.zshrc

# Verify installation
flutter doctor
```

### 2. Install Xcode (for iOS)

1. Download **Xcode** from the Mac App Store
2. Open Xcode once and accept the license
3. Install command line tools:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### 3. Set up iOS Simulator

1. Open Xcode
2. Go to **Xcode → Settings → Platforms**
3. Download **iOS 18** (or latest)

---

## Setup

### 1. Clone the repo

```bash
cd ~/dev
git clone https://github.com/bhargav-deshpande-98/gameswipe-frontend.git
cd gameswipe-frontend
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

If you have multiple devices, specify the simulator:
```bash
flutter devices  # List available devices
flutter run -d "iPhone 16 Pro"  # Run on specific device
```

---

## Project Structure

```
gameswipe-frontend/
├── lib/
│   └── main.dart        # Main app code
├── assets/
│   └── videos/          # Gameplay videos
│       ├── Game1.mov
│       └── Game2.mov
├── pubspec.yaml         # Dependencies & assets
└── README.md
```

---

## Adding New Videos

### 1. Record gameplay

1. Open game in your browser on your phone
2. Start game
3. Begin Recording and record a video for 10sec
4. Save it locally 

### 2. Add to project

```bash
# Copy video to assets folder
cp ~/Desktop/YourVideo.mov assets/videos/

# Update pubspec.yaml if needed (assets/videos/ is already included)
```

### 3. Update main.dart

Add your video to the `videos` list in `lib/main.dart`:

```dart
final videos = [
  {'id': 1, 'title': 'Slither.io', 'video': 'assets/videos/Game1.mov', 'gameUrl': 'http://slither.io'},
  {'id': 2, 'title': 'Game 2', 'video': 'assets/videos/Game2.mov', 'gameUrl': 'http://example.com'},
  // Add new video here:
  {'id': 3, 'title': 'New Game', 'video': 'assets/videos/YourVideo.mov', 'gameUrl': 'http://newgame.com'},
];
```

### 4. Rebuild

```bash
flutter run
```

---

## Troubleshooting

### "CocoaPods not installed"
```bash
sudo gem install cocoapods
```

### "flutter: command not found"
Add Flutter to your PATH in `~/.zshrc`:
```bash
export PATH="$HOME/dev/flutter/bin:$PATH"
```
Then run `source ~/.zshrc`

### Xcode build fails
1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to **Signing & Capabilities**
3. Select your Team under **Signing**
4. Close Xcode and run `flutter run` again

### Still stuck?
```bash
flutter clean
flutter pub get
flutter run
```

---

## Git Workflow

```bash
# Create a new branch for your feature
git checkout -b feature/your-feature-name

# Make changes, then commit
git add .
git commit -m "Add your feature"

# Push to GitHub
git push origin feature/your-feature-name

# Create Pull Request on GitHub
```

---

Built by Varin & Bhargav
