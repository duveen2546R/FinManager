class Commitment {
  final String id;
  final String title;
  final String? merchant;
  final double expectedAmount;
  final String frequency;
  final DateTime nextDueDate;
  final bool isEssential;
  final bool isActive;
  final String? notes;

  const Commitment({
    required this.id,
    required this.title,
    this.merchant,
    required this.expectedAmount,
    required this.frequency,
    required this.nextDueDate,
    required this.isEssential,
    required this.isActive,
    this.notes,
  });

  factory Commitment.fromJson(Map<String, dynamic> json) => Commitment(
    id: json['commitment_id'] as String,
    title: json['title'] as String,
    merchant: json['merchant'] as String?,
    expectedAmount: double.parse(json['expected_amount'].toString()),
    frequency: json['frequency'] as String,
    nextDueDate: DateTime.parse(json['next_due_date'] as String),
    isEssential: json['is_essential'] == true,
    isActive: json['is_active'] == true,
    notes: json['notes'] as String?,
  );
}

class MerchantRule {
  final String id;
  final String pattern;
  final String? displayMerchant;
  final String? category;
  final bool? isEssential;

  const MerchantRule({
    required this.id,
    required this.pattern,
    this.displayMerchant,
    this.category,
    this.isEssential,
  });

  factory MerchantRule.fromJson(Map<String, dynamic> json) => MerchantRule(
    id: json['rule_id'] as String,
    pattern: json['merchant_pattern'] as String,
    displayMerchant: json['display_merchant'] as String?,
    category: json['category'] as String?,
    isEssential: json['is_essential'] as bool?,
  );
}

class ImportItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String transactionType;
  final DateTime date;
  final String? merchant;
  final String status;

  const ImportItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.transactionType,
    required this.date,
    this.merchant,
    required this.status,
  });

  factory ImportItem.fromJson(Map<String, dynamic> json) => ImportItem(
    id: json['item_id'] as String,
    title: json['title'] as String,
    amount: double.parse(json['amount'].toString()),
    category: json['category'] as String,
    transactionType: json['transaction_type'] as String,
    date: DateTime.parse((json['transaction_date'] ?? json['date']) as String),
    merchant: json['merchant'] as String?,
    status: json['status'] as String,
  );
}

class ImportBatch {
  final String id;
  final String source;
  final String status;
  final List<ImportItem> items;

  const ImportBatch({
    required this.id,
    required this.source,
    required this.status,
    required this.items,
  });

  factory ImportBatch.fromResponse(Map<String, dynamic> json) {
    final batch = json['import'] as Map<String, dynamic>;
    return ImportBatch(
      id: batch['import_id'] as String,
      source: batch['source'] as String,
      status: batch['status'] as String,
      items: ((json['items'] as List?) ?? [])
          .map((item) => ImportItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
