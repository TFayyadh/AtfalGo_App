import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';

class TransactionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Transaction>> getTransactions() async {
    final response = await _supabase
        .from('transactions')
        .select()
        .order('transaction_date', ascending: false);

    return (response as List).map((item) => Transaction.fromMap(item)).toList();
  }

  Future<Transaction> createTransaction({
    required String transactionNo,
    required String customerId,
    String? supplierId,
    required DateTime transactionDate,
    required double rmbRequested,
    required double customerRate,
    String? notes,
  }) async {
    // Amount In = RMB Requested ÷ Customer Rate
    final amountInRm = (rmbRequested / customerRate * 100).round() / 100;

    final response = await _supabase
        .from('transactions')
        .insert({
          'transaction_no': transactionNo,
          'customer_id': customerId,
          'supplier_id': supplierId,
          'transaction_date': transactionDate.toIso8601String(),
          'rmb_requested': rmbRequested,
          'amount_in_rm': amountInRm,

          // Supplier cost is now calculated from
          // supplier_payment_allocations.
          'amount_out_rm': null,
          'margin_rm': null,

          'customer_rate': customerRate,

          // Supplier rate no longer belongs to the transaction.
          'supplier_rate': null,

          'status': 'pending',
          'notes': notes,
        })
        .select()
        .single();

    return Transaction.fromMap(response);
  }

  Future<void> updateTransactionStatus({
    required String id,
    required String status,
  }) async {
    await _supabase
        .from('transactions')
        .update({'status': status})
        .eq('id', id);
  }

  Future<List<Transaction>> getPendingTransactions() async {
    final response = await _supabase
        .from('transactions')
        .select()
        .inFilter('status', ['pending', 'customer_paid', 'supplier_paid'])
        .order('transaction_date', ascending: true);

    return (response as List).map((item) => Transaction.fromMap(item)).toList();
  }
}
