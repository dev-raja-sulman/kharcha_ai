class ReceiptLineItemModel {
  final String description;
  final double? amount;
  final int quantity;

  const ReceiptLineItemModel({
    required this.description,
    this.amount,
    this.quantity = 1,
  });

  factory ReceiptLineItemModel.fromJson(Map<String, dynamic> json) {
    double? parsedAmount;
    if (json['amount'] != null) {
      parsedAmount = double.tryParse(json['amount'].toString());
    }

    return ReceiptLineItemModel(
      description: json['description']?.toString() ?? '',
      amount: parsedAmount,
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount?.toStringAsFixed(2),
        'quantity': quantity,
      };
}

class ReceiptScanModel {
  final String? merchantName;
  final double? amount;
  final DateTime? transactionDate;
  final String currency;
  final String suggestedCategory;
  final String? categoryExplanation;
  final List<ReceiptLineItemModel> lineItems;
  final double confidence;
  final List<String> warnings;
  final String? rawTextPreview;
  final String providerUsed;

  const ReceiptScanModel({
    this.merchantName,
    this.amount,
    this.transactionDate,
    this.currency = 'PKR',
    this.suggestedCategory = 'Other',
    this.categoryExplanation,
    this.lineItems = const [],
    this.confidence = 0.0,
    this.warnings = const [],
    this.rawTextPreview,
    this.providerUsed = 'gemini',
  });

  factory ReceiptScanModel.fromJson(Map<String, dynamic> json) {
    double? parsedAmount;
    if (json['amount'] != null) {
      parsedAmount = double.tryParse(json['amount'].toString());
    }

    DateTime? parsedDate;
    if (json['transaction_date'] != null) {
      parsedDate = DateTime.tryParse(json['transaction_date'].toString());
    }

    final itemsList = (json['line_items'] as List<dynamic>?)
            ?.map((e) => ReceiptLineItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final warningsList = (json['warnings'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    double conf = 0.0;
    if (json['confidence'] != null) {
      conf = double.tryParse(json['confidence'].toString()) ?? 0.0;
    }

    return ReceiptScanModel(
      merchantName: json['merchant_name']?.toString(),
      amount: parsedAmount,
      transactionDate: parsedDate,
      currency: json['currency']?.toString() ?? 'PKR',
      suggestedCategory: json['suggested_category']?.toString() ?? 'Other',
      categoryExplanation: json['category_explanation']?.toString(),
      lineItems: itemsList,
      confidence: conf,
      warnings: warningsList,
      rawTextPreview: json['raw_text_preview']?.toString(),
      providerUsed: json['provider_used']?.toString() ?? 'gemini',
    );
  }
}
