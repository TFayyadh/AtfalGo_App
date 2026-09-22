import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../models/transaction.dart';
import '../../services/transaction_service.dart';
import '../../services/supplier_payment_allocation_service.dart';

import '../transactions/transactions_details_page.dart';

class CustomerDetailsPage extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsPage({super.key, required this.customer});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  final TransactionService _transactionService = TransactionService();
  final SupplierPaymentAllocationService _allocationService =
      SupplierPaymentAllocationService();

  List<Transaction> _transactions = [];
  bool _loadingTransactions = true;

  double _totalRmbRequested = 0;
  double _totalAmountIn = 0;
  double _totalSupplierCost = 0;
  double _totalMargin = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await _transactionService.getTransactionsByCustomer(
        widget.customer.id,
      );

      double totalRmbRequested = 0;
      double totalAmountIn = 0;
      double totalSupplierCost = 0;

      for (final transaction in transactions) {
        totalRmbRequested += transaction.rmbRequested;
        totalAmountIn += transaction.amountInRm ?? 0;

        totalSupplierCost += await _allocationService
            .getAllocatedAmountForTransaction(transaction.id);
      }

      final totalMargin = totalAmountIn - totalSupplierCost;

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _loadingTransactions = false;
        _totalRmbRequested = totalRmbRequested;
        _totalAmountIn = totalAmountIn;
        _totalSupplierCost = totalSupplierCost;
        _totalMargin = totalMargin;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingTransactions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading customer transactions: $e')),
      );
    }
  }

  String _value(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    return value;
  }

  //BUAT WIDGET BAWAH NI REUSABLE IN THE FUTURE

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  //BUAT WIDGET BAWAH NI REUSABLE IN THE FUTURE

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  //BUAT DATE BAWAH NI REUSABLE IN THE FUTURE

  String _dateKey(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.year}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(String dateKey) {
    final parts = dateKey.split('-');

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '$day ${months[month - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.customer.name?.isNotEmpty == true
              ? widget.customer.name!
              : widget.customer.customerCode,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  _detailRow('Customer Code', widget.customer.customerCode),

                  _detailRow('Name', _value(widget.customer.name)),

                  _detailRow('Phone', _value(widget.customer.phone)),

                  _detailRow('Alipay ID', _value(widget.customer.alipayId)),

                  _detailRow('Notes', _value(widget.customer.notes)),

                  Row(
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Chip(
                        label: Text(
                          widget.customer.isActive ? 'Active' : 'Inactive',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  _summaryRow(
                    'Total Transactions',
                    _transactions.length.toString(),
                  ),

                  _summaryRow(
                    'Total RMB Requested',
                    _totalRmbRequested.toStringAsFixed(2),
                  ),

                  _summaryRow(
                    'Total Amount In',
                    'RM ${_totalAmountIn.toStringAsFixed(2)}',
                  ),

                  _summaryRow(
                    'Total Supplier Cost',
                    'RM ${_totalSupplierCost.toStringAsFixed(2)}',
                  ),

                  _summaryRow(
                    'Total Margin',
                    'RM ${_totalMargin.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  if (_loadingTransactions)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_transactions.isEmpty)
                    const Text('No transactions found.')
                  else
                    Builder(
                      builder: (context) {
                        final groupedTransactions =
                            <String, List<Transaction>>{};

                        for (final transaction in _transactions) {
                          final key = _dateKey(transaction.transactionDate);

                          groupedTransactions.putIfAbsent(key, () => []);

                          groupedTransactions[key]!.add(transaction);
                        }

                        final dateKeys = groupedTransactions.keys.toList()
                          ..sort((a, b) => b.compareTo(a));

                        return Column(
                          children: dateKeys.map((dateKey) {
                            final transactions = groupedTransactions[dateKey]!;

                            return ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              title: Text(
                                _formatDate(dateKey),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${transactions.length} '
                                '${transactions.length == 1 ? 'transaction' : 'transactions'}',
                              ),
                              children: transactions.map((transaction) {
                                return ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 16,
                                    right: 8,
                                  ),
                                  title: Text(
                                    transaction.transactionNo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RMB Requested: '
                                        '${transaction.rmbRequested.toStringAsFixed(2)}',
                                      ),
                                      Text(
                                        'Amount In: RM '
                                        '${(transaction.amountInRm ?? 0).toStringAsFixed(2)}',
                                      ),
                                      Text(
                                        'Status: '
                                        '${transaction.status}',
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TransactionDetailsPage(
                                          transaction: transaction,
                                        ),
                                      ),
                                    );

                                    await _loadTransactions();
                                  },
                                );
                              }).toList(),
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
