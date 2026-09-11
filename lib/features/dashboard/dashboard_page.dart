import 'package:flutter/material.dart';

import '../customers/customers_page.dart';
import '../../services/auth_service.dart';
import '../../features/suppliers/supplier_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AtfalGo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            // Customers
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.people)),
                title: const Text(
                  'Customers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Manage customers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomersPage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Suppliers - coming next
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.business)),
                title: const Text(
                  'Suppliers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Manage Suppliers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SuppliersPage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Transactions - coming next
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.swap_horiz)),
                title: const Text(
                  'Transactions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Coming soon'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
