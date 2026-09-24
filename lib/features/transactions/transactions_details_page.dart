import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/transaction.dart';
import '../../services/customer_service.dart';
import '../../services/supplier_payment_allocation_service.dart';

class TransactionDetailsPage extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailsPage({super.key, required this.transaction});

  @override
  State<TransactionDetailsPage> createState() => _TransactionDetailsPageState();
}

class _TransactionDetailsPageState extends State<TransactionDetailsPage> {
  final CustomerService _customerService = CustomerService();
  final SupplierPaymentAllocationService _allocationService =
      SupplierPaymentAllocationService();

  Customer? _customer;
  List<Map<String, dynamic>> _allocations = [];

  bool _isLoading = true;

  double get _totalRmbAllocated {
    double total = 0;

    for (final allocation in _allocations) {
      final value = allocation['rmb_allocated'];

      if (value != null) {
        total += (value as num).toDouble();
      }
    }

    return total;
  }

  double get _totalSupplierCost {
    double total = 0;

    for (final allocation in _allocations) {
      final value = allocation['amount_rm'];

      if (value != null) {
        total += (value as num).toDouble();
      }
    }

    return total;
  }

  double get _rmbRemaining {
    final remaining = widget.transaction.rmbRequested - _totalRmbAllocated;

    return remaining < 0 ? 0 : remaining;
  }

  double? get _margin {
    final amountIn = widget.transaction.amountInRm;

    if (amountIn == null) {
      return null;
    }

    return amountIn - _totalSupplierCost;
  }

  bool get _isFullyAllocated {
    return _rmbRemaining <= 0.001;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _customerService.getCustomers(),
        _allocationService.getAllocationsForTransaction(widget.transaction.id),
      ]);

      final customers = results[0] as List<Customer>;
      final allocations = results[1] as List<Map<String, dynamic>>;

      Customer? customer;

      for (final item in customers) {
        if (item.id == widget.transaction.customerId) {
          customer = item;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        _customer = customer;
        _allocations = allocations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading transaction details: $e')),
      );
    }
  }

  String _formatRm(double? value) {
    if (value == null) {
      return '-';
    }

    return 'RM ${value.toStringAsFixed(2)}';
  }

  String _formatRmb(double? value) {
    if (value == null) {
      return '-';
    }

    return 'RMB ${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction.transactionNo),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTransactionSummary(),
                  const SizedBox(height: 16),
                  _buildSupplierAllocations(),
                  const SizedBox(height: 16),
                  _transactionSummaryCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildTransactionSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            _DetailRow(
              label: 'Transaction No',
              value: widget.transaction.transactionNo,
            ),

            _DetailRow(
              label: 'Customer',
              value: _customer == null
                  ? widget.transaction.customerId
                  : _customer!.name != null &&
                        _customer!.name!.trim().isNotEmpty
                  ? '${_customer!.customerCode} - ${_customer!.name}'
                  : _customer!.customerCode,
            ),

            _DetailRow(
              label: 'RMB Requested',
              value: _formatRmb(widget.transaction.rmbRequested),
            ),

            _DetailRow(
              label: 'Customer Rate',
              value: widget.transaction.customerRate?.toStringAsFixed(4) ?? '-',
            ),

            _DetailRow(
              label: 'Amount In',
              value: _formatRm(widget.transaction.amountInRm),
            ),

            _DetailRow(label: 'Status', value: widget.transaction.status),
          ],
        ),
      ),
    );
  }

  Widget _transactionSummaryCard() {
    return Card(
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

            _DetailRow(
              label: 'RMB Requested',
              value: _formatRmb(widget.transaction.rmbRequested),
            ),

            _DetailRow(
              label: 'RMB Allocated',
              value: _formatRmb(_totalRmbAllocated),
            ),

            _DetailRow(
              label: 'RMB Remaining',
              value: _formatRmb(_rmbRemaining),
              bold: true,
            ),

            const Divider(height: 24),

            _DetailRow(
              label: 'Total Supplier Cost',
              value: _formatRm(_totalSupplierCost),
            ),

            _DetailRow(
              label: 'Margin',
              value: _margin == null ? '-' : _formatRm(_margin),
              bold: true,
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(),
              ),
              child: Text(
                _isFullyAllocated ? 'Fully Fulfilled' : 'Pending Fulfillment',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierAllocations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supplier Allocations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            if (_allocations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No supplier allocations yet.')),
              )
            else
              ..._allocations.map(
                (allocation) => _buildAllocationCard(allocation),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationCard(Map<String, dynamic> allocation) {
    final rmbAllocated = (allocation['rmb_allocated'] as num?)?.toDouble();

    final supplierRate = (allocation['supplier_rate'] as num?)?.toDouble();

    final amountRm = (allocation['amount_rm'] as num?)?.toDouble();

    final supplierPayment =
        allocation['supplier_payments'] as Map<String, dynamic>?;

    final supplier = supplierPayment?['suppliers'] as Map<String, dynamic>?;

    final supplierName = supplier == null
        ? 'Unknown Supplier'
        : '${supplier['supplier_code']} - ${supplier['name']}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplierName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          if (supplierPayment?['payment_no'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Payment: ${supplierPayment!['payment_no']}',
              style: const TextStyle(fontSize: 12),
            ),
          ],

          const SizedBox(height: 10),

          _DetailRow(label: 'RMB Allocated', value: _formatRmb(rmbAllocated)),

          _DetailRow(
            label: 'Supplier Rate',
            value: supplierRate?.toStringAsFixed(4) ?? '-',
          ),

          _DetailRow(label: 'RM Cost', value: _formatRm(amountRm)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
