// Transaction domain model.
class Txn {
  final String id;
  final String title;
  final String? description;
  final String category;
  final double amount;
  final String type; // 'Income' | 'Expense'
  final DateTime date;
  final String? merchant;
  final String? paymentMethod;
  final bool isEssential;

  const Txn({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
    this.merchant,
    this.paymentMethod,
    this.isEssential = false,
  });

  // Converts the raw JSON shape returned by the Flask backend into a
  // normalized transaction with a real DateTime.
  factory Txn.fromJson(Map<String, dynamic> json) {
    return Txn(
      id: json['transaction_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      amount: double.parse(json['amount'].toString()),
      type: json['transaction_type'] as String,
      date: DateTime.parse(json['date'] as String),
      merchant: json['merchant'] as String?,
      paymentMethod: json['payment_method'] as String?,
      isEssential: json['is_essential'] == true,
    );
  }
}
