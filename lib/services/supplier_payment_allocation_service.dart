import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierPaymentAllocationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> createAllocation({
    required String supplierPaymentId,
    required String transactionId,
    required double rmbAllocated,
    required double supplierRate,
  }) async {
    final amountRm = (rmbAllocated / supplierRate * 100).round() / 100;

    await _supabase.from('supplier_payment_allocations').insert({
      'supplier_payment_id': supplierPaymentId,
      'transaction_id': transactionId,
      'amount_rm': amountRm,
      'rmb_allocated': rmbAllocated,
      'supplier_rate': supplierRate,
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

  Future<double> getAllocatedRmbForTransaction(String transactionId) async {
    final response = await _supabase
        .from('supplier_payment_allocations')
        .select('rmb_allocated')
        .eq('transaction_id', transactionId);

    double total = 0;

    for (final item in response as List) {
      final value = item['rmb_allocated'];

      if (value != null) {
        total += (value as num).toDouble();
      }
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
