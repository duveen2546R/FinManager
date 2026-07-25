"""FinManager expense-intelligence API.

Every private route derives ownership from a bearer token.  No route trusts a
user id supplied by the mobile client, and expense insights are deterministic
and evidence-backed rather than model-generated database queries.
"""

from __future__ import annotations

import hashlib
import html
import json
import os
import re
import secrets
import uuid
from contextlib import contextmanager
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from functools import wraps
from typing import Any, Iterator
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import psycopg2
from dotenv import load_dotenv
from flask import Flask, g, jsonify, request
from flask_bcrypt import Bcrypt
from flask_cors import CORS
from flask_jwt_extended import (
    JWTManager,
    create_access_token,
    create_refresh_token,
    get_jwt,
    get_jwt_identity,
    jwt_required,
)
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from psycopg2.extras import RealDictCursor

try:  # Supports both `python backend/app.py` and `flask --app backend.app`.
    from .expense_intelligence import build_expense_insights, build_expense_story
except ImportError:  # pragma: no cover - direct-script fallback
    from expense_intelligence import build_expense_insights, build_expense_story

load_dotenv()

EXPENSE_CATEGORIES = {"Food", "Travel", "Bills", "Shopping", "Rent", "Others"}
INCOME_CATEGORIES = {"Salary", "Bonus", "Gift", "Investment", "Others"}
TRANSACTION_SOURCES = {"Manual", "CSVImport", "BankStatementPDF", "FinancialSMS", "AI"}
IMPORT_SOURCES = {"CSVImport", "BankStatementPDF", "FinancialSMS"}
FREQUENCIES = {"weekly", "monthly", "quarterly", "yearly"}
INSIGHT_FEEDBACK = {"helpful", "incorrect", "expected", "ignored"}


class ApiError(Exception):
    def __init__(self, message: str, status: int = 400, code: str = "bad_request"):
        self.message = message
        self.status = status
        self.code = code
        super().__init__(message)


def _origins() -> list[str]:
    configured = os.getenv("CORS_ORIGINS", "").strip()
    if configured:
        return [origin.strip() for origin in configured.split(",") if origin.strip()]
    # Explicit local defaults are safer than an unrestricted CORS wildcard.
    return ["http://localhost:3000", "http://localhost:5000"]


app = Flask(__name__)
app.config.update(
    JWT_SECRET_KEY=os.getenv("JWT_SECRET_KEY", "development-only-change-me"),
    JWT_ACCESS_TOKEN_EXPIRES=timedelta(minutes=30),
    JWT_REFRESH_TOKEN_EXPIRES=timedelta(days=30),
    JWT_TOKEN_LOCATION=["headers"],
    JSON_SORT_KEYS=False,
)
CORS(app, resources={r"/*": {"origins": _origins()}}, supports_credentials=False)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)
limiter = Limiter(
    key_func=get_remote_address,
    app=app,
    default_limits=["240 per hour"],
    storage_uri=os.getenv("RATE_LIMIT_STORAGE_URI", "memory://"),
)


def get_db_connection():
    # Render exposes PostgreSQL as one connection string. Local development can
    # continue using the individual DB_* variables below.
    if database_url := os.getenv("DATABASE_URL"):
        return psycopg2.connect(database_url)
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        database=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        port=os.getenv("DB_PORT", "5432"),
    )


@contextmanager
def db_cursor() -> Iterator[tuple[Any, RealDictCursor]]:
    connection = get_db_connection()
    cursor = connection.cursor(cursor_factory=RealDictCursor)
    try:
        yield connection, cursor
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        connection.close()


def _json(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, dict):
        return {key: _json(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json(item) for item in value]
    return value


def _response(payload: dict[str, Any], status: int = 200):
    return jsonify(_json({"status": "success", **payload})), status


def _request_json() -> dict[str, Any]:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise ApiError("A JSON object is required.")
    return payload


def _text(value: Any, field: str, *, required: bool = False, max_length: int = 255) -> str | None:
    if value is None:
        if required:
            raise ApiError(f"{field} is required.")
        return None
    if not isinstance(value, str):
        raise ApiError(f"{field} must be text.")
    cleaned = value.strip()
    if required and not cleaned:
        raise ApiError(f"{field} is required.")
    if len(cleaned) > max_length:
        raise ApiError(f"{field} must be at most {max_length} characters.")
    return cleaned or None


def _amount(value: Any, field: str = "amount") -> Decimal:
    try:
        parsed = Decimal(str(value)).quantize(Decimal("0.01"))
    except (InvalidOperation, TypeError, ValueError):
        raise ApiError(f"{field} must be a valid amount.")
    if parsed <= 0 or parsed > Decimal("9999999999.99"):
        raise ApiError(f"{field} must be greater than zero.")
    return parsed


def _confidence(value: Any, default: Decimal) -> Decimal:
    if value is None:
        return default
    try:
        parsed = Decimal(str(value)).quantize(Decimal("0.01"))
    except (InvalidOperation, TypeError, ValueError):
        raise ApiError("confidence must be between 0 and 1.")
    if not Decimal("0") <= parsed <= Decimal("1"):
        raise ApiError("confidence must be between 0 and 1.")
    return parsed


def _timestamp(value: Any, field: str = "date") -> datetime:
    if value is None:
        return datetime.now(timezone.utc)
    if isinstance(value, datetime):
        parsed = value
    elif isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            raise ApiError(f"{field} must be an ISO-8601 date/time.")
    else:
        raise ApiError(f"{field} must be an ISO-8601 date/time.")
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed.astimezone(timezone.utc)


def _due_date(value: Any) -> date:
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if not isinstance(value, str):
        raise ApiError("next_due_date must be a YYYY-MM-DD date.")
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise ApiError("next_due_date must be a YYYY-MM-DD date.")


def _current_user_id() -> str:
    identity = get_jwt_identity()
    if not identity:
        raise ApiError("Authentication is required.", 401, "unauthorized")
    return str(identity)


def _owner_required(view):
    @wraps(view)
    @jwt_required()
    def wrapped(*args, **kwargs):
        g.user_id = _current_user_id()
        return view(*args, **kwargs)

    return wrapped


def _auth_payload(user_id: str, name: str, email: str, phone_no: str | None = None) -> dict[str, Any]:
    return {
        "user": {"user_id": user_id, "name": name, "email": email, "phone_no": phone_no},
        # Kept during the Flutter migration so a login response remains readable
        # by older clients. It is identity metadata only, never authorization.
        "user_id": user_id,
        "name": name,
        "email": email,
        "phone_no": phone_no,
        "access_token": create_access_token(identity=str(user_id)),
        "refresh_token": create_refresh_token(identity=str(user_id)),
        "token_type": "Bearer",
        "expires_in": int(app.config["JWT_ACCESS_TOKEN_EXPIRES"].total_seconds()),
    }


def _send_brevo_email(recipient: str, subject: str, text_content: str, html_content: str) -> None:
    """Send a branded FinManager transactional email with Brevo."""
    api_key = os.getenv("BREVO_API_KEY")
    sender_email = os.getenv("BREVO_SENDER_EMAIL")
    sender_name = os.getenv("BREVO_SENDER_NAME", "FinManager")
    if not api_key or not sender_email:
        raise RuntimeError("Brevo email is not configured.")

    payload = {
        "sender": {"name": sender_name, "email": sender_email},
        "to": [{"email": recipient}],
        "subject": subject,
        "textContent": text_content,
        "htmlContent": html_content,
    }
    request_body = json.dumps(payload).encode("utf-8")
    brevo_request = Request(
        "https://api.brevo.com/v3/smtp/email",
        data=request_body,
        headers={
            "accept": "application/json",
            "api-key": api_key,
            "content-type": "application/json",
        },
        method="POST",
    )
    try:
        with urlopen(brevo_request, timeout=10) as response:
            if not 200 <= response.status < 300:
                raise RuntimeError(f"Brevo returned HTTP {response.status}.")
    except (HTTPError, URLError, TimeoutError) as error:
        raise RuntimeError("Brevo could not send transactional email.") from error


def _finmanager_email(content: str) -> str:
    """Shared, inbox-friendly visual shell for FinManager email content."""
    return f"""<!doctype html>
<html lang="en">
  <body style="margin:0;padding:0;background:#F4F4F2;color:#171717;font-family:Arial,Helvetica,sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#F4F4F2;padding:32px 16px;">
      <tr><td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#FFFFFF;border-radius:24px;overflow:hidden;">
          <tr><td style="padding:28px 32px;background:#171717;">
            <span style="display:inline-block;padding:7px 11px;border-radius:9px;background:#C8E84E;color:#171717;font-size:13px;font-weight:700;letter-spacing:.4px;">FINMANAGER</span>
          </td></tr>
          <tr><td style="padding:36px 32px 28px;">{content}</td></tr>
          <tr><td style="padding:20px 32px 30px;border-top:1px solid #E8E8E6;color:#8A8A86;font-size:12px;line-height:18px;">
            FinManager · A clearer view of your money<br>
            This is an automated account email. Please do not reply.
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>"""


def _send_password_reset_email(recipient: str, code: str) -> None:
    """Deliver a branded, one-time password-reset code."""
    safe_code = html.escape(code)
    _send_brevo_email(
        recipient,
        "Reset your FinManager password",
        (
            f"Your FinManager password reset code is {code}. "
            "It expires in 15 minutes and can only be used once."
        ),
        _finmanager_email(
            f"""
            <h1 style="margin:0 0 12px;font-size:28px;line-height:34px;letter-spacing:-.5px;">Reset your password</h1>
            <p style="margin:0 0 24px;color:#5C5C58;font-size:16px;line-height:24px;">Use this verification code in the FinManager app. It expires in 15 minutes.</p>
            <div style="margin:0 0 24px;padding:18px;border-radius:16px;background:#C8E84E;color:#171717;font-size:32px;font-weight:700;letter-spacing:7px;text-align:center;">{safe_code}</div>
            <p style="margin:0;color:#8A8A86;font-size:14px;line-height:21px;">If you did not request a password reset, you can safely ignore this email.</p>
            """
        ),
    )


def _send_welcome_email(recipient: str, name: str) -> None:
    """Welcome new customers without making account creation depend on email."""
    safe_name = html.escape(name)
    _send_brevo_email(
        recipient,
        "Welcome to FinManager",
        (
            f"Welcome to FinManager, {name}! Your account is ready. "
            "Start by adding your income and expenses to see a clearer view of your money."
        ),
        _finmanager_email(
            f"""
            <h1 style="margin:0 0 12px;font-size:28px;line-height:34px;letter-spacing:-.5px;">Welcome, {safe_name}.</h1>
            <p style="margin:0 0 24px;color:#5C5C58;font-size:16px;line-height:24px;">Your FinManager account is ready. Start tracking income and expenses to get a clearer view of your money.</p>
            <table role="presentation" cellspacing="0" cellpadding="0"><tr><td style="padding:12px 18px;border-radius:999px;background:#171717;color:#FFFFFF;font-size:14px;font-weight:700;">Open FinManager and add your first transaction</td></tr></table>
            <p style="margin:24px 0 0;color:#8A8A86;font-size:14px;line-height:21px;">We’re glad to have you here.</p>
            """
        ),
    )


@app.errorhandler(ApiError)
def handle_api_error(error: ApiError):
    return jsonify({"status": "error", "code": error.code, "message": error.message}), error.status


@app.errorhandler(404)
def not_found(_error):
    return jsonify({"status": "error", "code": "not_found", "message": "Resource not found."}), 404


@app.errorhandler(Exception)
def handle_unexpected_error(error: Exception):
    app.logger.exception("Unhandled API error", exc_info=error)
    return jsonify({"status": "error", "code": "internal_error", "message": "Something went wrong. Please try again."}), 500


@jwt.unauthorized_loader
def missing_token(message: str):
    return jsonify({"status": "error", "code": "unauthorized", "message": message}), 401


@jwt.invalid_token_loader
def invalid_token(message: str):
    return jsonify({"status": "error", "code": "invalid_token", "message": message}), 401


@jwt.revoked_token_loader
def revoked_token(_header: dict[str, Any], _payload: dict[str, Any]):
    return jsonify({"status": "error", "code": "revoked_token", "message": "This session has ended."}), 401


@jwt.token_in_blocklist_loader
def is_token_revoked(_header: dict[str, Any], payload: dict[str, Any]) -> bool:
    try:
        with db_cursor() as (_connection, cursor):
            cursor.execute("SELECT 1 FROM token_blocklist WHERE jti = %s", (payload["jti"],))
            return cursor.fetchone() is not None
    except Exception:
        # Failing closed is safer than accepting a token whose revocation state
        # cannot be checked.
        return True


def _normalise_transaction(payload: dict[str, Any], *, source: str | None = None) -> dict[str, Any]:
    transaction_type = _text(payload.get("transaction_type"), "transaction_type", required=True, max_length=20)
    transaction_type = transaction_type.capitalize() if transaction_type else ""
    if transaction_type not in {"Income", "Expense"}:
        raise ApiError("transaction_type must be Income or Expense.")
    category_raw = _text(payload.get("category", "Others"), "category", required=True, max_length=100)
    permitted_categories = EXPENSE_CATEGORIES if transaction_type == "Expense" else INCOME_CATEGORIES
    # Match categories case-insensitively and store the canonical spelling, so
    # "food", "FOOD" and "Food" are all accepted as "Food".
    category = next(
        (c for c in permitted_categories if c.casefold() == category_raw.casefold()),
        None,
    )
    if category is None:
        raise ApiError("category is not valid for this transaction type.")
    source = source or _text(payload.get("source", "Manual"), "source", required=True, max_length=32)
    if source not in TRANSACTION_SOURCES:
        raise ApiError("source is not supported.")
    title = _text(payload.get("title"), "title", required=True)
    merchant = _text(payload.get("merchant") or title, "merchant")
    return {
        "title": title,
        "description": _text(payload.get("description"), "description", max_length=4000),
        "amount": _amount(payload.get("amount")),
        "category": category,
        "transaction_type": transaction_type,
        "date": _timestamp(payload.get("date")),
        "merchant": merchant,
        "source": source,
        "payment_method": _text(payload.get("payment_method"), "payment_method", max_length=100),
        "recurrence_status": _text(payload.get("recurrence_status", "Unknown"), "recurrence_status", required=True, max_length=32),
        "confidence": _confidence(payload.get("confidence"), Decimal("1.00") if source == "Manual" else Decimal("0.60")),
        "is_essential": bool(payload.get("is_essential", False)),
        "user_category_override": bool(payload.get("user_category_override", False)),
    }


def _fingerprint(transaction: dict[str, Any]) -> str:
    raw = "|".join(
        [
            transaction["source"],
            transaction["transaction_type"],
            (transaction["merchant"] or "").casefold(),
            str(transaction["amount"]),
            transaction["date"].date().isoformat(),
            transaction["payment_method"] or "",
        ]
    )
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _apply_merchant_rule(cursor: RealDictCursor, user_id: str, transaction: dict[str, Any]) -> dict[str, Any]:
    merchant = transaction.get("merchant")
    if not merchant:
        return transaction
    cursor.execute(
        """
        SELECT display_merchant, category, is_essential
        FROM merchant_rules WHERE user_id = %s AND merchant_pattern = %s
        """,
        (user_id, merchant.casefold()),
    )
    rule = cursor.fetchone()
    if not rule:
        return transaction
    updated = dict(transaction)
    if rule["display_merchant"]:
        updated["merchant"] = rule["display_merchant"]
    if rule["category"] and rule["category"] in (EXPENSE_CATEGORIES if updated["transaction_type"] == "Expense" else INCOME_CATEGORIES):
        updated["category"] = rule["category"]
    if rule["is_essential"] is not None:
        updated["is_essential"] = rule["is_essential"]
    return updated


TRANSACTION_COLUMNS = """
transaction_id, user_id, title, description, amount, category, transaction_type, date,
merchant, source, payment_method, recurrence_status, confidence, import_fingerprint,
is_essential, user_category_override, created_at, updated_at
"""


def _insert_transaction(cursor: RealDictCursor, user_id: str, transaction: dict[str, Any], fingerprint: str | None = None) -> dict[str, Any]:
    transaction = _apply_merchant_rule(cursor, user_id, transaction)
    cursor.execute(
        f"""
        INSERT INTO transactions (
            transaction_id, user_id, title, description, amount, category, transaction_type,
            date, merchant, source, payment_method, recurrence_status, confidence,
            import_fingerprint, is_essential, user_category_override
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) ON CONFLICT (user_id, import_fingerprint)
          WHERE import_fingerprint IS NOT NULL DO NOTHING
          RETURNING {TRANSACTION_COLUMNS}
        """,
        (
            str(uuid.uuid4()), user_id, transaction["title"], transaction["description"],
            transaction["amount"], transaction["category"], transaction["transaction_type"],
            transaction["date"], transaction["merchant"], transaction["source"],
            transaction["payment_method"], transaction["recurrence_status"], transaction["confidence"],
            fingerprint, transaction["is_essential"], transaction["user_category_override"],
        ),
    )
    return cursor.fetchone()


@app.get("/")
def home():
    return _response({"service": "FinManager expense-intelligence API", "version": "2"})


@app.post("/auth/register")
@app.post("/register")  # Transitional alias for the existing Flutter client.
@limiter.limit("10 per hour")
def register():
    payload = _request_json()
    name = _text(payload.get("name"), "name", required=True, max_length=200)
    email = _text(payload.get("email"), "email", required=True, max_length=255)
    password = payload.get("password")
    if not isinstance(password, str) or len(password) < 8:
        raise ApiError("password must be at least 8 characters.")
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email or ""):
        raise ApiError("email must be valid.")
    email = email.casefold()
    phone_no = _text(payload.get("phone_no"), "phone_no", max_length=15)
    with db_cursor() as (_connection, cursor):
        cursor.execute("SELECT 1 FROM customers WHERE email = %s", (email,))
        if cursor.fetchone():
            raise ApiError("An account with this email already exists.", 409, "email_taken")
        user_id = str(uuid.uuid4())
        cursor.execute(
            """
            INSERT INTO customers (user_id, name, email, password, phone_no)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (user_id, name, email, bcrypt.generate_password_hash(password).decode("utf-8"), phone_no),
        )
    try:
        _send_welcome_email(email, name)
    except RuntimeError:
        # Registration has already succeeded; an email outage must not block it.
        app.logger.exception("Unable to send welcome email through Brevo")
    return _response(_auth_payload(user_id, name, email, phone_no), 201)


@app.post("/auth/login")
@app.post("/login")  # Transitional alias for the existing Flutter client.
@limiter.limit("20 per hour")
def login():
    payload = _request_json()
    email = _text(payload.get("email"), "email", required=True, max_length=255)
    password = payload.get("password")
    if not isinstance(password, str):
        raise ApiError("email and password are required.", 401, "invalid_credentials")
    with db_cursor() as (_connection, cursor):
        cursor.execute(
            "SELECT user_id, name, email, phone_no, password FROM customers WHERE email = %s",
            (email.casefold(),),
        )
        user = cursor.fetchone()
    if not user or not bcrypt.check_password_hash(user["password"], password):
        raise ApiError("Invalid email or password.", 401, "invalid_credentials")
    return _response(_auth_payload(str(user["user_id"]), user["name"], user["email"], user["phone_no"]))


@app.post("/auth/forgot-password")
@limiter.limit("5 per hour")
def forgot_password():
    """Issue a short-lived, single-use reset code without revealing account existence."""
    email = _text(_request_json().get("email"), "email", required=True, max_length=255)
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email or ""):
        raise ApiError("email must be valid.")
    email = email.casefold()

    with db_cursor() as (_connection, cursor):
        cursor.execute("SELECT user_id FROM customers WHERE email = %s", (email,))
        account = cursor.fetchone()
        if account:
            code = f"{secrets.randbelow(1_000_000):06d}"
            cursor.execute(
                "DELETE FROM password_reset_tokens WHERE user_id = %s AND used_at IS NULL",
                (account["user_id"],),
            )
            cursor.execute(
                """
                INSERT INTO password_reset_tokens (token_id, user_id, token_hash, expires_at)
                VALUES (%s, %s, %s, CURRENT_TIMESTAMP + INTERVAL '15 minutes')
                """,
                (str(uuid.uuid4()), account["user_id"], hashlib.sha256(code.encode()).hexdigest()),
            )
            try:
                _send_password_reset_email(email, code)
            except RuntimeError:
                app.logger.exception("Unable to send password reset email through Brevo")
                # Keep account existence private even when email delivery has
                # an outage, and make sure an unsent code cannot be used.
                cursor.execute(
                    "DELETE FROM password_reset_tokens WHERE user_id = %s",
                    (account["user_id"],),
                )

    # This response is deliberately identical for existing and unknown emails.
    return _response({"message": "If an account uses that email, a reset code has been sent."})


@app.post("/auth/reset-password")
@limiter.limit("10 per hour")
def reset_password():
    payload = _request_json()
    email = _text(payload.get("email"), "email", required=True, max_length=255)
    code = _text(payload.get("code"), "code", required=True, max_length=6)
    password = payload.get("password")
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email or ""):
        raise ApiError("email must be valid.")
    if not code or not re.fullmatch(r"\d{6}", code):
        raise ApiError("Enter the six-digit code from your email.")
    if not isinstance(password, str) or len(password) < 8:
        raise ApiError("password must be at least 8 characters.")

    with db_cursor() as (_connection, cursor):
        cursor.execute(
            """
            SELECT reset.token_id, reset.token_hash, customer.user_id
            FROM password_reset_tokens AS reset
            JOIN customers AS customer ON customer.user_id = reset.user_id
            WHERE customer.email = %s
              AND reset.used_at IS NULL
              AND reset.expires_at > CURRENT_TIMESTAMP
              AND reset.attempts < 5
            ORDER BY reset.created_at DESC
            LIMIT 1
            FOR UPDATE OF reset
            """,
            (email.casefold(),),
        )
        reset = cursor.fetchone()
        if not reset or not secrets.compare_digest(
            reset["token_hash"], hashlib.sha256(code.encode()).hexdigest()
        ):
            if reset:
                cursor.execute(
                    "UPDATE password_reset_tokens SET attempts = attempts + 1 WHERE token_id = %s",
                    (reset["token_id"],),
                )
            raise ApiError("That reset code is invalid or has expired.", 400, "invalid_reset_code")

        cursor.execute(
            "UPDATE customers SET password = %s WHERE user_id = %s",
            (bcrypt.generate_password_hash(password).decode("utf-8"), reset["user_id"]),
        )
        cursor.execute(
            "UPDATE password_reset_tokens SET used_at = CURRENT_TIMESTAMP WHERE token_id = %s",
            (reset["token_id"],),
        )
        cursor.execute("DELETE FROM password_reset_tokens WHERE user_id = %s", (reset["user_id"],))
    return _response({"message": "Your password has been reset. Please log in."})


@app.post("/auth/refresh")
@jwt_required(refresh=True)
def refresh():
    return _response({"access_token": create_access_token(identity=_current_user_id()), "token_type": "Bearer"})


@app.post("/auth/logout")
@_owner_required
def logout():
    claims = get_jwt()
    with db_cursor() as (_connection, cursor):
        cursor.execute(
            """
            INSERT INTO token_blocklist (jti, user_id, expires_at)
            VALUES (%s, %s, to_timestamp(%s)) ON CONFLICT (jti) DO NOTHING
            """,
            (claims["jti"], g.user_id, claims["exp"]),
        )
    return _response({"message": "Logged out."})


@app.get("/transactions")
@_owner_required
def get_transactions():
    page = max(int(request.args.get("page", 1)), 1)
    page_size = min(max(int(request.args.get("page_size", 100)), 1), 100)
    filters, params = ["user_id = %s"], [g.user_id]
    if transaction_type := request.args.get("transaction_type"):
        if transaction_type not in {"Income", "Expense"}:
            raise ApiError("transaction_type must be Income or Expense.")
        filters.append("transaction_type = %s")
        params.append(transaction_type)
    if category := request.args.get("category"):
        filters.append("category = %s")
        params.append(category)
    where = " AND ".join(filters)
    with db_cursor() as (_connection, cursor):
        cursor.execute(f"SELECT COUNT(*) AS count FROM transactions WHERE {where}", params)
        total = cursor.fetchone()["count"]
        cursor.execute(
            f"SELECT {TRANSACTION_COLUMNS} FROM transactions WHERE {where} ORDER BY date DESC, created_at DESC LIMIT %s OFFSET %s",
            [*params, page_size, (page - 1) * page_size],
        )
        transactions = cursor.fetchall()
    return _response({"transactions": transactions, "pagination": {"page": page, "page_size": page_size, "total": total}})


@app.post("/transactions")
@app.post("/transaction")
@_owner_required
def add_transaction():
    transaction = _normalise_transaction(_request_json())
    with db_cursor() as (_connection, cursor):
        created = _insert_transaction(cursor, g.user_id, transaction)
    return _response({"message": "Transaction added successfully.", "transaction": created}, 201)


@app.route("/transactions/<transaction_id>", methods=["GET", "PATCH", "DELETE"])
@_owner_required
def transaction_detail(transaction_id: str):
    with db_cursor() as (_connection, cursor):
        cursor.execute(f"SELECT {TRANSACTION_COLUMNS} FROM transactions WHERE transaction_id = %s AND user_id = %s", (transaction_id, g.user_id))
        current = cursor.fetchone()
        if not current:
            raise ApiError("Transaction not found.", 404, "not_found")
        if request.method == "GET":
            return _response({"transaction": current})
        if request.method == "DELETE":
            cursor.execute("DELETE FROM transactions WHERE transaction_id = %s AND user_id = %s", (transaction_id, g.user_id))
            return _response({"message": "Transaction deleted."})

        payload = {**_json(current), **_request_json()}
        payload.pop("user_id", None)
        transaction = _normalise_transaction(payload)
        updated = _apply_merchant_rule(cursor, g.user_id, transaction)
        cursor.execute(
            f"""
            UPDATE transactions SET title=%s, description=%s, amount=%s, category=%s,
                transaction_type=%s, date=%s, merchant=%s, source=%s, payment_method=%s,
                recurrence_status=%s, confidence=%s, is_essential=%s,
                user_category_override=%s, updated_at=CURRENT_TIMESTAMP
            WHERE transaction_id=%s AND user_id=%s RETURNING {TRANSACTION_COLUMNS}
            """,
            (
                updated["title"], updated["description"], updated["amount"], updated["category"],
                updated["transaction_type"], updated["date"], updated["merchant"], updated["source"],
                updated["payment_method"], updated["recurrence_status"], updated["confidence"],
                updated["is_essential"], updated["user_category_override"], transaction_id, g.user_id,
            ),
        )
        return _response({"transaction": cursor.fetchone()})


def _import_item_payload(item: Any, source: str) -> dict[str, Any]:
    if not isinstance(item, dict):
        raise ApiError("Each import item must be a JSON object.")
    payload = _normalise_transaction({**item, "source": source}, source=source)
    return {**payload, "import_fingerprint": _text(item.get("import_fingerprint"), "import_fingerprint", max_length=128) or _fingerprint(payload)}


@app.post("/imports")
@_owner_required
def create_import():
    payload = _request_json()
    source = _text(payload.get("source"), "source", required=True, max_length=32)
    if source not in IMPORT_SOURCES:
        raise ApiError("source must be CSVImport, BankStatementPDF, or FinancialSMS.")
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        raise ApiError("items must be a non-empty list.")
    if len(items) > 1000:
        raise ApiError("An import is limited to 1,000 items.")
    filename = _text(payload.get("filename"), "filename", max_length=255)
    with db_cursor() as (_connection, cursor):
        import_id = str(uuid.uuid4())
        cursor.execute(
            "INSERT INTO import_batches (import_id, user_id, source, filename) VALUES (%s, %s, %s, %s)",
            (import_id, g.user_id, source, filename),
        )
        created_items = []
        for item in items:
            try:
                parsed = _import_item_payload(item, source)
                cursor.execute(
                    "SELECT 1 FROM transactions WHERE user_id = %s AND import_fingerprint = %s",
                    (g.user_id, parsed["import_fingerprint"]),
                )
                status = "duplicate" if cursor.fetchone() else "pending"
                cursor.execute(
                    """
                    INSERT INTO import_items (
                        item_id, import_id, title, description, amount, category, transaction_type,
                        transaction_date, merchant, payment_method, confidence, import_fingerprint, status
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING *
                    """,
                    (
                        str(uuid.uuid4()), import_id, parsed["title"], parsed["description"], parsed["amount"],
                        parsed["category"], parsed["transaction_type"], parsed["date"], parsed["merchant"],
                        parsed["payment_method"], parsed["confidence"], parsed["import_fingerprint"], status,
                    ),
                )
            except ApiError as error:
                cursor.execute(
                    """
                    INSERT INTO import_items (
                        item_id, import_id, title, amount, category, transaction_type, transaction_date,
                        confidence, import_fingerprint, status, error_message
                    ) VALUES (%s, %s, %s, 1, 'Others', 'Expense', CURRENT_TIMESTAMP, 0, %s, 'invalid', %s)
                    RETURNING *
                    """,
                    (str(uuid.uuid4()), import_id, "Invalid import row", hashlib.sha256(str(item).encode()).hexdigest(), error.message),
                )
            created_items.append(cursor.fetchone())
    return _response({"import": {"import_id": import_id, "source": source, "status": "review_required"}, "items": created_items}, 201)


@app.post("/imports/validate_csv_headers")
@_owner_required
def validate_csv_headers():
    payload = _request_json()
    headers = payload.get("headers")
    if not isinstance(headers, list):
        raise ApiError("headers must be a list of strings.")

    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return _response({"valid": True})

    try:
        from langchain_groq import ChatGroq
        
        prompt = f"""You are a data validation assistant for FinManager. The user is trying to upload a CSV file of financial transactions.
        
The headers of the CSV file are: {json.dumps(headers)}

Determine if these headers look like a valid financial statement or expense tracker export. A valid statement typically contains columns for things like Date, Description/Narration/Title, and Amount (or Debit/Credit).

Reply with ONLY a single JSON object (no markdown, nothing outside it):
{{
    "valid": true
}}
or false if it clearly has no relation to financial transactions.
"""
        raw = ChatGroq(
            model_name=os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile"),
            temperature=0.0,
            groq_api_key=api_key,
        ).invoke(prompt).content
        
        parsed = _parse_agent_json(raw)
        is_valid = bool(parsed.get("valid", True)) if parsed else True
    except Exception as e:
        app.logger.warning(f"Groq CSV validation failed: {e}")
        is_valid = True

    return _response({"valid": is_valid})


def _get_import(cursor: RealDictCursor, import_id: str, user_id: str) -> dict[str, Any]:
    cursor.execute("SELECT * FROM import_batches WHERE import_id = %s AND user_id = %s", (import_id, user_id))
    result = cursor.fetchone()
    if not result:
        raise ApiError("Import not found.", 404, "not_found")
    return result


@app.get("/imports/<import_id>")
@_owner_required
def get_import(import_id: str):
    with db_cursor() as (_connection, cursor):
        imported = _get_import(cursor, import_id, g.user_id)
        cursor.execute("SELECT * FROM import_items WHERE import_id = %s ORDER BY created_at", (import_id,))
        items = cursor.fetchall()
    return _response({"import": imported, "items": items})


@app.post("/imports/<import_id>/confirm")
@_owner_required
def confirm_import(import_id: str):
    payload = _request_json()
    decisions = payload.get("items")
    if not isinstance(decisions, list) or not decisions or len(decisions) > 500:
        raise ApiError("items must contain between 1 and 500 review decisions.")
    accepted, discarded, duplicate = [], [], []
    with db_cursor() as (_connection, cursor):
        _get_import(cursor, import_id, g.user_id)
        for decision in decisions:
            if not isinstance(decision, dict):
                raise ApiError("Each review decision must be an object.")
            item_id = _text(decision.get("item_id"), "item_id", required=True, max_length=36)
            cursor.execute("SELECT * FROM import_items WHERE item_id = %s AND import_id = %s FOR UPDATE", (item_id, import_id))
            item = cursor.fetchone()
            if not item:
                raise ApiError("An import item was not found.", 404, "not_found")
            if item["status"] != "pending":
                continue
            if decision.get("accept", True) is False:
                cursor.execute("UPDATE import_items SET status = 'discarded' WHERE item_id = %s", (item_id,))
                discarded.append(item_id)
                continue
            merged = {**_json(item), **decision, "date": _json(item["transaction_date"]), "source": "Manual"}
            # Imported transactions retain the source of the batch, never the
            # client supplied value in a review decision.
            merged["source"] = _get_import(cursor, import_id, g.user_id)["source"]
            transaction = _normalise_transaction(merged, source=merged["source"])
            created = _insert_transaction(cursor, g.user_id, transaction, item["import_fingerprint"])
            if created:
                cursor.execute("UPDATE import_items SET status = 'accepted' WHERE item_id = %s", (item_id,))
                accepted.append(created)
            else:
                cursor.execute("UPDATE import_items SET status = 'duplicate' WHERE item_id = %s", (item_id,))
                duplicate.append(item_id)
        cursor.execute(
            """
            UPDATE import_batches SET status = 'confirmed', confirmed_at = CURRENT_TIMESTAMP
            WHERE import_id = %s
            """,
            (import_id,),
        )
    return _response({"accepted": accepted, "discarded_item_ids": discarded, "duplicate_item_ids": duplicate})


@app.get("/merchant-rules")
@_owner_required
def list_merchant_rules():
    with db_cursor() as (_connection, cursor):
        cursor.execute("SELECT * FROM merchant_rules WHERE user_id = %s ORDER BY updated_at DESC", (g.user_id,))
        rules = cursor.fetchall()
    return _response({"merchant_rules": rules})


@app.post("/merchant-rules")
@_owner_required
def create_merchant_rule():
    payload = _request_json()
    pattern = _text(payload.get("merchant_pattern"), "merchant_pattern", required=True)
    category = _text(payload.get("category"), "category", max_length=100)
    if category and category not in EXPENSE_CATEGORIES | INCOME_CATEGORIES:
        raise ApiError("category is not supported.")
    with db_cursor() as (_connection, cursor):
        cursor.execute(
            """
            INSERT INTO merchant_rules (rule_id, user_id, merchant_pattern, display_merchant, category, is_essential)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (user_id, merchant_pattern) DO UPDATE SET
              display_merchant = EXCLUDED.display_merchant, category = EXCLUDED.category,
              is_essential = EXCLUDED.is_essential, updated_at = CURRENT_TIMESTAMP
            RETURNING *
            """,
            (str(uuid.uuid4()), g.user_id, pattern.casefold(), _text(payload.get("display_merchant"), "display_merchant"), category, payload.get("is_essential")),
        )
        rule = cursor.fetchone()
    return _response({"merchant_rule": rule}, 201)


@app.delete("/merchant-rules/<rule_id>")
@_owner_required
def delete_merchant_rule(rule_id: str):
    with db_cursor() as (_connection, cursor):
        cursor.execute("DELETE FROM merchant_rules WHERE rule_id = %s AND user_id = %s RETURNING rule_id", (rule_id, g.user_id))
        if not cursor.fetchone():
            raise ApiError("Merchant rule not found.", 404, "not_found")
    return _response({"message": "Merchant rule deleted."})


def _normalise_commitment(payload: dict[str, Any]) -> dict[str, Any]:
    frequency = _text(payload.get("frequency"), "frequency", required=True, max_length=20)
    if frequency not in FREQUENCIES:
        raise ApiError("frequency must be weekly, monthly, quarterly, or yearly.")
    return {
        "title": _text(payload.get("title"), "title", required=True),
        "merchant": _text(payload.get("merchant"), "merchant"),
        "expected_amount": _amount(payload.get("expected_amount"), "expected_amount"),
        "frequency": frequency,
        "next_due_date": _due_date(payload.get("next_due_date")),
        "is_essential": bool(payload.get("is_essential", True)),
        "is_active": bool(payload.get("is_active", True)),
        "notes": _text(payload.get("notes"), "notes", max_length=4000),
    }


@app.route("/commitments", methods=["GET", "POST"])
@_owner_required
def commitments():
    if request.method == "GET":
        with db_cursor() as (_connection, cursor):
            cursor.execute("SELECT * FROM recurring_commitments WHERE user_id = %s ORDER BY next_due_date", (g.user_id,))
            rows = cursor.fetchall()
        return _response({"commitments": rows})
    commitment = _normalise_commitment(_request_json())
    with db_cursor() as (_connection, cursor):
        cursor.execute(
            """
            INSERT INTO recurring_commitments (
              commitment_id, user_id, title, merchant, expected_amount, frequency,
              next_due_date, is_essential, is_active, notes
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING *
            """,
            (str(uuid.uuid4()), g.user_id, *commitment.values()),
        )
        created = cursor.fetchone()
    return _response({"commitment": created}, 201)


@app.route("/commitments/<commitment_id>", methods=["PATCH", "DELETE"])
@_owner_required
def commitment_detail(commitment_id: str):
    with db_cursor() as (_connection, cursor):
        cursor.execute("SELECT * FROM recurring_commitments WHERE commitment_id = %s AND user_id = %s", (commitment_id, g.user_id))
        existing = cursor.fetchone()
        if not existing:
            raise ApiError("Commitment not found.", 404, "not_found")
        if request.method == "DELETE":
            cursor.execute("DELETE FROM recurring_commitments WHERE commitment_id = %s", (commitment_id,))
            return _response({"message": "Commitment deleted."})
        commitment = _normalise_commitment({**_json(existing), **_request_json()})
        cursor.execute(
            """
            UPDATE recurring_commitments SET title=%s, merchant=%s, expected_amount=%s,
              frequency=%s, next_due_date=%s, is_essential=%s, is_active=%s, notes=%s,
              updated_at=CURRENT_TIMESTAMP WHERE commitment_id=%s AND user_id=%s RETURNING *
            """,
            (*commitment.values(), commitment_id, g.user_id),
        )
        return _response({"commitment": cursor.fetchone()})


def _generated_insights(cursor: RealDictCursor, user_id: str) -> list[dict[str, Any]]:
    cursor.execute(
        """
        SELECT transaction_id, title, merchant, amount, transaction_type, date
        FROM transactions WHERE user_id = %s AND transaction_type = 'Expense'
          AND date >= CURRENT_TIMESTAMP - INTERVAL '400 days'
        ORDER BY date
        """,
        (user_id,),
    )
    transactions = cursor.fetchall()
    cursor.execute(
        """
        SELECT commitment_id, title, expected_amount, frequency, next_due_date
        FROM recurring_commitments WHERE user_id = %s AND is_active = TRUE
          AND next_due_date <= CURRENT_DATE + 7
        """,
        (user_id,),
    )
    generated = build_expense_insights(transactions, cursor.fetchall())
    stored = []
    for insight in generated:
        cursor.execute(
            """
            INSERT INTO expense_insights (
              insight_id, user_id, insight_key, kind, title, message, confidence,
              amount, projected_annual_cost, evidence
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)
            ON CONFLICT (user_id, insight_key) DO UPDATE SET
              title=EXCLUDED.title, message=EXCLUDED.message, confidence=EXCLUDED.confidence,
              amount=EXCLUDED.amount, projected_annual_cost=EXCLUDED.projected_annual_cost,
              evidence=EXCLUDED.evidence, updated_at=CURRENT_TIMESTAMP
            RETURNING *
            """,
            (
                str(uuid.uuid4()), user_id, insight["insight_key"], insight["kind"], insight["title"],
                insight["message"], insight["confidence"], insight["amount"], insight["projected_annual_cost"],
                json.dumps(insight["evidence"]),
            ),
        )
        stored.append(cursor.fetchone())
    return stored


@app.get("/expense-insights")
@_owner_required
def expense_insights():
    include_dismissed = request.args.get("include_dismissed") == "true"
    with db_cursor() as (_connection, cursor):
        _generated_insights(cursor, g.user_id)
        where = "user_id = %s" if include_dismissed else "user_id = %s AND status = 'open'"
        cursor.execute(f"SELECT * FROM expense_insights WHERE {where} ORDER BY updated_at DESC", (g.user_id,))
        insights = cursor.fetchall()
    return _response({"insights": insights})


@app.post("/expense-insights/<insight_id>/feedback")
@_owner_required
def expense_insight_feedback(insight_id: str):
    feedback = _text(_request_json().get("feedback"), "feedback", required=True, max_length=20)
    if feedback not in INSIGHT_FEEDBACK:
        raise ApiError("feedback must be helpful, incorrect, expected, or ignored.")
    with db_cursor() as (_connection, cursor):
        cursor.execute(
            """
            UPDATE expense_insights SET status=%s, feedback_at=CURRENT_TIMESTAMP, updated_at=CURRENT_TIMESTAMP
            WHERE insight_id=%s AND user_id=%s RETURNING *
            """,
            (feedback, insight_id, g.user_id),
        )
        insight = cursor.fetchone()
        if not insight:
            raise ApiError("Insight not found.", 404, "not_found")
    return _response({"insight": insight})


@app.get("/expense-story")
@_owner_required
def expense_story():
    with db_cursor() as (_connection, cursor):
        generated = _generated_insights(cursor, g.user_id)
    story = build_expense_story([_json(item) for item in generated if item["status"] == "open"])
    return _response({"story": story})


@app.get("/expense-guidance")
@_owner_required
def expense_guidance():
    with db_cursor() as (_connection, cursor):
        cursor.execute(
            """
            SELECT COALESCE(SUM(amount), 0) AS current_flexible_spend
            FROM transactions WHERE user_id=%s AND transaction_type='Expense' AND is_essential=FALSE
              AND date >= date_trunc('month', CURRENT_TIMESTAMP)
            """,
            (g.user_id,),
        )
        current_spend = cursor.fetchone()["current_flexible_spend"]
        cursor.execute(
            """
            SELECT COALESCE(AVG(monthly_total), 0) AS historical_monthly_average FROM (
              SELECT date_trunc('month', date) AS month, SUM(amount) AS monthly_total
              FROM transactions WHERE user_id=%s AND transaction_type='Expense' AND is_essential=FALSE
                AND date >= date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '3 months'
                AND date < date_trunc('month', CURRENT_TIMESTAMP)
              GROUP BY 1
            ) monthly
            """,
            (g.user_id,),
        )
        historical = cursor.fetchone()["historical_monthly_average"]
        cursor.execute(
            """
            SELECT COALESCE(SUM(expected_amount), 0) AS upcoming_commitments
            FROM recurring_commitments WHERE user_id=%s AND is_active=TRUE
              AND next_due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
            """,
            (g.user_id,),
        )
        commitments = cursor.fetchone()["upcoming_commitments"]
    remaining_days = max(1, (date.today().replace(day=28) + timedelta(days=4)).replace(day=1).toordinal() - date.today().toordinal())
    remaining_allowance = max(Decimal("0"), historical - current_spend)
    return _response({
        "current_flexible_spend": current_spend,
        "historical_monthly_average": historical,
        "upcoming_commitments_30_days": commitments,
        "recommended_weekly_limit": remaining_allowance * Decimal("7") / Decimal(str(remaining_days)),
        "note": "This is an expense allowance based on your own history; it is not financial advice.",
    })


def _get_chat_session(cursor: RealDictCursor, session_id: str, user_id: str) -> dict[str, Any]:
    cursor.execute(
        "SELECT * FROM chat_sessions WHERE session_id = %s AND user_id = %s",
        (session_id, user_id),
    )
    session = cursor.fetchone()
    if not session:
        raise ApiError("Chat session not found.", 404, "not_found")
    return session


def _create_chat_session(cursor: RealDictCursor, user_id: str, title: str | None = None) -> dict[str, Any]:
    cursor.execute(
        """
        INSERT INTO chat_sessions (session_id, user_id, title)
        VALUES (%s, %s, %s) RETURNING *
        """,
        (str(uuid.uuid4()), user_id, title or "New expense chat"),
    )
    return cursor.fetchone()


def _insert_chat_message(
    cursor: RealDictCursor,
    session_id: str,
    user_id: str,
    role: str,
    content: str,
    context: dict[str, Any] | None = None,
) -> dict[str, Any]:
    cursor.execute(
        """
        INSERT INTO chat_messages (message_id, session_id, user_id, role, content, context)
        VALUES (%s, %s, %s, %s, %s, %s::jsonb) RETURNING *
        """,
        (str(uuid.uuid4()), session_id, user_id, role, content, json.dumps(context or {})),
    )
    return cursor.fetchone()


def _recent_chat_messages(cursor: RealDictCursor, session_id: str, limit: int = 12) -> list[dict[str, Any]]:
    # Fetch newest rows first for an efficient index scan, then restore the
    # natural conversation order before handing context to the responder.
    cursor.execute(
        """
        SELECT * FROM (
          SELECT * FROM chat_messages WHERE session_id = %s
          ORDER BY created_at DESC, message_id DESC LIMIT %s
        ) recent ORDER BY created_at, message_id
        """,
        (session_id, limit),
    )
    return cursor.fetchall()


def _financial_context(cursor: RealDictCursor, user_id: str) -> dict[str, Any]:
    """Deterministic, read-only snapshot of the user's money for the assistant.

    The model never touches the database or writes SQL; it only reasons over this
    bounded, server-computed context, scoped to the current user's rows.
    """
    cursor.execute(
        """
        SELECT transaction_type, COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count
        FROM transactions WHERE user_id = %s GROUP BY transaction_type
        """,
        (user_id,),
    )
    totals = {row["transaction_type"]: row for row in cursor.fetchall()}
    income = float(totals.get("Income", {}).get("total") or 0)
    expense = float(totals.get("Expense", {}).get("total") or 0)
    transaction_count = sum(int(row["count"]) for row in totals.values())

    cursor.execute(
        """
        SELECT title, merchant, category, transaction_type, amount, date
        FROM transactions WHERE user_id = %s
        ORDER BY date DESC, created_at DESC LIMIT 15
        """,
        (user_id,),
    )
    recent = [
        {
            "date": row["date"].date().isoformat(),
            "title": row["title"],
            "merchant": row["merchant"],
            "category": row["category"],
            "type": row["transaction_type"],
            "amount": float(row["amount"]),
        }
        for row in cursor.fetchall()
    ]

    cursor.execute(
        """
        SELECT category, COALESCE(SUM(amount), 0) AS total
        FROM transactions WHERE user_id = %s AND transaction_type = 'Expense'
          AND date >= date_trunc('month', CURRENT_TIMESTAMP)
        GROUP BY category ORDER BY total DESC
        """,
        (user_id,),
    )
    this_month = {row["category"]: round(float(row["total"]), 2) for row in cursor.fetchall()}

    cursor.execute(
        """
        SELECT category, COALESCE(SUM(amount), 0) AS total
        FROM transactions WHERE user_id = %s AND transaction_type = 'Expense'
        GROUP BY category ORDER BY total DESC LIMIT 5
        """,
        (user_id,),
    )
    top_categories = {row["category"]: round(float(row["total"]), 2) for row in cursor.fetchall()}

    return {
        "currency": "INR",
        "transaction_count": transaction_count,
        "totals": {
            "income": round(income, 2),
            "expense": round(expense, 2),
            "balance": round(income - expense, 2),
        },
        "this_month_expense_by_category": this_month,
        "top_expense_categories_all_time": top_categories,
        "recent_transactions": recent,
    }


def _deterministic_chat_answer(context: dict[str, Any], story: dict[str, Any]) -> str:
    """Grounded answer used when no LLM key is configured."""
    if context["transaction_count"] == 0:
        return (
            "You haven't added any transactions yet. Add or import your income and "
            "expenses, and I can break down your spending, balances, and recent activity."
        )
    totals = context["totals"]
    recent = context["recent_transactions"][0]
    return (
        f"Snapshot: balance ₹{totals['balance']:.2f} (income ₹{totals['income']:.2f}, "
        f"spending ₹{totals['expense']:.2f}). Your most recent transaction was "
        f"\"{recent['title']}\" — ₹{recent['amount']:.2f} {recent['type'].lower()} "
        f"in {recent['category']} on {recent['date']}. "
        "Ask about a category, merchant, or period for more detail."
    )


def _parse_agent_json(raw: str) -> dict[str, Any] | None:
    """Extract the first JSON object from the model's reply, tolerating prose."""
    if not raw:
        return None
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    if not match:
        return None
    try:
        parsed = json.loads(match.group(0))
        return parsed if isinstance(parsed, dict) else None
    except (json.JSONDecodeError, ValueError):
        return None


def _agent_add_transaction(
    cursor: RealDictCursor, user_id: str, proposed: dict[str, Any]
) -> dict[str, Any]:
    """Validate an LLM-proposed transaction and insert it (source=AI).

    The category is forced into the allowed set (anything else becomes
    'Others'); every other field runs through the same strict validation as a
    manual add. The model cannot bypass ownership, amount, or type checks.
    """
    transaction_type = str(proposed.get("transaction_type") or "Expense").strip().capitalize()
    allowed = EXPENSE_CATEGORIES if transaction_type == "Expense" else INCOME_CATEGORIES
    raw_category = str(proposed.get("category") or "")
    # Case-insensitive match to the canonical category; unknowns become Others.
    category = next(
        (c for c in allowed if c.casefold() == raw_category.casefold()), "Others"
    )
    payload = {
        "title": proposed.get("title"),
        "amount": proposed.get("amount"),
        "transaction_type": transaction_type,
        "category": category,
        "description": proposed.get("description"),
        "date": proposed.get("date"),
        "source": "AI",
    }
    transaction = _normalise_transaction(payload, source="AI")
    return _insert_transaction(cursor, user_id, transaction)


def _agent_reply(
    cursor: RealDictCursor,
    user_id: str,
    message: str,
    history: list[dict[str, Any]],
    story: dict[str, Any],
    context: dict[str, Any],
) -> str:
    """A chat turn that can answer questions OR add a transaction.

    The model only proposes a structured action as JSON; this server validates
    and performs any write. It never writes SQL or touches the database itself.
    Missing details are gathered conversationally across turns (the recent
    history is the slot-filling state).
    """
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return _deterministic_chat_answer(context, story)

    try:
        from langchain_groq import ChatGroq

        transcript = "\n".join(
            f"{m['role'].capitalize()}: {m['content']}" for m in history[-12:]
        )
        today = datetime.now(timezone.utc).date().isoformat()
        prompt = f"""You are FinManager's expense assistant. You can chat about the user's money and you can ADD a transaction (income or expense) to their account when they ask.

Reply with ONLY a single JSON object (no markdown, nothing outside it), shaped exactly like:
{{
  "intent": "add_transaction" | "chat",
  "ready_to_add": true | false,
  "transaction": {{
    "title": "short label e.g. Coffee",
    "amount": 0,
    "transaction_type": "Expense" | "Income",
    "category": "one of the allowed categories",
    "description": "optional note or null",
    "date": "YYYY-MM-DD or null (null = today)"
  }},
  "reply": "what to say to the user"
}}

Adding a transaction:
- Use intent="add_transaction" when the user wants to record/add/log an expense or income.
- Required: title, amount, transaction_type. If any is missing or unclear, set ready_to_add=false and put a SHORT question in "reply" asking only for the missing detail. Keep the details you already know inside "transaction".
- When title, amount and type are known, set ready_to_add=true.
- transaction_type is "Income" for money received (salary, bonus, gift, refund, dividend); otherwise "Expense".
- category MUST be exactly one of these — never invent others:
    Expense: Food, Travel, Bills, Shopping, Rent, Others
    Income: Salary, Bonus, Gift, Investment, Others
  Map sensibly: coffee/restaurant/grocery/snacks/dinner/lunch -> Food; uber/taxi/train/flight/bus/fuel/cab -> Travel; electricity/water/internet/phone/wifi/recharge/bill -> Bills; clothes/movie/gadgets/shopping -> Shopping; rent -> Rent; salary/pay -> Salary; bonus -> Bonus; gift -> Gift; dividend/interest/investment -> Investment. If nothing fits, use Others.
- Do NOT claim you added anything; the app performs the insert and confirms it.

Chatting (intent="chat"): set transaction=null and answer using ONLY the snapshot below; never invent numbers. If a detail isn't there, say so.

You cannot delete, edit, or cancel anything, and you give no investment/tax/legal advice. Use Indian Rupees (₹). Today is {today}.

Authoritative account snapshot:
{json.dumps(context, ensure_ascii=False)}

Spending insights:
{json.dumps(story, ensure_ascii=False)}

Conversation:
{transcript}
"""
        raw = ChatGroq(
            model_name=os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile"),
            temperature=0.1,
            groq_api_key=api_key,
        ).invoke(prompt).content
        action = _parse_agent_json(raw)
    except Exception:
        app.logger.warning("Agent model unavailable; returning deterministic fallback.")
        return _deterministic_chat_answer(context, story)

    if action is None:
        return _deterministic_chat_answer(context, story)

    reply = str(action.get("reply") or "").strip()[:4000]
    if action.get("intent") == "add_transaction":
        if action.get("ready_to_add") and isinstance(action.get("transaction"), dict):
            try:
                created = _json(_agent_add_transaction(cursor, user_id, action["transaction"]))
            except ApiError as exc:
                return (
                    f"I couldn't add that — {exc.message} "
                    "Tell me the amount and what it was for."
                )
            return (
                f"Added ₹{created['amount']:.2f} for \"{created['title']}\" under "
                f"{created['category']} ({created['transaction_type']}) on "
                f"{str(created['date'])[:10]}."
            )
        return reply or "Sure — what was it for, and how much?"
    return reply or _deterministic_chat_answer(context, story)


def _chat_title(message: str) -> str:
    compact = re.sub(r"\s+", " ", message).strip()
    return compact[:117] + "..." if len(compact) > 120 else compact


@app.route("/chat/sessions", methods=["GET", "POST"])
@_owner_required
def chat_sessions():
    if request.method == "GET":
        include_archived = request.args.get("include_archived") == "true"
        limit = min(max(int(request.args.get("limit", 30)), 1), 100)
        with db_cursor() as (_connection, cursor):
            where = "user_id = %s" if include_archived else "user_id = %s AND is_archived = FALSE"
            cursor.execute(
                f"SELECT * FROM chat_sessions WHERE {where} ORDER BY last_message_at DESC NULLS LAST, created_at DESC LIMIT %s",
                (g.user_id, limit),
            )
            sessions = cursor.fetchall()
        return _response({"sessions": sessions})

    title = _text(_request_json().get("title"), "title", max_length=120)
    with db_cursor() as (_connection, cursor):
        session = _create_chat_session(cursor, g.user_id, title)
    return _response({"session": session}, 201)


@app.route("/chat/sessions/<session_id>", methods=["GET", "PATCH", "DELETE"])
@_owner_required
def chat_session_detail(session_id: str):
    with db_cursor() as (_connection, cursor):
        session = _get_chat_session(cursor, session_id, g.user_id)
        if request.method == "GET":
            return _response({"session": session})
        if request.method == "DELETE":
            cursor.execute("DELETE FROM chat_sessions WHERE session_id = %s AND user_id = %s", (session_id, g.user_id))
            return _response({"message": "Chat session deleted."})

        payload = _request_json()
        title = _text(payload.get("title", session["title"]), "title", required=True, max_length=120)
        archived = payload.get("is_archived", session["is_archived"])
        if not isinstance(archived, bool):
            raise ApiError("is_archived must be true or false.")
        cursor.execute(
            """
            UPDATE chat_sessions SET title = %s, is_archived = %s, updated_at = CURRENT_TIMESTAMP
            WHERE session_id = %s AND user_id = %s RETURNING *
            """,
            (title, archived, session_id, g.user_id),
        )
        return _response({"session": cursor.fetchone()})


@app.get("/chat/sessions/<session_id>/messages")
@_owner_required
def chat_history(session_id: str):
    limit = min(max(int(request.args.get("limit", 100)), 1), 100)
    with db_cursor() as (_connection, cursor):
        _get_chat_session(cursor, session_id, g.user_id)
        messages = _recent_chat_messages(cursor, session_id, limit)
    return _response({"messages": messages})


def _send_chat_message(payload: dict[str, Any], requested_session_id: str | None = None):
    message = _text(payload.get("message") or payload.get("question"), "message", required=True, max_length=4000)
    session_id = requested_session_id or _text(payload.get("session_id"), "session_id", max_length=36)
    with db_cursor() as (_connection, cursor):
        if session_id:
            session = _get_chat_session(cursor, session_id, g.user_id)
            if session["is_archived"]:
                raise ApiError("Unarchive this chat before sending a new message.", 409, "chat_archived")
        else:
            session = _create_chat_session(cursor, g.user_id)
            session_id = str(session["session_id"])

        user_message = _insert_chat_message(cursor, session_id, g.user_id, "user", message)
        history = _recent_chat_messages(cursor, session_id)
        generated = _generated_insights(cursor, g.user_id)
        story = build_expense_story([_json(item) for item in generated if item["status"] == "open"])
        context = _financial_context(cursor, g.user_id)
        answer = _agent_reply(
            cursor, g.user_id, message, [_json(item) for item in history], story, context
        )
        assistant_message = _insert_chat_message(
            cursor,
            session_id,
            g.user_id,
            "assistant",
            answer,
            {"story_insight_keys": story["insight_keys"]},
        )
        cursor.execute(
            """
            UPDATE chat_sessions SET title = CASE WHEN title = 'New expense chat' THEN %s ELSE title END,
              updated_at = CURRENT_TIMESTAMP, last_message_at = CURRENT_TIMESTAMP
            WHERE session_id = %s AND user_id = %s RETURNING *
            """,
            (_chat_title(message), session_id, g.user_id),
        )
        session = cursor.fetchone()
    return _response({"session": session, "user_message": user_message, "assistant_message": assistant_message, "answer": answer, "story": story})


@app.post("/chat/sessions/<session_id>/messages")
@_owner_required
@limiter.limit("30 per hour")
def send_chat_message(session_id: str):
    return _send_chat_message(_request_json(), session_id)


@app.post("/ai/agent/invoke")
@_owner_required
@limiter.limit("30 per hour")
def ai_agent_invoke():
    """Compatibility endpoint; now persists a multi-turn, safe chat session."""
    return _send_chat_message(_request_json())


@app.get("/me/export")
@_owner_required
def export_my_data():
    with db_cursor() as (_connection, cursor):
        cursor.execute("SELECT user_id, name, email, phone_no, created_at FROM customers WHERE user_id=%s", (g.user_id,))
        profile = cursor.fetchone()
        cursor.execute(f"SELECT {TRANSACTION_COLUMNS} FROM transactions WHERE user_id=%s ORDER BY date DESC", (g.user_id,))
        transactions = cursor.fetchall()
        cursor.execute("SELECT * FROM merchant_rules WHERE user_id=%s", (g.user_id,))
        rules = cursor.fetchall()
        cursor.execute("SELECT * FROM recurring_commitments WHERE user_id=%s", (g.user_id,))
        commitments = cursor.fetchall()
        cursor.execute("SELECT * FROM chat_sessions WHERE user_id=%s ORDER BY created_at", (g.user_id,))
        chat_sessions = cursor.fetchall()
        cursor.execute("SELECT * FROM chat_messages WHERE user_id=%s ORDER BY created_at, message_id", (g.user_id,))
        chat_messages = cursor.fetchall()
    return _response({"export": {
        "profile": profile,
        "transactions": transactions,
        "merchant_rules": rules,
        "commitments": commitments,
        "chat_sessions": chat_sessions,
        "chat_messages": chat_messages,
    }})


@app.delete("/me")
@_owner_required
def delete_my_account():
    password = _request_json().get("password")
    if not isinstance(password, str):
        raise ApiError("password is required to delete an account.")
    with db_cursor() as (_connection, cursor):
        cursor.execute("SELECT password FROM customers WHERE user_id = %s", (g.user_id,))
        account = cursor.fetchone()
        if not account or not bcrypt.check_password_hash(account["password"], password):
            raise ApiError("Password is incorrect.", 401, "invalid_credentials")
        cursor.execute("DELETE FROM customers WHERE user_id = %s", (g.user_id,))
    return _response({"message": "Your account and expense data have been deleted."})


if __name__ == "__main__":
    if os.getenv("FLASK_ENV") == "production" and app.config["JWT_SECRET_KEY"] == "development-only-change-me":
        raise RuntimeError("JWT_SECRET_KEY must be configured in production.")
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5001")), debug=False)
