import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supplier.dart';

class SupplierService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Supplier>> getSuppliers() async {
    final response = await _supabase
        .from('suppliers')
        .select()
        .eq('is_active', true)
        .order('supplier_code');

    return (response as List).map((item) => Supplier.fromMap(item)).toList();
  }

  Future<Supplier> createSupplier({
    required String supplierCode,
    required String name,
    String? phone,
    String? bankName,
    String? bankAccount,
    String? accountName,
    String? notes,
  }) async {
    final response = await _supabase
        .from('suppliers')
        .insert({
          'supplier_code': supplierCode,
          'name': name,
          'phone': phone,
          'bank_name': bankName,
          'bank_account': bankAccount,
          'account_name': accountName,
          'notes': notes,
        })
        .select()
        .single();

    return Supplier.fromMap(response);
  }

  Future<Supplier> updateSupplier({
    required String id,
    required String supplierCode,
    required String name,
    String? phone,
    String? bankName,
    String? bankAccount,
    String? accountName,
    String? notes,
  }) async {
    final response = await _supabase
        .from('suppliers')
        .update({
          'supplier_code': supplierCode,
          'name': name,
          'phone': phone,
          'bank_name': bankName,
          'bank_account': bankAccount,
          'account_name': accountName,
          'notes': notes,
        })
        .eq('id', id)
        .select()
        .single();

    return Supplier.fromMap(response);
  }

  Future<void> deactivateSupplier(String id) async {
    await _supabase.from('suppliers').update({'is_active': false}).eq('id', id);
  }
}
