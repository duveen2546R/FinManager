# FinManager — AI-Powered Personal Finance

FinManager is a cross-platform personal-finance app: a **Flutter** client (iOS,
Android, and web) backed by a **Python / Flask** API with a conversational AI
assistant, deterministic spending insights, and CSV statement imports. The UI is
a clean, light "neobank" design — flat white cards, a lime accent, and bold
typography — with a full dark mode.

---

## ✨ Features

**Accounts & security**
- Email/password **registration and login** with `bcrypt` hashing.
- **JWT** access + refresh tokens; tokens stored in encrypted device storage and
  auto-refreshed. Server-side **logout** revokes the token.
- **Forgot / reset password** via a one-time emailed code.
- **Delete account** (password-confirmed) and **export my data**.

**Money tracking**
- **Add, edit, and delete** income and expenses (title, amount, category,
  date, description).
- Strict category sets — Expense: Food, Travel, Bills, Shopping, Rent, Others;
  Income: Salary, Bonus, Gift, Investment, Others.
- **Dashboard** — a bold balance card (with a hide/show toggle), a horizontal
  stat rail (income, spending, daily average, highest), an **expense-breakdown
  pie chart**, a **monthly-spending bar chart**, and recent transactions.
- **Activity** screen — full history grouped by date, with **sort** (newest /
  oldest / amount) and **filter** (all / income / expense), expandable notes,
  and per-row **edit / delete**.

**AI assistant**
- A multi-turn chat that **answers questions about your money** from a
  server-computed snapshot (balances, recent activity, category spend) — it
  never guesses numbers.
- **Adds transactions from natural language** — e.g. "add a ₹500 expense for a
  movie ticket." If details are missing it **asks follow-up questions**, then
  records the transaction and **auto-categorizes** it into the allowed set.
- **Voice input** (speech-to-text) and optional **spoken replies**
  (text-to-speech). Chats are saved as **sessions** you can revisit.

**Insights & planning**
- **Deterministic, evidence-backed expense insights** (e.g. likely
  subscriptions, spending spikes, upcoming commitments) with thumbs-up /
  not-right / dismiss feedback.
- **Spending guidance** — a "safe to spend this week" allowance derived from
  your own history.
- **Recurring commitments** and **merchant rules** (auto-rename / auto-categorize
  recurring merchants) under *Expense setup*.

**Imports**
- **CSV statement import** — pick a file, review the parsed rows (duplicates are
  detected and excluded), then confirm which become transactions.

**Experience**
- **Light / dark / system** theme, persisted on device.
- **Responsive** — a phone-first UI that stays a centered, phone-width panel on
  web, tablets, and laptops.

---

## 🧱 Tech stack

| Area | Technology |
| :--- | :--- |
| **Client** | Flutter (Dart, SDK ≥ 3.10) — iOS · Android · Web |
| | `provider` state · `http` · `flutter_secure_storage` + `shared_preferences` |
| | `fl_chart` · `flutter_markdown` · `ionicons` · `intl` |
| | `speech_to_text` (voice in) · `flutter_tts` (voice out) · `file_selector` + `csv` (imports) |
| **API** | Python + Flask, `Flask-JWT-Extended`, `Flask-Bcrypt`, `Flask-Cors`, `Flask-Limiter` |
| | PostgreSQL (`psycopg2-binary`) |
| | AI chat via **Groq** (`langchain-groq`, `llama-3.3-70b-versatile`) |
| | Deterministic insight engine (`expense_intelligence.py`) |
| | `gunicorn` (production WSGI), `python-dotenv` |

---

## 📁 Project structure

```
FinManager/
├── frontend/                    # Flutter app (iOS · Android · Web)
│   ├── lib/
│   │   ├── main.dart            # entry, theme, routes, responsive wrapper
│   │   ├── config.dart          # ← backend base URL
│   │   ├── models/              # transaction, insight, chat, expense-setup
│   │   ├── services/            # api (JWT client), storage, voice
│   │   ├── theme/               # colors + theme provider
│   │   ├── widgets/             # cards, charts, nav, inputs, toast
│   │   └── screens/             # first, login, register, forgot-password,
│   │                            #   home, add/edit txn, activity, AI chat,
│   │                            #   chat history, expense setup, import, account
│   ├── assets/                  # logo + app icon
│   └── pubspec.yaml
│
└── backend/                     # Flask API
    ├── app.py                   # routes, auth, transactions, chat, imports
    ├── expense_intelligence.py  # deterministic insight/story engine
    ├── Schema.sql               # full schema (fresh database)
    ├── migrations/              # incremental SQL migrations
    ├── tests/                   # pytest suite
    ├── requirements.txt
    └── .env.example
```

---

## 🚀 Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.10+ (Dart bundled)
- Python 3.10+ and PostgreSQL
- For device builds / voice: Xcode (iOS) or Android Studio (Android).
  Run `flutter doctor` to check your toolchains.

### 1. Backend (Flask API)

```bash
cd backend

python3 -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Configure secrets — copy `.env.example` → `.env` and fill in:

```
DB_HOST / DB_NAME / DB_USER / DB_PASSWORD / DB_PORT   # PostgreSQL
DB_URI=postgresql+psycopg2://user:pass@host:5432/finmanager
JWT_SECRET_KEY   # python -c "import secrets; print(secrets.token_urlsafe(48))"
GROQ_API_KEY     # optional — enables the LLM assistant
CORS_ORIGINS     # web origins only (e.g. http://localhost:3000); inert for mobile
# Optional email (password reset / welcome): BREVO_API_KEY, MAIL_FROM
```

Create the database tables (choose one):

```bash
psql -d finmanager -f Schema.sql                                 # new database
psql -d finmanager -f migrations/0001_expense_intelligence.sql   # existing database
```

Run it:

```bash
python app.py                        # dev server on http://0.0.0.0:5001
# or, production:
gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --threads 4 --timeout 120
```

Run the tests:

```bash
python -m pytest tests -q            # from the backend/ directory
```

### 2. Frontend (Flutter)

```bash
cd frontend
flutter pub get
```

Point the app at your API — edit `lib/config.dart`:

```dart
// Use your machine's LAN IP (not 127.0.0.1) so a physical device can reach it,
// or your deployed URL.
static const String baseUrl = 'http://192.168.1.10:5001';
```

Run it:

```bash
flutter run                 # pick a connected device or emulator
flutter run -d chrome       # run in a browser (web / laptop)
```

Build releases:

```bash
flutter build apk           # Android
flutter build ios           # iOS
flutter build web           # Web → build/web/
```

> **Cleartext HTTP:** if your API is served over `http://`, the app already
> includes the iOS/Android exceptions needed for local development. Serve the
> API over **HTTPS** in production.
>
> **Voice permissions:** microphone + speech usage descriptions are configured
> in the iOS `Info.plist` and Android manifest. The mic button appears only when
> the device reports speech recognition is available.

---

## 📖 API overview

All private routes require `Authorization: Bearer <access_token>`; ownership is
derived from the token (no user id is sent by the client).

| Endpoint | Method | Description |
| :--- | :---: | :--- |
| `/auth/register`, `/auth/login` | `POST` | Create account / sign in → access + refresh tokens |
| `/auth/refresh` | `POST` | Exchange a refresh token for a new access token |
| `/auth/logout` | `POST` | Revoke the current token |
| `/auth/forgot-password`, `/auth/reset-password` | `POST` | Emailed reset-code flow |
| `/transactions` | `GET`/`POST` | List (paginated) / add a transaction |
| `/transactions/<id>` | `GET`/`PATCH`/`DELETE` | Read / edit / delete a transaction |
| `/ai/agent/invoke`, `/chat/sessions/<id>/messages` | `POST` | Chat with the assistant (answers + adds transactions) |
| `/chat/sessions`, `/chat/sessions/<id>` | `GET`/`POST`/`PATCH`/`DELETE` | Manage chat sessions & history |
| `/expense-insights`, `/expense-insights/<id>/feedback` | `GET`/`POST` | Insights + feedback |
| `/expense-story`, `/expense-guidance` | `GET` | Narrative summary / weekly allowance |
| `/commitments`, `/commitments/<id>` | `GET`/`POST`/`PATCH`/`DELETE` | Recurring commitments |
| `/merchant-rules`, `/merchant-rules/<id>` | `GET`/`POST`/`DELETE` | Merchant auto-categorization rules |
| `/imports`, `/imports/<id>`, `/imports/<id>/confirm` | `POST`/`GET`/`POST` | CSV import review & confirm |
| `/me`, `/me/export` | `DELETE`/`GET` | Delete account / export data |

---

## ☁️ Deployment notes

- **Backend** deploys cleanly to any Python host (e.g. Render) with build
  `pip install -r requirements.txt` and start
  `gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --threads 4 --timeout 120`.
  Set `FLASK_ENV=production` and a real `JWT_SECRET_KEY`; run the schema on the
  database before first use.
- **Web build** pins Flutter 3.10+; if a build host installs a much newer
  Flutter, pin the toolchain version in your build command.
- Update `frontend/lib/config.dart` `baseUrl` to your deployed API URL. For web
  deployments, add the site's origin to the backend `CORS_ORIGINS`.

---

## 🛠️ Troubleshooting

- **Login/500 right after setup** — the database tables aren't created yet; run
  `Schema.sql` (or the migration).
- **Can't reach the API from a device** — use your machine's LAN IP in
  `config.dart` (not `localhost`), on the same network, with the API bound to
  `0.0.0.0`.
- **AI assistant gives generic answers** — set `GROQ_API_KEY`; without it the
  assistant falls back to a deterministic summary.
- **Voice mic missing** — the device needs an available speech-recognition
  service and granted microphone permission.

---

## 📄 License

Available for educational and personal use.

## 👨‍💻 Author

Created with ❤️ by Duveen Kumar Reddy R — give the repo a ⭐️ if it helped you!
