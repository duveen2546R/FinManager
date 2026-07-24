# FinManager backend API

## Setup

1. Copy `.env.example` to `.env`, configure PostgreSQL, a long `JWT_SECRET_KEY`, and the production Flutter/web origins in `CORS_ORIGINS`.
2. Install dependencies with `python3 -m pip install -r requirements.txt` in a virtual environment.
3. For a new database, run `Schema.sql`. For the pre-release database, run `migrations/0001_expense_intelligence.sql` once.
4. Start the service with `python app.py`.

## Client contract

`POST /auth/register` and `POST /auth/login` return an access and refresh token.
Send every private request with `Authorization: Bearer <access_token>`. The app must use `GET /transactions`, not `/transactions/<user_id>`; ownership is inferred by the API.

Imports submit already parsed, structured rows to `POST /imports`; raw statements and raw SMS text are intentionally not stored. Review rows with `POST /imports/{import_id}/confirm` before they become transactions.

The expense-insight endpoints are deterministic and include evidence for each finding:

- `GET /expense-insights`
- `POST /expense-insights/{insight_id}/feedback`
- `GET /expense-story`
- `GET /expense-guidance`

## Multi-turn AI chats

Create a session with `POST /chat/sessions`, reopen its history with
`GET /chat/sessions/{session_id}/messages`, and send a follow-up with
`POST /chat/sessions/{session_id}/messages` using `{ "message": "..." }`.
The existing `POST /ai/agent/invoke` endpoint also accepts `question` or
`message` plus an optional `session_id`; it creates a session when absent and
returns the stored session and both messages. Chats are included in data export
and cascade-delete with the account.

## Test

Run `python3 -m pytest backend/tests -q` from the repository root.
