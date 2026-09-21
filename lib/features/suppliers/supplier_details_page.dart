import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../models/supplier_payment.dart';
import '../../services/supplier_payment_service.dart';
import '../../services/supplier_payment_allocation_service.dart';
import '../supplier_payments/supplier_payment_details_page.dart';

class SupplierDetailsPage extends StatefulWidget {
  final Supplier supplier;

  const SupplierDetailsPage({super.key, required this.supplier});

  @override
  State<SupplierDetailsPage> createState() => _SupplierDetailsPageState();
}

class _SupplierDetailsPageState extends State<SupplierDetailsPage> {
  final SupplierPaymentService _paymentService = SupplierPaymentService();

  final SupplierPaymentAllocationService _allocationService =
      SupplierPaymentAllocationService();

  final Map<String, double> _allocatedAmounts = {};

  List<SupplierPayment> _payments = [];
  bool _loadingPayments = true;

  String _formatPaymentDate(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

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

    final date = DateTime(year, month, day);

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
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final payments = await _paymentService.getSupplierPaymentsBySupplier(
        widget.supplier.id,
      );

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
        _allocatedAmounts
          ..clear()
          ..addAll(allocatedAmounts);
        _loadingPayments = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPayments = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading supplier payments: $e')),
      );
    }
  }

  double _remainingAmount(SupplierPayment payment) {
    final allocated = _allocatedAmounts[payment.id] ?? 0;
    final remaining = payment.amountRm - allocated;

    return remaining < 0 ? 0 : remaining;
  }

  String _value(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    return value;
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.supplier.name)),
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
                    'Supplier Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  _detailRow('Supplier Code', widget.supplier.supplierCode),

                  _detailRow('Name', widget.supplier.name),

                  _detailRow('Phone', _value(widget.supplier.phone)),

                  _detailRow('Bank Name', _value(widget.supplier.bankName)),

                  _detailRow(
                    'Bank Account',
                    _value(widget.supplier.bankAccount),
                  ),

                  _detailRow(
                    'Account Name',
                    _value(widget.supplier.accountName),
                  ),

                  _detailRow('Notes', _value(widget.supplier.notes)),

                  Row(
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Chip(
                        label: Text(
                          widget.supplier.isActive ? 'Active' : 'Inactive',
                        ),
                      ),
                    ],
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
                    'Payment History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  if (_loadingPayments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_payments.isEmpty)
                    const Text('No supplier payments found.')
                  else
                    Builder(
                      builder: (context) {
                        final groupedPayments =
                            <String, List<SupplierPayment>>{};

                        for (final payment in _payments) {
                          final key = _dateKey(payment.paymentDate);

                          groupedPayments.putIfAbsent(key, () => []);
                          groupedPayments[key]!.add(payment);
                        }

                        final dateKeys = groupedPayments.keys.toList()
                          ..sort((a, b) => b.compareTo(a));

                        return Column(
                          children: dateKeys.map((dateKey) {
                            final payments = groupedPayments[dateKey]!;
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
                                '${payments.length} '
                                '${payments.length == 1 ? 'payment' : 'payments'}',
                              ),
                              children: payments.map((payment) {
                                final allocated =
                                    _allocatedAmounts[payment.id] ?? 0;

                                final remaining = _remainingAmount(payment);

                                return ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 16,
                                    right: 8,
                                  ),
                                  title: Text(
                                    payment.paymentNo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Allocated: RM '
                                        '${allocated.toStringAsFixed(2)}',
                                      ),
                                      Text(
                                        'Remaining: RM '
                                        '${remaining.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: remaining <= 0.001
                                              ? Colors.green
                                              : null,
                                        ),
                                      ),
                                      Text(payment.status),
                                    ],
                                  ),
                                  trailing: Text(
                                    'RM ${payment.amountRm.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SupplierPaymentDetailsPage(
                                              payment: payment,
                                            ),
                                      ),
                                    );

                                    await _loadPayments();
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
