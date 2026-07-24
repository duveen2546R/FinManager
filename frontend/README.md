# FinManager — Flutter client

The FinManager app for **iOS, Android, and web**. A light "neobank" UI (flat
white cards, lime accent, bold type) with a full dark mode, talking to the Flask
API in [`../backend`](../backend).

## Run

```bash
flutter pub get
flutter run            # a connected device / emulator
flutter run -d chrome  # in a browser
```

Set the API URL in [`lib/config.dart`](lib/config.dart):

```dart
static const String baseUrl = 'http://192.168.1.10:5001';  // LAN IP or deployed URL
```

## Build

```bash
flutter build apk      # Android
flutter build ios      # iOS
flutter build web      # Web → build/web/
```

## Layout

```
lib/
├── main.dart          # entry, theme, routes, responsive wrapper
├── config.dart        # backend base URL
├── models/            # transaction, insight, chat, expense-setup
├── services/          # api (JWT client + auto-refresh), storage, voice
├── theme/             # colors, theme provider (light/dark/system)
├── widgets/           # cards, charts, bottom nav, inputs, toast
└── screens/           # first, login, register, forgot-password, home,
                       #   add/edit transaction, activity, AI chat, chat
                       #   history, expense setup, CSV import, account
```

## Notes

- **Auth**: JWT access/refresh tokens in encrypted storage, auto-refreshed on
  401; expired sessions return to the landing screen.
- **Responsive**: phone-first; on web/tablet/desktop it renders as a centered,
  phone-width panel.
- **App icon**: regenerate from `assets/icon.png` with
  `dart run flutter_launcher_icons`.
- **Native permissions** (microphone, cleartext HTTP for local dev) are set in
  `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml`.
