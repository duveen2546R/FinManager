# FinManager — AI-Powered Personal Finance Tracker

A full-stack, cross-platform personal finance app. The mobile client is built with
**Flutter (Dart)** and talks to a **Python / Flask** backend that includes a
conversational AI agent (LangChain + Groq) for querying and adding transactions in
natural language — including voice input and spoken replies.

> **Migration note:** The frontend has been migrated **React Native (Expo) → Flutter**,
> and now lives in [`frontend/`](frontend/). The old Expo/RN sources have
> been removed. The Flask backend and PostgreSQL schema are **unchanged** by the
> migration. See [`frontend/README.md`](frontend/README.md) for a full
> RN → Flutter file-and-package mapping.

---

## 🌟 Features

- **Secure auth** — registration & login with `bcrypt` password hashing.
- **Transactions** — add/track income & expenses with title, description, category, amount, and date.
- **Dashboard** — total balance, daily average & highest spend, an expense-breakdown **pie chart**, and a **monthly-spending bar chart**.
- **History** — all transactions grouped by date, with filtering (All / Income / Expense) and sorting (date, amount) and expandable descriptions.
- **Conversational AI agent** — ask "How much did I spend on Food last month?" or say "Add a ₹500 expense for a movie ticket."
- **Voice** — speech-to-text input (`speech_to_text`) and text-to-speech replies (`flutter_tts`).
- **Theming** — light / dark / system modes, persisted on-device.

---

## 🧱 Tech Stack

| Area | Technology |
| :--- | :--- |
| **Frontend** | Flutter (Dart, SDK ≥ 3.10) |
| | Navigator with named routes + typed route arguments |
| | `http` · `fl_chart` · `flutter_markdown` · `ionicons` |
| | `speech_to_text` (STT) · `flutter_tts` (TTS) |
| | `provider` + `shared_preferences` (theme & session) |
| **Backend** | Python + Flask, `Flask-Cors`, `Flask-Bcrypt` |
| | PostgreSQL (`psycopg2-binary`) |
| | LangChain agent + **Groq** (`llama-3.3-70b-versatile`) |
| | `python-dotenv` for config |

---

## 📁 Project Structure

```
FinManager/
├── frontend/              # ← Flutter frontend (the app)
│   ├── lib/
│   │   ├── main.dart            # App entry, theme, named-route table
│   │   ├── config.dart          # ← Backend API base URL lives here
│   │   ├── models/transaction.dart
│   │   ├── services/            # api.dart, storage.dart, voice.dart
│   │   ├── theme/               # theme_provider.dart, app_colors.dart
│   │   ├── utils.dart
│   │   ├── widgets/             # toast, spending_pie_chart, monthly_bar_chart, auth_fields
│   │   └── screens/             # FirstPage, Login, Register, Home, AddTransaction,
│   │                            #   AiAgent, AllTransactions, Account
│   ├── assets/                  # Images & app icon
│   ├── android/  ios/           # Native projects (committed; hold permissions config)
│   ├── pubspec.yaml
│   └── README.md                # RN → Flutter file/package mapping
│
└── backend/                     # Python / Flask API (unchanged by the migration)
    ├── app.py
    ├── Schema.sql
    ├── requirements.txt
    └── .env.example
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.10+ (Dart is bundled)
- [Python](https://www.python.org/) 3.10+ and PostgreSQL
- **For device builds / voice:** Xcode (iOS) or Android Studio (Android).
  Run `flutter doctor` to verify your toolchains.

### 1. Backend (Flask API)

```bash
cd backend

python3 -m venv venv
source venv/bin/activate            # Windows: venv\Scripts\activate

pip install -r requirements.txt
```

- **Database:** create a PostgreSQL database and run `Schema.sql` to create the `customers` and `transactions` tables.
- **Secrets:** copy `backend/.env.example` → `backend/.env` and fill in your PostgreSQL credentials (`DB_*`, `DB_URI`) and your `GROQ_API_KEY`. Never commit `.env` — it's gitignored.
- **Run it:**

  ```bash
  python app.py
  ```

  The server listens on `http://0.0.0.0:5001`.

### 2. Frontend (Flutter)

```bash
cd frontend
flutter pub get
```

**Point the app at your backend** — edit `lib/config.dart`:

```dart
// Use your machine's LAN IP (not 127.0.0.1) so a device/simulator can reach it.
static const String baseUrl = 'http://192.168.1.10:5001';
```

**Run it:**

```bash
flutter run            # pick a connected device or emulator
```

Build release binaries with `flutter build apk` (Android) or `flutter build ios` (iOS).

> **Cleartext HTTP:** the app targets an `http://` backend, and iOS/Android block
> cleartext by default. The needed exceptions are already configured
> (`NSAllowsArbitraryLoads` in `ios/Runner/Info.plist`, `usesCleartextTraffic` in
> `android/app/src/main/AndroidManifest.xml`). For production, serve the backend
> over **HTTPS** instead.

> **Voice permissions:** microphone + speech-recognition usage descriptions are set
> in `ios/Runner/Info.plist`, and `RECORD_AUDIO` (plus recognition/TTS `<queries>`)
> in the Android manifest. The mic button appears only when the device reports that
> speech recognition is available.

---

## 📖 API Endpoints

| Endpoint | Method | Description |
| :--- | :---: | :--- |
| `/register` | `POST` | Register a new user |
| `/login` | `POST` | Authenticate and return user details |
| `/transaction` | `POST` | Add an income or expense transaction |
| `/transactions/<user_id>` | `GET` | Fetch all transactions for a user |
| `/ai/agent/invoke` | `POST` | Send a natural-language query to the AI agent |

---

## 🛠️ Troubleshooting

**`flutter pub get` fails / dependency version conflicts.**
Ensure your Flutter SDK is 3.10+ (`flutter --version`). Run `flutter clean` then
`flutter pub get` if a stale build is interfering.

**AI agent import error (`No module named 'langchain_groq'`).**
Make sure `langchain-groq` is installed (it's in `requirements.txt`); the agent in
`app.py` uses Groq, not Google Gemini.

**Voice mic button missing / no transcription.** The device or emulator must have a
speech-recognition service available and the microphone permission granted. On a
fresh iOS simulator, enable a keyboard/dictation locale; on Android, ensure a
recognition service (e.g. Google) is present.

**Can't reach the backend from a device.** Use your machine's LAN IP in
`lib/config.dart` (not `127.0.0.1`/`localhost`), and make sure both are on the same
network and the backend is bound to `0.0.0.0`.

---

## 📄 License

Available for educational and personal use.

## 👨‍💻 Author

Created with ❤️ by Duveen Kumar Reddy R — give the repo a ⭐️ if it helped you!
