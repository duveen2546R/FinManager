// Deterministic expense insights served by GET /expense-insights.
class Insight {
  final String id;
  final String kind;
  final String title;
  final String message;
  final double confidence;
  final double? amount;
  final double? projectedAnnualCost;
  final String status; // open | helpful | incorrect | expected | ignored

  const Insight({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.confidence,
    this.amount,
    this.projectedAnnualCost,
    required this.status,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    return Insight(
      id: json['insight_id'] as String,
      kind: (json['kind'] as String?) ?? 'insight',
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      confidence: toDouble(json['confidence']) ?? 0,
      amount: toDouble(json['amount']),
      projectedAnnualCost: toDouble(json['projected_annual_cost']),
      status: (json['status'] as String?) ?? 'open',
    );
  }
}

// Spending guidance from GET /expense-guidance.
class Guidance {
  final double currentFlexibleSpend;
  final double historicalMonthlyAverage;
  final double upcomingCommitments30Days;
  final double recommendedWeeklyLimit;
  final String note;

  const Guidance({
    required this.currentFlexibleSpend,
    required this.historicalMonthlyAverage,
    required this.upcomingCommitments30Days,
    required this.recommendedWeeklyLimit,
    required this.note,
  });

  factory Guidance.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => double.tryParse(v.toString()) ?? 0;
    return Guidance(
      currentFlexibleSpend: toDouble(json['current_flexible_spend']),
      historicalMonthlyAverage: toDouble(json['historical_monthly_average']),
      upcomingCommitments30Days:
          toDouble(json['upcoming_commitments_30_days']),
      recommendedWeeklyLimit: toDouble(json['recommended_weekly_limit']),
      note: (json['note'] as String?) ?? '',
    );
  }
}
