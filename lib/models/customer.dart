class Customer {
  final String id;
  final String customerCode;
  final String? name;
  final String? phone;
  final String? alipayId;
  final String? notes;
  final bool isActive;

  Customer({
    required this.id,
    required this.customerCode,
    this.name,
    this.phone,
    this.alipayId,
    this.notes,
    required this.isActive,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      customerCode: map['customer_code'] as String,
      name: map['name'] as String?,
      phone: map['phone'] as String?,
      alipayId: map['alipay_id'] as String?,
      notes: map['notes'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
