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
    required double supplierRate,
    String? notes,
  }) async {
    // Standard rounding to 2 decimal places.
    final amountInRm = (rmbRequested / customerRate * 100).round() / 100;

    final amountOutRm = (rmbRequested / supplierRate * 100).round() / 100;

    final marginRm = ((amountInRm - amountOutRm) * 100).round() / 100;

    final response = await _supabase
        .from('transactions')
        .insert({
          'transaction_no': transactionNo,
          'customer_id': customerId,
          'supplier_id': supplierId,
          'transaction_date': transactionDate.toIso8601String(),
          'rmb_requested': rmbRequested,
          'amount_in_rm': amountInRm,
          'amount_out_rm': amountOutRm,
          'margin_rm': marginRm,
          'customer_rate': customerRate,
          'supplier_rate': supplierRate,
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
