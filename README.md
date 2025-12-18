# GameSwipe App 🎮

Flutter app for GameSwipe - TikTok for Games

## Quick Start

```bash
flutter pub get
flutter run
```

## How It Works

- **Swipe up/down** → Next/previous video
- **Swipe left** → Play the game instantly
- **Tap** → Pause/play video

## Config

Edit the API URL in `lib/main.dart`:

```dart
// Android emulator
const apiUrl = 'http://10.0.2.2:8000';

// iOS simulator  
const apiUrl = 'http://localhost:8000';

// Physical device
const apiUrl = 'http://YOUR_COMPUTER_IP:8000';
```

App works offline with mock data if backend isn't running.
