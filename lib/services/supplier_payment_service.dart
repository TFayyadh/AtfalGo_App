import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier_payment.dart';

class SupplierPaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<SupplierPayment>> getSupplierPayments() async {
    final response = await _supabase
        .from('supplier_payments')
        .select()
        .order('payment_date', ascending: false);

    return (response as List)
        .map((item) => SupplierPayment.fromMap(item))
        .toList();
  }

  Future<SupplierPayment> createSupplierPayment({
    required String supplierId,
    required DateTime paymentDate,
    required double amountRm,
    String? paymentMethod,
    String? referenceNo,
    String? notes,
  }) async {
    final response = await _supabase
        .from('supplier_payments')
        .insert({
          'supplier_id': supplierId,
          'payment_date': paymentDate.toIso8601String(),
          'amount_rm': amountRm,
          'payment_method': paymentMethod,
          'reference_no': referenceNo,
          'status': 'pending',
          'notes': notes,
        })
        .select()
        .single();

    return SupplierPayment.fromMap(response);
  }

  Future<void> updateSupplierPaymentStatus({
    required String id,
    required String status,
  }) async {
    await _supabase
        .from('supplier_payments')
        .update({'status': status})
        .eq('id', id);
  }
}
