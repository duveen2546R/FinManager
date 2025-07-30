# FinManager: AI-Powered Personal Finance Tracker

**A full-stack, cross-platform personal finance management application built with Flutter and a powerful Python backend. Featuring a conversational AI agent powered by LangChain and Groq to provide intelligent insights into your spending habits.**

---

## 🌟 Key Features

*   **Secure User Authentication:** Safe and secure user registration and login using industry-standard password hashing.
*   **Comprehensive Transaction Management:** Easily add, view, and track both income and expenses with titles, descriptions, categories, and dates.
*   **Dynamic Dashboard:** A beautiful, real-time dashboard that visualizes key financial metrics:
    *   Total Balance
    *   Quick Stats (Daily Average, Highest Spend)
    *   Expense Breakdown Pie Chart with a dynamic legend.
    *   Monthly Spending Bar Chart.
*   **Complete Transaction History:** A dedicated screen to view all transactions, complete with powerful filtering (All/Income/Expense) and sorting (Date, Amount).
*   **Conversational AI Agent:** Interact with your finances using natural language!
    *   Ask questions like "How much did I spend on Food last month?" or "What was my biggest expense this week?".
    *   Get intelligent advice, such as "How can I schedule my expenses until the end of the month?".
    *   Features **Speech-to-Text** and **Text-to-Speech** for a hands-free, conversational experience.
*   **Modern & Responsive UI:** A clean, card-based user interface that works beautifully on both iOS and Android, with full support for both light and dark modes.

---

## 🛠️ Technology Stack

| Area      | Technology / Library                                                              |
| :-------- | :-------------------------------------------------------------------------------- |
| **Frontend**  | **Flutter & Dart** (Cross-platform UI)                                            |
|           | `http` (API Communication)                                                        |
|           | `fl_chart` (Beautiful, dynamic charts)                                            |
|           | `speech_to_text` (Voice input)                                                    |
|           | `flutter_tts` (Voice output)                                                      |
|           | `intl` (Date formatting)                                                          |
| **Backend**   | **Python & Flask** (Web Framework)                                                |
|           | **PostgreSQL** (Relational Database)                                              |
|           | **LangChain** (AI Agent Framework)                                                |
|           | **Groq** with **Llama 3** (Free, High-Speed LLM for AI reasoning)                   |
|           | `Flask-Bcrypt` (Password Hashing)                                                 |
|           | `psycopg2-binary` (PostgreSQL Driver)                                             |

---

## 📸 Screenshots

<!-- 
IMPORTANT: Add screenshots of your app here! Good screenshots are the best way to showcase your work. 
Create a folder named '.github/assets' in your project and place your images there. 
Then, reference them like this:
<img src=".github/assets/login_screen.png" width="200">
-->

| Login Screen | Dashboard | All Transactions | AI Agent |
| :---: | :---: | :---: | :---: |
| <img src="" width="200" alt="Login Screen Screenshot"> | <img src="" width="200" alt="Dashboard Screenshot"> | <img src="" width="200" alt="Transactions Screenshot"> | <img src="" width="200" alt="AI Agent Screenshot"> |

---

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

You need to have the following software installed on your machine:
*   [Git](https://git-scm.com/)
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable version)
*   [Python](https://www.python.org/downloads/) (version 3.10 or higher)
*   [PostgreSQL](https://www.postgresql.org/download/)

### ⚙️ Backend Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/finmanager.git
    cd finmanager
    ```

2.  **Create and activate a Python virtual environment:**
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    # On Windows, use: venv\Scripts\activate
    ```

3.  **Install Python dependencies:**
    *(It is recommended to create a `requirements.txt` file by running `pip freeze > requirements.txt` in your project)*
    ```bash
    pip install Flask Flask-Cors Flask-Bcrypt psycopg2-binary langchain langchain-community langchain-groq
    ```

4.  **Set up the PostgreSQL Database:**
    *   Start your PostgreSQL server.
    *   Create a new database and run the schema script provided in the project to create the `users` and `transactions` tables.

5.  **Configure Environment Variables (Crucial):**
    *   You need a free API key from [Groq](https://console.groq.com/).
    *   Set the key as an environment variable in your terminal before running the server.
        ```bash
        export GROQ_API_KEY="gsk_YourGroqApiKeyGoesHere"
        ```
    *   **For a permanent solution**, add this `export` command to your shell's startup file (`~/.zshrc` or `~/.bash_profile`).

6.  **Run the Flask Server:**
    *   This command makes the server accessible on your local network, which is required for the mobile app to connect.
        ```bash
        flask run --host=0.0.0.0
        ```
    *   The backend should now be running on `http://0.0.0.0:5000`.

### 📱 Frontend Setup

1.  **Navigate to the Flutter project:**
    *   Open a new terminal and navigate to the root of the Flutter project.

2.  **Get Flutter dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure the API URL (Most Important Step):**
    *   You **must** replace the placeholder IP address in your Dart files with your computer's local network IP address.
    *   Find your IP on macOS/Linux with `ifconfig` or `ip addr`, and on Windows with `ipconfig`.
    *   Open the following files and update the `apiUrl` constant:
        *   `lib/Screens/login.dart`
        *   `lib/Screens/register.dart`
        *   `lib/Screens/home_screen.dart`
        *   `lib/Screens/add_transaction_screen.dart`
        *   `lib/Screens/ai_agent_screen.dart`
    *   **Example:**
        ```dart
        // Change this:
        const String apiUrl = 'http://127.0.0.1:5000/...'; 
        // To this (using your actual IP):
        const String apiUrl = 'http://192.168.1.10:5000/...';
        ```
4. **Configure Native Permissions for Voice Features:**
    *   **iOS:** Add `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` keys to `ios/Runner/Info.plist`.
    *   **Android:** Add `RECORD_AUDIO` permission and a `<queries>` tag to `android/app/src/main/AndroidManifest.xml`.

5.  **Run the Flutter App:**
    *   Select your target device (emulator or physical device) and run the app.
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

## 🚧 Future Work / Roadmap

This project has a solid foundation, but there are many exciting features that could be added:

*   [ ] **Budgeting Module:** Allow users to set monthly budgets per category and track their spending against them.
*   [ ] **Multiple Accounts:** Enable users to add and manage multiple financial accounts (e.g., Checking, Savings, Credit Card).
*   [ ] **Savings Goals:** A feature to set and track progress towards specific savings goals.
*   [ ] **Recurring Transactions:** Allow users to schedule recurring income and expenses (e.g., salary, rent).
*   [ ] **Advanced AI Insights:** Enhance the AI agent to provide proactive insights, like "You've spent 80% of your food budget this month" or "Your travel spending is higher than usual."

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/your-username/finmanager/issues).

---

## 📜 License

This project is licensed under the MIT License - see the `LICENSE` file for details.
