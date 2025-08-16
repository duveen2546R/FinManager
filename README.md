# FinManager: AI-Powered Personal Finance Tracker

**A full-stack, cross-platform personal finance management application built with Flutter and Python. Featuring a conversational AI agent powered by LangChain and Google Gemini to provide intelligent insights, add transactions, and integrate with Siri.**

This application allows users to securely track their income and expenses, visualize financial data, and interact with a smart AI assistant using natural language. The integration with Siri provides a truly hands-free way to manage personal finances.

---

## 🌟 Key Features

*   **Secure User Authentication:** Safe and secure user registration and login using industry-standard password hashing (`bcrypt`).
*   **Comprehensive Transaction Management:** Easily add, view, and track both income and expenses with titles, descriptions, categories, and user-selectable dates.
*   **Dynamic Dashboard:** A beautiful, real-time dashboard that visualizes key financial metrics:
    *   Total Balance (Income - Expenses).
    *   Quick Stats (Daily Average Spend, Highest Single Transaction).
    *   Expense Breakdown Pie Chart with a dynamic, color-coded legend.
    *   Monthly Spending Bar Chart that correctly displays data across different months and years.
*   **Complete Transaction History:** A dedicated screen to view all transactions, complete with powerful filtering (All/Income/Expense) and sorting (Date, Amount). Transactions are grouped by date for readability.
*   **Conversational AI Agent:** A sophisticated chatbot that understands natural language.
    *   **Data Retrieval:** Ask "How much did I spend on Food last month?" or "What was my biggest expense this week?".
    *   **Data Entry:** Add transactions via chat: "Add an expense of 500 rupees for a movie yesterday".
    *   **Financial Advice:** Get intelligent advice, such as "How can I schedule my expenses until the end of the month?".
*   **Voice & System Integration:**
    *   **Speech-to-Text & Text-to-Speech:** Full voice-to-text and text-to-speech capabilities within the app for a hands-free experience.
    *   **Siri Integration (iOS):** Teach Siri new skills with App Intents. Use phrases like, "Hey Siri, ask FinManager what was my biggest expense last month?" to get financial insights without opening the app.
*   **Modern & Responsive UI:** A clean, card-based user interface that works beautifully on both iOS and Android, with full support for user-selectable **Light and Dark Modes**.

---

## 🛠️ Technology Stack

| Area      | Technology / Library                                                              |
| :-------- | :-------------------------------------------------------------------------------- |
| **Frontend**  | **Flutter & Dart** (Cross-platform UI)                                            |
|           | **Swift (iOS Native)** for Siri App Intents integration                           |
|           | `http` (API Communication)                                                        |
|           | `fl_chart` (Beautiful, dynamic charts)                                            |
|           | `speech_to_text` (Voice input)                                                    |
|           | `flutter_tts` (Voice output)                                                      |
|           | `provider` & `shared_preferences` (For theme management)                             |
| **Backend**   | **Python & Flask** (Web Framework)                                                |
|           | **PostgreSQL on AWS RDS** (Cloud-hosted Relational Database)                      |
|           | **LangChain** (AI Agent Framework)                                                |
|           | **Google Gemini Pro** (High-Capability LLM for AI reasoning)                      |
|           | `Flask-Bcrypt` (Password Hashing)                                                 |
|           | `psycopg2-binary` (PostgreSQL Driver)                                             |
|           | `python-dotenv` (Secure API Key & Config Management)                              |

---

## 📸 Screenshots

<!-- 
IMPORTANT: Add screenshots of your app here! Good screenshots are the best way to showcase your work. 
Create a folder named '.github/assets' in your project and place your images there. 
Then, reference them like this:
<img src=".github/assets/login_screen.png" width="200">
-->

| Login Screen | Dashboard | AI Agent with Voice | Siri Integration |
| :---: | :---: | :---: | :---: |
| <img src="" width="200" alt="Login Screen Screenshot"> | <img src="" width="200" alt="Dashboard Screenshot"> | <img src="" width="200" alt="AI Agent Screenshot"> | <img src="" width="200" alt="Siri Integration Screenshot"> |

---

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

You need to have the following software installed on your machine:
*   [Git](https://git-scm.com/)
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable version)
*   [Python](https://www.python.org/downloads/) (version 3.10 or higher)
*   [PostgreSQL](https://www.postgresql.org/download/)
*   **For iOS/Siri:** A Mac with [Xcode](https://developer.apple.com/xcode/) installed.

### ⚙️ Backend Setup

1.  **Clone the repository and `cd` into it.**

2.  **Create and activate a Python virtual environment:**
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    # On Windows, use: venv\Scripts\activate
    ```

3.  **Install Python dependencies from `requirements.txt`:**
    ```bash
    pip install -r requirements.txt
    ```

4.  **Set up the PostgreSQL Database:**
    *   Connect to your local or cloud (e.g., AWS RDS) PostgreSQL instance.
    *   Create a new database and run the `schema.sql` script to create the `users` and `transactions` tables.

5.  **Configure Environment Variables (Crucial):**
    *   You need a permanent API key from [Google AI Studio](https://aistudio.google.com/). It is **highly recommended to enable billing** on the associated Google Cloud project to get a non-expiring key and higher usage limits.
    *   In your project's root directory, create a file named `.env`.
    *   Copy the contents of `.env.example` into this new file.
    *   Open `.env` and fill in all your secret credentials (Google API key and all database details).
    *   **IMPORTANT:** Ensure the `.env` file is listed in your `.gitignore` file to keep your secrets from being committed.

6.  **Run the Flask Server:**
    *   This command automatically loads your `.env` file and makes the server accessible on your local network.
        ```bash
        flask run --host=0.0.0.0
        ```
    *   The backend should now be running on `http://0.0.0.0:5000`.

### 📱 Frontend Setup

1.  **Navigate to the Flutter project folder.**

2.  **Get Flutter dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure the API URL (Most Important Step):**
    *   You **must** replace the placeholder IP address in your Dart files with your computer's local network IP address (or your deployed server's address).
    *   Find your IP on macOS/Linux with `ifconfig` or `ip addr`, and on Windows with `ipconfig`.
    *   Open all files in `lib/Screens/` that make API calls and update the `apiUrl` constant.
    *   **Example:**
        ```dart
        // Change from: 'http://127.0.0.1:5000/...' 
        // To (using your actual IP): 'http://192.168.1.10:5000/...'
        ```
4. **Configure Native Permissions:**
    *   **iOS:** Add `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` keys to `ios/Runner/Info.plist` for voice features.
    *   **Android:** Add `RECORD_AUDIO` permission and a `<queries>` tag to `android/app/src/main/AndroidManifest.xml` for voice features.

6.  **Run the Flutter App:**
    *   Select your target device and run the app.
        ```bash
        flutter run
        ```

---

## 📖 API Endpoints

The backend exposes the following RESTful API endpoints:

| Endpoint                 | Method | Description                                    |
| :----------------------- | :----: | :--------------------------------------------- |
| `/register`              | `POST` | Registers a new user.                          |
| `/login`                 | `POST` | Authenticates a user and returns their details. |
| `/transaction`           | `POST` | Adds a new income or expense transaction.      |
| `/transactions/<user_id>`| `GET`  | Fetches all transactions for a specific user.  |
| `/ai/agent/invoke`       | `POST` | Sends a natural language query to the AI agent. |

---

