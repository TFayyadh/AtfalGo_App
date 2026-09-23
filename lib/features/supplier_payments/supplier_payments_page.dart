import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../models/supplier_payment.dart';

import '../../services/supplier_service.dart';
import '../../services/supplier_payment_service.dart';
import '../../services/supplier_payment_allocation_service.dart';

import '../supplier_payment_allocations/supplier_payment_allocation_page.dart';
import 'supplier_payment_details_page.dart';

class SupplierPaymentsPage extends StatefulWidget {
  const SupplierPaymentsPage({super.key});

  @override
  State<SupplierPaymentsPage> createState() => _SupplierPaymentsPageState();
}

class _SupplierPaymentsPageState extends State<SupplierPaymentsPage> {
  final SupplierPaymentService _paymentService = SupplierPaymentService();

  final SupplierService _supplierService = SupplierService();

  final SupplierPaymentAllocationService _allocationService =
      SupplierPaymentAllocationService();

  List<SupplierPayment> _payments = [];
  List<Supplier> _suppliers = [];

  final Map<String, double> _allocatedAmounts = {};

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
        _paymentService.getSupplierPayments(),
        _supplierService.getSuppliers(),
      ]);

      final payments = results[0] as List<SupplierPayment>;
      final suppliers = results[1] as List<Supplier>;

      final allocationResults = await Future.wait(
        payments.map(
          (payment) =>
              _allocationService.getAllocatedAmountForPayment(payment.id),
        ),
      );

      final allocatedAmounts = <String, double>{};

      for (int i = 0; i < payments.length; i++) {
        allocatedAmounts[payments[i].id] = allocationResults[i];
      }

      if (!mounted) return;

      setState(() {
        _payments = payments;
        _suppliers = suppliers;
        _allocatedAmounts
          ..clear()
          ..addAll(allocatedAmounts);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading payments: $e')));
    }
  }

  List<SupplierPayment> get _filteredPayments {
    if (_searchQuery.trim().isEmpty) {
      return _payments;
    }

    final query = _searchQuery.trim().toLowerCase();

    return _payments.where((payment) {
      final supplier = _getSupplier(payment.supplierId);

      return payment.paymentNo.toLowerCase().contains(query) ||
          payment.status.toLowerCase().contains(query) ||
          (supplier?.supplierCode.toLowerCase().contains(query) ?? false) ||
          (supplier?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Supplier? _getSupplier(String supplierId) {
    final matches = _suppliers.where((supplier) => supplier.id == supplierId);

    if (matches.isEmpty) {
      return null;
    }

    return matches.first;
  }

  String _supplierName(String supplierId) {
    final supplier = _getSupplier(supplierId);

    if (supplier == null) {
      return supplierId;
    }

    return '${supplier.supplierCode} - ${supplier.name}';
  }

  String _formatMoney(double amount) {
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  double _allocatedAmount(String paymentId) {
    return _allocatedAmounts[paymentId] ?? 0;
  }

  double _remainingAmount(SupplierPayment payment) {
    final allocated = _allocatedAmount(payment.id);
    final remaining = payment.amountRm - allocated;

    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _showPaymentDialog() async {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    Supplier? selectedSupplier;
    String? selectedPaymentMethod;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Supplier Payment'),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<Supplier>(
                          value: selectedSupplier,
                          decoration: const InputDecoration(
                            labelText: 'Supplier',
                          ),
                          items: _suppliers.map((supplier) {
                            return DropdownMenuItem<Supplier>(
                              value: supplier,
                              child: Text(
                                '${supplier.supplierCode} - ${supplier.name}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSupplier = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a supplier';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount (RM)',
                            hintText: 'e.g. 6049.61',
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value ?? '');

                            if (amount == null || amount <= 0) {
                              return 'Enter a valid RM amount';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: selectedPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Bank Transfer',
                              child: Text('Bank Transfer'),
                            ),
                            DropdownMenuItem(
                              value: 'Cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(
                              value: 'Online Transfer',
                              child: Text('Online Transfer'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedPaymentMethod = value;
                            });
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: referenceController,
                          decoration: const InputDecoration(
                            labelText: 'Reference No',
                            hintText: 'e.g. bank transfer reference',
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
                      await _paymentService.createSupplierPayment(
                        supplierId: selectedSupplier!.id,
                        paymentDate: DateTime.now(),
                        amountRm: double.parse(amountController.text.trim()),
                        paymentMethod: selectedPaymentMethod,
                        referenceNo: referenceController.text.trim(),
                        notes: notesController.text.trim(),
                      );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Error saving payment: $e')),
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
    final payments = _filteredPayments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPaymentDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search payments',
                hintText: 'Payment No, supplier or status',
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
                : payments.isEmpty
                ? const Center(child: Text('No supplier payments found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final payment = payments[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(child: Icon(Icons.payment)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        payment.paymentNo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Supplier: ${_supplierName(payment.supplierId)}',
                                      ),
                                      Text(
                                        'Method: ${payment.paymentMethod ?? '-'}',
                                      ),
                                      Text(
                                        'Reference: ${payment.referenceNo ?? '-'}',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatMoney(payment.amountRm),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    Text(
                                      'Allocated: ${_formatMoney(_allocatedAmount(payment.id))}',
                                      style: const TextStyle(fontSize: 12),
                                    ),

                                    Text(
                                      'Remaining: ${_formatMoney(_remainingAmount(payment))}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _remainingAmount(payment) <= 0.001
                                            ? Colors.green
                                            : null,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      payment.status,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                SupplierPaymentDetailsPage(
                                                  payment: payment,
                                                ),
                                          ),
                                        );

                                        await _loadData();
                                      },
                                      child: const Text('View Details'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
