import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierPaymentAllocationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> createAllocation({
    required String supplierPaymentId,
    required String transactionId,
    required double amountRm,
  }) async {
    await _supabase.from('supplier_payment_allocations').insert({
      'supplier_payment_id': supplierPaymentId,
      'transaction_id': transactionId,
      'amount_rm': amountRm,
    });
  }

  Future<double> getAllocatedAmountForTransaction(String transactionId) async {
    final response = await _supabase
        .from('supplier_payment_allocations')
        .select('amount_rm')
        .eq('transaction_id', transactionId);

    double total = 0;

    for (final item in response as List) {
      total += (item['amount_rm'] as num).toDouble();
    }

    return total;
  }

  Future<double> getAllocatedAmountForPayment(String supplierPaymentId) async {
    final response = await _supabase
        .from('supplier_payment_allocations')
        .select('amount_rm')
        .eq('supplier_payment_id', supplierPaymentId);

    double total = 0;

    for (final item in response as List) {
      total += (item['amount_rm'] as num).toDouble();
    }

    return total;
  }

  Future<List<Map<String, dynamic>>> getAllocationsForPayment(
    String supplierPaymentId,
  ) async {
    final response = await _supabase
        .from('supplier_payment_allocations')
        .select()
        .eq('supplier_payment_id', supplierPaymentId);

    return List<Map<String, dynamic>>.from(response);
  }
}
