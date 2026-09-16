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

    // 1. Create allocation
    await _supabase.from('supplier_payment_allocations').insert({
      'supplier_payment_id': supplierPaymentId,
      'transaction_id': transactionId,
      'rmb_allocated': rmbAllocated,
      'supplier_rate': supplierRate,
      'amount_rm': amountRm,
    });

    // 2. Check supplier payment
    final payment = await _supabase
        .from('supplier_payments')
        .select('amount_rm')
        .eq('id', supplierPaymentId)
        .single();

    final paymentAmount = (payment['amount_rm'] as num).toDouble();

    final allocations = await _supabase
        .from('supplier_payment_allocations')
        .select('amount_rm')
        .eq('supplier_payment_id', supplierPaymentId);

    double totalAllocated = 0;

    for (final item in allocations as List) {
      final value = item['amount_rm'];

      if (value != null) {
        totalAllocated += (value as num).toDouble();
      }
    }

    final remainingPayment = paymentAmount - totalAllocated;

    // 3. Automatically complete supplier payment
    if (remainingPayment <= 0.001) {
      await _supabase
          .from('supplier_payments')
          .update({'status': 'completed'})
          .eq('id', supplierPaymentId);
    }

    // 4. Check transaction fulfillment
    final transaction = await _supabase
        .from('transactions')
        .select('rmb_requested')
        .eq('id', transactionId)
        .single();

    final rmbRequested = (transaction['rmb_requested'] as num).toDouble();

    final transactionAllocations = await _supabase
        .from('supplier_payment_allocations')
        .select('rmb_allocated')
        .eq('transaction_id', transactionId);

    double totalRmbAllocated = 0;

    for (final item in transactionAllocations as List) {
      final value = item['rmb_allocated'];

      if (value != null) {
        totalRmbAllocated += (value as num).toDouble();
      }
    }

    final remainingRmb = rmbRequested - totalRmbAllocated;

    // 5. Automatically complete transaction
    if (remainingRmb <= 0.001) {
      await _supabase
          .from('transactions')
          .update({'status': 'completed'})
          .eq('id', transactionId);
    }
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

  Future<List<Map<String, dynamic>>> getAllocationsForTransaction(
    String transactionId,
  ) async {
    final response = await _supabase
        .from('supplier_payment_allocations')
        .select('''
        *,
        supplier_payments (
          payment_no,
          supplier_id,
          suppliers (
            supplier_code,
            name
          )
        )
      ''')
        .eq('transaction_id', transactionId);

    return List<Map<String, dynamic>>.from(response);
  }
}
