"""Deterministic, explainable expense insights.

This module deliberately contains no database or model calls.  Keeping the
signal generation pure makes the rules testable and prevents an LLM from
inventing financial facts or altering a user's ledger.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from statistics import median
from typing import Any, Iterable


def _as_datetime(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, date):
        return datetime.combine(value, datetime.min.time(), tzinfo=timezone.utc)
    return datetime.fromisoformat(str(value).replace("Z", "+00:00")).astimezone(
        timezone.utc
    )


def _amount(value: Any) -> Decimal:
    return value if isinstance(value, Decimal) else Decimal(str(value))


def _money(value: Decimal) -> float:
    return float(value.quantize(Decimal("0.01")))


def _insight(
    key: str,
    kind: str,
    title: str,
    message: str,
    confidence: float,
    amount: Decimal,
    evidence: dict[str, Any],
    projected_annual_cost: Decimal | None = None,
) -> dict[str, Any]:
    return {
        "insight_key": key,
        "kind": kind,
        "title": title,
        "message": message,
        "confidence": confidence,
        "amount": _money(amount),
        "projected_annual_cost": (
            _money(projected_annual_cost) if projected_annual_cost is not None else None
        ),
        "evidence": evidence,
    }


def build_expense_insights(
    transactions: Iterable[dict[str, Any]],
    commitments: Iterable[dict[str, Any]],
    *,
    now: datetime | None = None,
) -> list[dict[str, Any]]:
    """Return high-confidence expense signals for a single user.

    Transactions must already be authorised and scoped to one user.  The
    returned evidence contains only the transaction ids and values that led to
    a conclusion, so the client can always explain an alert.
    """
    now = now or datetime.now(timezone.utc)
    expenses = [
        {
            **transaction,
            "date": _as_datetime(transaction["date"]),
            "amount": _amount(transaction["amount"]),
            "merchant": (transaction.get("merchant") or transaction.get("title") or "").strip(),
        }
        for transaction in transactions
        if transaction.get("transaction_type") == "Expense"
    ]
    insights: list[dict[str, Any]] = []
    by_merchant: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for transaction in expenses:
        if transaction["merchant"]:
            by_merchant[transaction["merchant"].casefold()].append(transaction)

    # Same merchant and amount within 24h is a useful duplicate-payment signal.
    for merchant_key, items in by_merchant.items():
        items.sort(key=lambda item: item["date"])
        for first, second in zip(items, items[1:]):
            if (
                first["amount"] == second["amount"]
                and second["date"] - first["date"] <= timedelta(hours=24)
            ):
                ids = sorted((str(first["transaction_id"]), str(second["transaction_id"])))
                insights.append(
                    _insight(
                        f"duplicate:{ids[0]}:{ids[1]}",
                        "possible_duplicate",
                        "Possible duplicate payment",
                        f"Two payments of ₹{_money(first['amount']):,.2f} to {first['merchant']} were recorded within 24 hours.",
                        0.92,
                        first["amount"],
                        {
                            "transaction_ids": ids,
                            "merchant": first["merchant"],
                            "time_difference_hours": round(
                                (second["date"] - first["date"]).total_seconds() / 3600, 1
                            ),
                        },
                    )
                )

    for merchant_key, items in by_merchant.items():
        items.sort(key=lambda item: item["date"])
        recent = items[-4:]
        if len(recent) >= 3:
            gaps = [
                (right["date"].date() - left["date"].date()).days
                for left, right in zip(recent, recent[1:])
            ]
            typical_gap = median(gaps)
            if 24 <= typical_gap <= 37 or 340 <= typical_gap <= 390:
                annual_multiplier = Decimal("12") if typical_gap < 100 else Decimal("1")
                average = sum((item["amount"] for item in recent), Decimal("0")) / len(recent)
                cadence = "monthly" if annual_multiplier == 12 else "yearly"
                next_due = recent[-1]["date"].date() + timedelta(days=round(typical_gap))
                insights.append(
                    _insight(
                        f"recurring:{merchant_key}:{cadence}",
                        "recurring_expense",
                        f"Likely {cadence} expense",
                        f"{recent[-1]['merchant']} has appeared {len(recent)} times at roughly {cadence} intervals. The next payment is likely around {next_due.isoformat()}.",
                        0.82,
                        average,
                        {
                            "transaction_ids": [str(item["transaction_id"]) for item in recent],
                            "merchant": recent[-1]["merchant"],
                            "cadence": cadence,
                            "typical_gap_days": typical_gap,
                            "next_expected_date": next_due.isoformat(),
                        },
                        average * annual_multiplier,
                    )
                )

        # Compare a merchant's most recent 30 days with the preceding 30 days.
        current_window = [item for item in items if item["date"] >= now - timedelta(days=30)]
        previous_window = [
            item
            for item in items
            if now - timedelta(days=60) <= item["date"] < now - timedelta(days=30)
        ]
        if current_window and previous_window:
            current_average = sum((item["amount"] for item in current_window), Decimal("0")) / len(current_window)
            previous_average = sum((item["amount"] for item in previous_window), Decimal("0")) / len(previous_window)
            increase = current_average - previous_average
            if previous_average > 0 and increase >= Decimal("100") and current_average >= previous_average * Decimal("1.20"):
                percent = int((increase / previous_average) * 100)
                insights.append(
                    _insight(
                        f"price-creep:{merchant_key}:{now.strftime('%Y-%m')}",
                        "price_creep",
                        "This merchant is costing more",
                        f"Your average payment to {items[-1]['merchant']} is {percent}% higher than in the previous 30 days.",
                        0.75,
                        increase,
                        {
                            "transaction_ids": [
                                str(item["transaction_id"])
                                for item in current_window + previous_window
                            ],
                            "merchant": items[-1]["merchant"],
                            "current_average": _money(current_average),
                            "previous_average": _money(previous_average),
                        },
                    )
                )

    for commitment in commitments:
        next_due = _as_datetime(commitment["next_due_date"]).date()
        days_until_due = (next_due - now.date()).days
        if 0 <= days_until_due <= 7:
            amount = _amount(commitment["expected_amount"])
            title = commitment["title"]
            time_label = "today" if days_until_due == 0 else f"in {days_until_due} days"
            insights.append(
                _insight(
                    f"commitment:{commitment['commitment_id']}:{next_due.isoformat()}",
                    "upcoming_commitment",
                    "Upcoming committed expense",
                    f"{title} of ₹{_money(amount):,.2f} is due {time_label} ({next_due.isoformat()}).",
                    1.0,
                    amount,
                    {
                        "commitment_id": str(commitment["commitment_id"]),
                        "next_due_date": next_due.isoformat(),
                        "frequency": commitment["frequency"],
                    },
                )
            )

    # Show urgent, actionable signals first and avoid a noisy feed.
    priority = {
        "possible_duplicate": 0,
        "upcoming_commitment": 1,
        "price_creep": 2,
        "recurring_expense": 3,
    }
    insights.sort(key=lambda item: (priority[item["kind"]], -item["confidence"], -item["amount"]))
    return insights[:20]


def build_expense_story(insights: Iterable[dict[str, Any]]) -> dict[str, Any]:
    """Create a compact, factual weekly story from generated insights."""
    selected = list(insights)[:3]
    if not selected:
        return {
            "headline": "Your expense story is still learning",
            "summary": "Add or import a few more expenses to receive explainable spending signals.",
            "insight_keys": [],
        }
    return {
        "headline": selected[0]["title"],
        "summary": " ".join(item["message"] for item in selected),
        "insight_keys": [item["insight_key"] for item in selected],
    }
