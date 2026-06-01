# flutter_application_1

A new Flutter project.

## WC2026 API key configuration

This app reads the API key from a compile-time variable named `WC2026_API_KEY`.

Run locally:

```bash
flutter run --dart-define=WC2026_API_KEY=your_key_here
```

Build APK:

```bash
flutter build apk --dart-define=WC2026_API_KEY=your_key_here
```

Build App Bundle:

```bash
flutter build appbundle --dart-define=WC2026_API_KEY=your_key_here
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
