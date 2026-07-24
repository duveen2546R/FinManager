from datetime import datetime, timedelta, timezone

from backend.expense_intelligence import build_expense_insights, build_expense_story


NOW = datetime(2026, 7, 24, tzinfo=timezone.utc)


def expense(transaction_id, merchant, amount, days_ago):
    return {
        "transaction_id": transaction_id,
        "merchant": merchant,
        "title": merchant,
        "amount": amount,
        "transaction_type": "Expense",
        "date": NOW - timedelta(days=days_ago),
    }


def test_detects_duplicate_payment_with_evidence():
    results = build_expense_insights(
        [expense("a", "Metro", "499", 2), expense("b", "Metro", "499", 1.5)],
        [],
        now=NOW,
    )

    duplicate = next(item for item in results if item["kind"] == "possible_duplicate")
    assert duplicate["evidence"]["transaction_ids"] == ["a", "b"]
    assert duplicate["amount"] == 499.0


def test_detects_monthly_recurring_expense_and_projected_cost():
    results = build_expense_insights(
        [
            expense("a", "StreamCo", "199", 89),
            expense("b", "StreamCo", "199", 59),
            expense("c", "StreamCo", "199", 29),
        ],
        [],
        now=NOW,
    )

    recurring = next(item for item in results if item["kind"] == "recurring_expense")
    assert recurring["projected_annual_cost"] == 2388.0
    assert recurring["evidence"]["cadence"] == "monthly"


def test_story_limits_the_user_to_three_signals():
    results = build_expense_insights(
        [expense("a", "Metro", "499", 2), expense("b", "Metro", "499", 1.5)],
        [
            {
                "commitment_id": "rent",
                "title": "Rent",
                "expected_amount": "20000",
                "frequency": "monthly",
                "next_due_date": "2026-07-25",
            }
        ],
        now=NOW,
    )

    story = build_expense_story(results)
    assert len(story["insight_keys"]) <= 3
    assert story["headline"] == "Possible duplicate payment"
