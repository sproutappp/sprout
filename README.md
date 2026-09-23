# Flutter

A modern Flutter-based mobile application utilizing the latest mobile development technologies and tools for building responsive cross-platform applications.

## 📋 Prerequisites

- Flutter SDK (^3.38.4)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Android SDK / Xcode (for iOS development)
- A free [Supabase](https://supabase.com) project

## 🗄️ Backend setup (Supabase)

1. Create a project at [supabase.com](https://supabase.com).
2. In the Supabase Dashboard, open **SQL Editor** and run the contents of
   `supabase/schema.sql` — this creates the `profiles`, `circles`,
   `circle_members`, `memories` tables, all RLS policies, and the
   `memories` storage bucket.
3. In **Project Settings > API**, copy your Project URL and `anon` public key.
4. Fill them into `env.json` at the repo root:
   ```json
   {
       "SUPABASE_URL": "https://your-project.supabase.co",
       "SUPABASE_ANON_KEY": "your-anon-key"
   }
   ```
   `env.json` is git-ignored — never commit real keys.
5. (Optional, for Google sign-in) In **Authentication > Providers**, enable
   Google and configure the redirect URL.

## 🛠️ Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Run the application (note the `--dart-define-from-file` flag — this is
   how `env.json` gets loaded; the app throws a clear error on startup if
   it's missing):
```bash
flutter run --dart-define-from-file=env.json
```

## 📁 Project Structure

```
flutter_app/
├── android/            # Android-specific configuration
├── ios/                # iOS-specific configuration
├── lib/
│   ├── core/           # Core utilities and services
│   │   └── utils/      # Utility classes
│   ├── presentation/   # UI screens and widgets
│   │   └── splash_screen/ # Splash screen implementation
│   ├── routes/         # Application routing
│   ├── theme/          # Theme configuration
│   ├── widgets/        # Reusable UI components
│   └── main.dart       # Application entry point
├── assets/             # Static assets (images, fonts, etc.)
├── pubspec.yaml        # Project dependencies and configuration
└── README.md           # Project documentation
```

## 🧩 Adding Routes

To add new routes to the application, update the `lib/routes/app_routes.dart` file:

```dart
import 'package:flutter/material.dart';
import 'package:package_name/presentation/home_screen/home_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String home = '/home';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    home: (context) => const HomeScreen(),
    // Add more routes as needed
  }
}
```

## 🎨 Theming

This project includes a comprehensive theming system with both light and dark themes:

```dart
// Access the current theme
ThemeData theme = Theme.of(context);

// Use theme colors
Color primaryColor = theme.colorScheme.primary;
```

The theme configuration includes:
- Color schemes for light and dark modes
- Typography styles
- Button themes
- Input decoration themes
- Card and dialog themes

## 📱 Responsive Design

The app is built with responsive design using the Sizer package:

```dart
// Example of responsive sizing
Container(
  width: 50.w, // 50% of screen width
  height: 20.h, // 20% of screen height
  child: Text('Responsive Container'),
)
```
## 📦 Deployment

Build the application for production:

```bash
# For Android
flutter build apk --release --dart-define-from-file=env.json

# For iOS
flutter build ios --release --dart-define-from-file=env.json
```

## 🙏 Acknowledgments
- Built with [Rocket.new](https://rocket.new)
- Powered by [Flutter](https://flutter.dev) & [Dart](https://dart.dev)
- Styled with Material Design

Built with ❤️ on Rocket.new
