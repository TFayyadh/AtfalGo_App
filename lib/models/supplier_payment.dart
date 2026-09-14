class SupplierPayment {
  final String id;
  final String paymentNo;
  final String supplierId;
  final DateTime paymentDate;
  final double amountRm;
  final String? paymentMethod;
  final String? referenceNo;
  final String status;
  final String? notes;

  SupplierPayment({
    required this.id,
    required this.paymentNo,
    required this.supplierId,
    required this.paymentDate,
    required this.amountRm,
    this.paymentMethod,
    this.referenceNo,
    required this.status,
    this.notes,
  });

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupplierPayment(
      id: map['id'] as String,
      paymentNo: map['payment_no'] as String,
      supplierId: map['supplier_id'] as String,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      amountRm: (map['amount_rm'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String?,
      referenceNo: map['reference_no'] as String?,
      status: map['status'] as String,
      notes: map['notes'] as String?,
    );
  }
}
