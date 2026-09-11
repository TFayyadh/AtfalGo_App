class Transaction {
  final String id;
  final String transactionNo;
  final String customerId;
  final String? supplierId;
  final DateTime transactionDate;

  final double rmbRequested;
  final double? amountInRm;
  final double? amountOutRm;
  final double? marginRm;

  final double? customerRate;
  final double? supplierRate;

  final String status;
  final String? notes;

  Transaction({
    required this.id,
    required this.transactionNo,
    required this.customerId,
    this.supplierId,
    required this.transactionDate,
    required this.rmbRequested,
    this.amountInRm,
    this.amountOutRm,
    this.marginRm,
    this.customerRate,
    this.supplierRate,
    required this.status,
    this.notes,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      transactionNo: map['transaction_no'] as String,
      customerId: map['customer_id'] as String,
      supplierId: map['supplier_id'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      rmbRequested: (map['rmb_requested'] as num).toDouble(),
      amountInRm: (map['amount_in_rm'] as num?)?.toDouble(),
      amountOutRm: (map['amount_out_rm'] as num?)?.toDouble(),
      marginRm: (map['margin_rm'] as num?)?.toDouble(),
      customerRate: (map['customer_rate'] as num?)?.toDouble(),
      supplierRate: (map['supplier_rate'] as num?)?.toDouble(),
      status: map['status'] as String,
      notes: map['notes'] as String?,
    );
  }
}
