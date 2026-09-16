import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../models/transaction.dart';

import '../../services/customer_service.dart';
import '../../services/transaction_service.dart';

import '../transactions/transactions_details_page.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final TransactionService _transactionService = TransactionService();
  final CustomerService _customerService = CustomerService();

  List<Transaction> _transactions = [];
  List<Customer> _customers = [];

  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        _transactionService.getTransactions(),
        _customerService.getCustomers(),
      ]);

      if (!mounted) return;

      setState(() {
        _transactions = results[0] as List<Transaction>;
        _customers = results[1] as List<Customer>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading transactions: $e')));
    }
  }

  List<Transaction> get _filteredTransactions {
    if (_searchQuery.trim().isEmpty) {
      return _transactions;
    }

    final query = _searchQuery.trim().toLowerCase();

    return _transactions.where((transaction) {
      return transaction.transactionNo.toLowerCase().contains(query) ||
          transaction.customerId.toLowerCase().contains(query) ||
          transaction.status.toLowerCase().contains(query);
    }).toList();
  }

  String _customerName(String customerId) {
    final matches = _customers.where((customer) => customer.id == customerId);

    if (matches.isEmpty) {
      return customerId;
    }

    final customer = matches.first;

    if (customer.name != null && customer.name!.trim().isNotEmpty) {
      return '${customer.customerCode} - ${customer.name}';
    }

    return customer.customerCode;
  }

  String _formatMoney(double? value) {
    if (value == null) {
      return '-';
    }

    return 'RMB ${value.toStringAsFixed(2)}';
  }

  Future<void> _showTransactionDialog() async {
    final transactionNoController = TextEditingController();
    final rmbController = TextEditingController();
    final customerRateController = TextEditingController();
    final notesController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    Customer? selectedCustomer;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double? amountIn;

            final rmb = double.tryParse(rmbController.text);
            final customerRate = double.tryParse(customerRateController.text);

            if (rmb != null && customerRate != null && customerRate > 0) {
              amountIn = (rmb / customerRate * 100).round() / 100;
            }

            return AlertDialog(
              title: const Text('Add Transaction'),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: transactionNoController,
                          decoration: const InputDecoration(
                            labelText: 'Transaction No',
                            hintText: 'e.g. TXN001',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Transaction No is required';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<Customer>(
                          value: selectedCustomer,
                          decoration: const InputDecoration(
                            labelText: 'Customer',
                          ),
                          items: _customers.map((customer) {
                            return DropdownMenuItem<Customer>(
                              value: customer,
                              child: Text(
                                customer.name != null &&
                                        customer.name!.trim().isNotEmpty
                                    ? '${customer.customerCode} - ${customer.name}'
                                    : customer.customerCode,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCustomer = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a customer';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: rmbController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'RMB Requested',
                            hintText: 'e.g. 10000',
                          ),
                          onChanged: (_) {
                            setDialogState(() {});
                          },
                          validator: (value) {
                            final amount = double.tryParse(value ?? '');

                            if (amount == null || amount <= 0) {
                              return 'Enter a valid RMB amount';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: customerRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Customer Rate',
                            hintText: 'e.g. 1.63',
                          ),
                          onChanged: (_) {
                            setDialogState(() {});
                          },
                          validator: (value) {
                            final rate = double.tryParse(value ?? '');

                            if (rate == null || rate <= 0) {
                              return 'Enter a valid customer rate';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _CalculationRow(
                                  label: 'Amount In',
                                  value: _formatMoney(amountIn),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Notes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    try {
                      await _transactionService.createTransaction(
                        transactionNo: transactionNoController.text.trim(),
                        customerId: selectedCustomer!.id,
                        transactionDate: DateTime.now(),
                        rmbRequested: double.parse(rmbController.text.trim()),
                        customerRate: double.parse(
                          customerRateController.text.trim(),
                        ),
                        notes: notesController.text.trim(),
                      );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Error saving transaction: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showTransactionDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search transactions',
                hintText: 'Transaction No, customer or status',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                ? const Center(child: Text('No transactions found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransactionDetailsPage(
                                  transaction: transaction,
                                ),
                              ),
                            );

                            if (mounted) {
                              await _loadData();
                            }
                          },
                          title: Text(
                            transaction.transactionNo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer: ${_customerName(transaction.customerId)}',
                                ),
                                Text(
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  'RMB Requested: ${transaction.rmbRequested.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Amount In: ${_formatMoney(transaction.amountInRm)}',
                                ),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                transaction.status,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CalculationRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _CalculationRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
