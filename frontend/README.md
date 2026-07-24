# FinManager — Flutter Frontend

This is the Flutter port of the FinManager frontend, migrated from the Expo /
React Native app that lived at the repository root (`App.jsx`, `src/`). It talks
to the same unchanged Flask backend (`../backend/app.py`).

## Running

```bash
cd finmanager_app
flutter pub get
flutter run          # pick a device/emulator
```

The backend base URL is configured in `lib/config.dart`
(`http://savorgo.centralindia.cloudapp.azure.com:5001`).

## Architecture / file mapping

The Dart layout mirrors the original RN `src/` tree one-to-one:

| React Native (`src/…`)               | Flutter (`lib/…`)                        |
| ------------------------------------ | ---------------------------------------- |
| `config.js`                          | `config.dart`                            |
| `models.js`                          | `models/transaction.dart`                |
| `storage.js` (AsyncStorage)          | `services/storage.dart` (shared_preferences) |
| `api/client.js` (axios)              | `services/api.dart` (http)               |
| `voice.js` + `expo-speech`           | `services/voice.dart` (speech_to_text + flutter_tts) |
| `utils.js`                           | `utils.dart`                             |
| `theme/ThemeContext.jsx`             | `theme/theme_provider.dart` + `theme/app_colors.dart` |
| `components/Toast.jsx`               | `widgets/toast.dart` (themed SnackBar)   |
| `components/SpendingPieChart.jsx`    | `widgets/spending_pie_chart.dart` (fl_chart) |
| `components/MonthlyBarChart.jsx`     | `widgets/monthly_bar_chart.dart` (fl_chart) |
| auth field styles (inline in RN)     | `widgets/auth_fields.dart`               |
| `App.jsx` (navigation)               | `main.dart` (named routes)               |
| `screens/FirstPageScreen.jsx`        | `screens/first_page_screen.dart`         |
| `screens/LoginScreen.jsx`            | `screens/login_screen.dart`              |
| `screens/RegisterScreen.jsx`         | `screens/register_screen.dart`           |
| `screens/HomeScreen.jsx`             | `screens/home_screen.dart`               |
| `screens/AddTransactionScreen.jsx`   | `screens/add_transaction_screen.dart`    |
| `screens/AiAgentScreen.jsx`          | `screens/ai_agent_screen.dart`           |
| `screens/AllTransactionsScreen.jsx`  | `screens/all_transactions_screen.dart`   |
| `screens/AccountScreen.jsx`          | `screens/account_screen.dart`            |

## Package equivalents

| RN dependency                          | Flutter package    |
| -------------------------------------- | ------------------ |
| axios                                  | http               |
| @react-native-async-storage            | shared_preferences |
| React context (theme)                  | provider           |
| react-native-chart-kit                 | fl_chart           |
| react-native-markdown-display          | flutter_markdown   |
| @expo/vector-icons (Ionicons)          | ionicons           |
| @react-navigation                      | Navigator (named routes) |
| expo-speech-recognition                | speech_to_text     |
| expo-speech                            | flutter_tts        |
| @react-native-community/datetimepicker | showDatePicker     |

## Notes

- Navigation state (`user_id`, transactions) is passed via typed route
  argument classes (`HomeArgs`, `AddTransactionArgs`, etc.).
- The AI answers render Markdown; user bubbles are plain text — matching the RN
  behaviour.
- Voice input degrades gracefully: the mic button only appears when the device
  reports speech recognition is available.
- Native permissions (microphone, cleartext HTTP) are configured in
  `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.
