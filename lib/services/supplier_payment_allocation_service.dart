import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierPaymentAllocationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> createAllocation({
    required String supplierPaymentId,
    required String transactionId,
    required double rmbAllocated,
    required double supplierRate,
  }) async {
    if (rmbAllocated <= 0) {
      throw Exception('RMB allocation must be greater than 0.');
    }

    if (supplierRate <= 0) {
      throw Exception('Supplier rate must be greater than 0.');
    }

    final existingAllocation = await _supabase
        .from('supplier_payment_allocations')
        .select('id')
        .eq('supplier_payment_id', supplierPaymentId)
        .eq('transaction_id', transactionId)
        .maybeSingle();

    if (existingAllocation != null) {
      throw Exception(
        'This transaction is already allocated to this supplier payment.',
      );
    }

    // Calculate RM allocation and round to 2 decimals.
    final amountRm = (rmbAllocated / supplierRate * 100).round() / 100;

    // ------------------------------------------------------------
    // 1. Check supplier payment remaining RM
    // ------------------------------------------------------------

    final payment = await _supabase
        .from('supplier_payments')
        .select('amount_rm, status')
        .eq('id', supplierPaymentId)
        .single();

    final paymentAmount = (payment['amount_rm'] as num).toDouble();
    final paymentStatus = payment['status'] as String;

    if (paymentStatus == 'completed') {
      throw Exception('This supplier payment is already completed.');
    }

    final paymentAllocations = await _supabase
        .from('supplier_payment_allocations')
        .select('amount_rm')
        .eq('supplier_payment_id', supplierPaymentId);

    double totalPaymentAllocated = 0;

    for (final item in paymentAllocations as List) {
      final value = item['amount_rm'];

      if (value != null) {
        totalPaymentAllocated += (value as num).toDouble();
      }
    }

    final remainingPayment =
        ((paymentAmount - totalPaymentAllocated) * 100).round() / 100;

    if ((amountRm * 100).round() > (remainingPayment * 100).round()) {
      throw Exception(
        'Allocation exceeds the remaining supplier payment '
        'amount of RM ${remainingPayment.toStringAsFixed(2)}.',
      );
    }

    // ------------------------------------------------------------
    // 2. Check transaction remaining RMB
    // ------------------------------------------------------------

    final transaction = await _supabase
        .from('transactions')
        .select('rmb_requested, status')
        .eq('id', transactionId)
        .single();

    final rmbRequested = (transaction['rmb_requested'] as num).toDouble();

    final transactionStatus = transaction['status'] as String;

    if (transactionStatus == 'completed') {
      throw Exception('This transaction is already fully allocated.');
    }

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

    final remainingRmb =
        ((rmbRequested - totalRmbAllocated) * 100).round() / 100;

    if ((rmbAllocated * 100).round() > (remainingRmb * 100).round()) {
      throw Exception(
        'Allocation exceeds the remaining transaction amount '
        'of ¥${remainingRmb.toStringAsFixed(2)}.',
      );
    }

    // ------------------------------------------------------------
    // 3. Insert allocation only after ALL validation passes
    // ------------------------------------------------------------

    await _supabase.from('supplier_payment_allocations').insert({
      'supplier_payment_id': supplierPaymentId,
      'transaction_id': transactionId,
      'rmb_allocated': rmbAllocated,
      'supplier_rate': supplierRate,
      'amount_rm': amountRm,
    });

    // ------------------------------------------------------------
    // 4. Re-check supplier payment total and complete if fully used
    // ------------------------------------------------------------

    final updatedPaymentAllocations = await _supabase
        .from('supplier_payment_allocations')
        .select('amount_rm')
        .eq('supplier_payment_id', supplierPaymentId);

    double updatedPaymentAllocated = 0;

    for (final item in updatedPaymentAllocations as List) {
      final value = item['amount_rm'];

      if (value != null) {
        updatedPaymentAllocated += (value as num).toDouble();
      }
    }

    final updatedPaymentRemaining =
        ((paymentAmount - updatedPaymentAllocated) * 100).round() / 100;

    if (updatedPaymentRemaining <= 0.00) {
      await _supabase
          .from('supplier_payments')
          .update({'status': 'completed'})
          .eq('id', supplierPaymentId);
    }

    // ------------------------------------------------------------
    // 5. Re-check transaction total and complete if fully allocated
    // ------------------------------------------------------------

    final updatedTransactionAllocations = await _supabase
        .from('supplier_payment_allocations')
        .select('rmb_allocated')
        .eq('transaction_id', transactionId);

    double updatedTransactionRmbAllocated = 0;

    for (final item in updatedTransactionAllocations as List) {
      final value = item['rmb_allocated'];

      if (value != null) {
        updatedTransactionRmbAllocated += (value as num).toDouble();
      }
    }

    final updatedTransactionRemaining =
        ((rmbRequested - updatedTransactionRmbAllocated) * 100).round() / 100;

    if (updatedTransactionRemaining <= 0.00) {
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

  Future<Map<String, double>> getAllocatedAmountsForTransactions(
    List<String> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return {};

    final response = await _supabase
        .from('supplier_payment_allocations')
        .select('transaction_id, amount_rm')
        .inFilter('transaction_id', transactionIds);

    final totals = <String, double>{};

    for (final item in response as List) {
      final transactionId = item['transaction_id'] as String;
      final amountRm = (item['amount_rm'] as num?)?.toDouble() ?? 0;

      totals[transactionId] = (totals[transactionId] ?? 0) + amountRm;
    }

    return totals;
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

  // GET ALLOCATED RMB FOR MULTIPLE TRANSACTIONS

  Future<Map<String, double>> getAllocatedRmbForTransactions(
    List<String> transactionIds,
  ) async {
    if (transactionIds.isEmpty) {
      return {};
    }

    final response = await _supabase
        .from('supplier_payment_allocations')
        .select('transaction_id, rmb_allocated')
        .inFilter('transaction_id', transactionIds);

    final totals = <String, double>{};

    for (final item in response as List) {
      final transactionId = item['transaction_id'] as String;
      final rmbAllocated = (item['rmb_allocated'] as num?)?.toDouble() ?? 0;

      totals[transactionId] = (totals[transactionId] ?? 0) + rmbAllocated;
    }

    return totals;
  }

  Future<List<Map<String, dynamic>>> getAllocationsForPayment(
    String supplierPaymentId,
  ) async {
    final response = await _supabase
        .from('supplier_payment_allocations')
        .select('''
        *,
        transactions (
        id,
          transaction_no,
          rmb_requested,
          customer_id,
          customers (
            customer_code,
            name
          )
        )
      ''')
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
