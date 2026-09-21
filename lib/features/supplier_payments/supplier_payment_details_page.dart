import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../models/supplier_payment.dart';
import '../../services/supplier_payment_allocation_service.dart';
import '../../services/supplier_service.dart';
import '../supplier_payment_allocations/supplier_payment_allocation_page.dart';

class SupplierPaymentDetailsPage extends StatefulWidget {
  final SupplierPayment payment;

  const SupplierPaymentDetailsPage({super.key, required this.payment});

  @override
  State<SupplierPaymentDetailsPage> createState() =>
      _SupplierPaymentDetailsPageState();
}

class _SupplierPaymentDetailsPageState
    extends State<SupplierPaymentDetailsPage> {
  final SupplierService _supplierService = SupplierService();
  final SupplierPaymentAllocationService _allocationService =
      SupplierPaymentAllocationService();

  Supplier? _supplier;
  List<Map<String, dynamic>> _allocations = [];

  bool _loading = true;

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
        _supplierService.getSuppliers(),
        _allocationService.getAllocationsForPayment(widget.payment.id),
      ]);

      if (!mounted) return;

      final suppliers = results[0] as List<Supplier>;
      final allocations = results[1] as List<Map<String, dynamic>>;

      Supplier? supplier;

      for (final item in suppliers) {
        if (item.id == widget.payment.supplierId) {
          supplier = item;
          break;
        }
      }

      setState(() {
        _supplier = supplier;
        _allocations = allocations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment details: $e')),
      );
    }
  }

  double get _totalAllocatedRm {
    return _allocations.fold<double>(0, (total, allocation) {
      final amount = (allocation['amount_rm'] as num?)?.toDouble() ?? 0;

      return total + amount;
    });
  }

  double get _remainingRm {
    final remaining = widget.payment.amountRm - _totalAllocatedRm;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  String _formatMoney(double amount) {
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final supplierName = _supplier == null
        ? widget.payment.supplierId
        : '${_supplier!.supplierCode} - ${_supplier!.name}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildInfoRow('Payment No', widget.payment.paymentNo, bold: true),

            _buildInfoRow('Supplier', supplierName),

            _buildInfoRow(
              'Payment Date',
              _formatDate(widget.payment.paymentDate),
            ),

            const Divider(),

            _buildInfoRow(
              'Payment Amount',
              _formatMoney(widget.payment.amountRm),
              bold: true,
            ),

            _buildInfoRow('Allocated', _formatMoney(_totalAllocatedRm)),

            _buildInfoRow('Remaining', _formatMoney(_remainingRm), bold: true),

            _buildInfoRow('Status', widget.payment.status, bold: true),

            const Divider(),

            _buildInfoRow(
              'Payment Method',
              widget.payment.paymentMethod ?? '-',
            ),

            _buildInfoRow('Reference No', widget.payment.referenceNo ?? '-'),

            if (widget.payment.notes != null &&
                widget.payment.notes!.trim().isNotEmpty)
              _buildInfoRow('Notes', widget.payment.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationCard(Map<String, dynamic> allocation) {
    final rmbAllocated = (allocation['rmb_allocated'] as num?)?.toDouble();

    final supplierRate = (allocation['supplier_rate'] as num?)?.toDouble();

    final amountRm = (allocation['amount_rm'] as num?)?.toDouble();

    final transaction = allocation['transactions'] as Map<String, dynamic>?;

    final transactionNo = transaction?['transaction_no'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transaction',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _buildInfoRow('Transaction', transactionNo ?? '-', bold: true),

            _buildInfoRow(
              'RMB Allocated',
              rmbAllocated == null
                  ? '-'
                  : 'RMB ${rmbAllocated.toStringAsFixed(2)}',
            ),

            _buildInfoRow(
              'Supplier Rate',
              supplierRate == null ? '-' : supplierRate.toStringAsFixed(8),
            ),

            _buildInfoRow(
              'RM Allocation',
              amountRm == null ? '-' : _formatMoney(amountRm),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Transaction Allocations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_allocations.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_allocations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No allocations yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._allocations.map(_buildAllocationCard),
          ],
        ),
      ),
    );
  }

  Future<void> _openAllocationPage() async {
    if (widget.payment.status == 'completed') {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierPaymentAllocationPage(payment: widget.payment),
      ),
    );

    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.payment.paymentNo),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPaymentSummary(),

                  const SizedBox(height: 16),

                  _buildAllocationsSection(),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.payment.status == 'completed'
                          ? null
                          : _openAllocationPage,
                      icon: const Icon(Icons.add),
                      label: Text(
                        widget.payment.status == 'completed'
                            ? 'Payment Completed'
                            : 'Allocate Payment',
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
