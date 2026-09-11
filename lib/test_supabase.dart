import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> testSupabase() async {
  final supabase = Supabase.instance.client;

  final customers = await supabase.from('customers').select();

  print('Customers: $customers');
}
