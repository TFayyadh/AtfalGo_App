import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';

class CustomerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Customer>> getCustomers() async {
    final response = await _supabase
        .from('customers')
        .select()
        .eq('is_active', true)
        .order('customer_code');

    return (response as List).map((item) => Customer.fromMap(item)).toList();
  }

  Future<Customer> createCustomer({
    required String customerCode,
    String? name,
    String? phone,
    String? alipayId,
    String? notes,
  }) async {
    final response = await _supabase
        .from('customers')
        .insert({
          'customer_code': customerCode,
          'name': name,
          'phone': phone,
          'alipay_id': alipayId,
          'notes': notes,
        })
        .select()
        .single();

    return Customer.fromMap(response);
  }

  Future<Customer> updateCustomer({
    required String id,
    required String customerCode,
    String? name,
    String? phone,
    String? alipayId,
    String? notes,
  }) async {
    final response = await _supabase
        .from('customers')
        .update({
          'customer_code': customerCode,
          'name': name,
          'phone': phone,
          'alipay_id': alipayId,
          'notes': notes,
        })
        .eq('id', id)
        .select()
        .single();

    return Customer.fromMap(response);
  }

  Future<void> deactivateCustomer(String id) async {
    await _supabase.from('customers').update({'is_active': false}).eq('id', id);
  }
}
