import 'package:flutter/material.dart';

import '../customers/customers_page.dart';
import '../../services/auth_service.dart';
import '../../services/customer_service.dart';
import '../../services/supplier_service.dart';
import '../../services/transaction_service.dart';
import '../../services/supplier_payment_service.dart';
import '../../services/supplier_payment_allocation_service.dart';

import '../../models/transaction.dart';
import '../../models/supplier_payment.dart';

import '../../features/suppliers/supplier_page.dart';
import '../../features/transactions/transactions_page.dart';
import '../../features/supplier_payments/supplier_payments_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;

  int _totalCustomers = 0;
  int _totalSuppliers = 0;
  int _totalTransactions = 0;
  int _totalSupplierPayments = 0;
  int _pendingTransactions = 0;
  int _pendingSupplierPayments = 0;

  double _totalRmbRequested = 0;
  double _totalAmountIn = 0;
  double _totalSupplierCost = 0;
  double _totalMargin = 0;

  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();
  final TransactionService _transactionService = TransactionService();
  final SupplierPaymentService _supplierPaymentService =
      SupplierPaymentService();
  final SupplierPaymentAllocationService _allocationService =
      SupplierPaymentAllocationService();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final results = await Future.wait([
        _customerService.getCustomers(),
        _supplierService.getSuppliers(),
        _transactionService.getTransactions(),
        _supplierPaymentService.getSupplierPayments(),
      ]);

      final transactions = results[2] as List<Transaction>;

      final supplierPayments = results[3] as List<SupplierPayment>;

      int pendingTransactions = 0;
      int pendingSupplierPayments = 0;

      double totalRmbRequested = 0;
      double totalAmountIn = 0;
      double totalSupplierCost = 0;

      for (final transaction in transactions) {
        totalRmbRequested += transaction.rmbRequested;
        totalAmountIn += transaction.amountInRm ?? 0;
      }
      for (final transaction in transactions) {
        totalSupplierCost += await _allocationService
            .getAllocatedAmountForTransaction(transaction.id);
      }

      for (final transaction in transactions) {
        if (transaction.status == 'pending') {
          pendingTransactions++;
        }
      }

      for (final payment in supplierPayments) {
        if (payment.status == 'pending') {
          pendingSupplierPayments++;
        }
      }

      final totalMargin = totalAmountIn - totalSupplierCost;

      if (!mounted) return;

      setState(() {
        _totalCustomers = results[0].length;
        _totalSuppliers = results[1].length;
        _totalTransactions = transactions.length;
        _totalSupplierPayments = results[3].length;

        _totalRmbRequested = totalRmbRequested;
        _totalAmountIn = totalAmountIn;
        _totalSupplierCost = totalSupplierCost;
        _totalMargin = totalMargin;
        _pendingTransactions = pendingTransactions;
        _pendingSupplierPayments = pendingSupplierPayments;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
    }
  }

  String _formatCompactAmount(double amount) {
    final absAmount = amount.abs();

    double value;
    String suffix;

    if (absAmount >= 1000000000) {
      value = amount / 1000000000;
      suffix = 'B';
    } else if (absAmount >= 1000000) {
      value = amount / 1000000;
      suffix = 'M';
    } else if (absAmount >= 1000) {
      value = amount / 1000;
      suffix = 'K';
    } else {
      return amount.toStringAsFixed(0);
    }

    final formatted = value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '');

    return '$formatted$suffix';
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Summary
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            'Customers',
                            _totalCustomers.toString(),
                            Icons.people,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            'Transactions',
                            _totalTransactions.toString(),
                            Icons.swap_horiz,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            'RMB Requested',
                            '${_formatCompactAmount(_totalRmbRequested)} RMB',
                            Icons.currency_exchange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            'RM Received',
                            'RM ${_formatCompactAmount(_totalAmountIn)}',
                            Icons.account_balance_wallet,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            'Supplier Cost',
                            'RM ${_formatCompactAmount(_totalSupplierCost)}',
                            Icons.account_balance,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            'Total Margin',
                            'RM ${_formatCompactAmount(_totalMargin)}',
                            Icons.trending_up,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TransactionsPage(
                                    showPendingOnly: true,
                                  ),
                                ),
                              );

                              await _loadDashboard();
                            },
                            child: _summaryCard(
                              'Pending Transactions',
                              _pendingTransactions.toString(),
                              Icons.pending_actions,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SupplierPaymentsPage(
                                        showPendingOnly: true,
                                      ),
                                ),
                              );

                              await _loadDashboard();
                            },
                            child: _summaryCard(
                              'Pending Payments',
                              _pendingSupplierPayments.toString(),
                              Icons.hourglass_empty,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Existing Customers card
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.people)),
                        title: const Text(
                          'Customers',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Manage customers'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CustomersPage(),
                            ),
                          );

                          await _loadDashboard();
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Existing Suppliers card
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.business),
                        ),
                        title: const Text(
                          'Suppliers',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Manage Suppliers'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SuppliersPage(),
                            ),
                          );

                          await _loadDashboard();
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Existing Supplier Payments card
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.payment)),
                        title: const Text(
                          'Supplier Payments',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Record RM payments to suppliers'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SupplierPaymentsPage(),
                            ),
                          );

                          await _loadDashboard();
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Existing Transactions card
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.swap_horiz),
                        ),
                        title: const Text(
                          'Transactions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Manage transactions'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TransactionsPage(),
                            ),
                          );

                          await _loadDashboard();
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
