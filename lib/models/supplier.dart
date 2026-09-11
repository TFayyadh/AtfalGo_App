class Supplier {
  final String id;
  final String supplierCode;
  final String name;
  final String? phone;
  final String? bankName;
  final String? bankAccount;
  final String? accountName;
  final String? notes;
  final bool isActive;

  Supplier({
    required this.id,
    required this.supplierCode,
    required this.name,
    this.phone,
    this.bankName,
    this.bankAccount,
    this.accountName,
    this.notes,
    required this.isActive,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      supplierCode: map['supplier_code'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      bankName: map['bank_name'] as String?,
      bankAccount: map['bank_account'] as String?,
      accountName: map['account_name'] as String?,
      notes: map['notes'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
