import 'package:flutter/material.dart';

import '../../models/supplier_payment.dart';
import '../../models/transaction.dart';
import '../../services/supplier_payment_allocation_service.dart';
import '../../services/transaction_service.dart';

class SupplierPaymentAllocationPage extends StatefulWidget {
  final SupplierPayment payment;

  const SupplierPaymentAllocationPage({super.key, required this.payment});

  @override
  State<SupplierPaymentAllocationPage> createState() =>
      _SupplierPaymentAllocationPageState();
}

class _SupplierPaymentAllocationPageState
    extends State<SupplierPaymentAllocationPage> {
  final SupplierPaymentAllocationService _allocationService =
      SupplierPaymentAllocationService();

  final TransactionService _transactionService = TransactionService();

  List<Transaction> _transactions = [];

  final Map<String, TextEditingController> _rmbControllers = {};
  final Map<String, TextEditingController> _rateControllers = {};

  // Total RM already allocated from this supplier payment.
  double _allocatedAmount = 0;

  // Total RMB already allocated to each transaction,
  // across ALL supplier payments.
  final Map<String, double> _transactionAllocatedRmb = {};

  bool _isLoading = true;
  bool _isSaving = false;

  double get _remainingPaymentAmount =>
      widget.payment.amountRm - _allocatedAmount;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final controller in _rmbControllers.values) {
      controller.dispose();
    }

    for (final controller in _rateControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final transactions = await _transactionService.getPendingTransactions();

      final transactionRmbAllocationMap = <String, double>{};

      for (final transaction in transactions) {
        final totalRmbAllocated = await _allocationService
            .getAllocatedRmbForTransaction(transaction.id);

        transactionRmbAllocationMap[transaction.id] = totalRmbAllocated;
      }

      final allocated = await _allocationService.getAllocatedAmountForPayment(
        widget.payment.id,
      );

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _allocatedAmount = allocated;
        _transactionAllocatedRmb.addAll(transactionRmbAllocationMap);
        _isLoading = false;
      });

      for (final transaction in transactions) {
        _rmbControllers[transaction.id] = TextEditingController();

        _rateControllers[transaction.id] = TextEditingController();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
    }
  }

  double _getEnteredRmb(String transactionId) {
    final controller = _rmbControllers[transactionId];

    if (controller == null || controller.text.trim().isEmpty) {
      return 0;
    }

    return double.tryParse(controller.text.trim()) ?? 0;
  }

  double _getEnteredRate(String transactionId) {
    final controller = _rateControllers[transactionId];

    if (controller == null || controller.text.trim().isEmpty) {
      return 0;
    }

    return double.tryParse(controller.text.trim()) ?? 0;
  }

  double _getCalculatedRm(String transactionId) {
    final rmb = _getEnteredRmb(transactionId);
    final rate = _getEnteredRate(transactionId);

    if (rmb <= 0 || rate <= 0) {
      return 0;
    }

    return (rmb / rate * 100).round() / 100;
  }

  double get _enteredRmTotal {
    double total = 0;

    for (final transaction in _transactions) {
      total += _getCalculatedRm(transaction.id);
    }

    return total;
  }

  double get _afterNewAllocationRemaining =>
      _remainingPaymentAmount - _enteredRmTotal;

  Future<void> _saveAllocations() async {
    if (_isSaving) return;

    bool hasAllocation = false;

    for (final transaction in _transactions) {
      final rmb = _getEnteredRmb(transaction.id);

      if (rmb > 0) {
        hasAllocation = true;
        break;
      }
    }

    if (!hasAllocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one RMB allocation.'),
        ),
      );
      return;
    }

    // Check total RM against this supplier payment.
    final enteredRmTotal = _enteredRmTotal;

    if ((enteredRmTotal * 100).round() >
        (_remainingPaymentAmount * 100).round()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Allocation exceeds the remaining payment '
            'amount of RM '
            '${_remainingPaymentAmount.toStringAsFixed(2)}.',
          ),
        ),
      );
      return;
    }

    // Validate every transaction before saving anything.
    for (final transaction in _transactions) {
      final rmb = _getEnteredRmb(transaction.id);

      if (rmb <= 0) continue;

      final rate = _getEnteredRate(transaction.id);

      if (rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter a valid supplier rate for '
              '${transaction.transactionNo}.',
            ),
          ),
        );
        return;
      }

      final alreadyAllocated = _transactionAllocatedRmb[transaction.id] ?? 0;

      final remainingRmb = transaction.rmbRequested - alreadyAllocated;

      if ((rmb * 100).round() > (remainingRmb * 100).round()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${transaction.transactionNo} can only receive '
              '¥${remainingRmb.toStringAsFixed(2)} more.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      for (final transaction in _transactions) {
        final rmb = _getEnteredRmb(transaction.id);

        if (rmb <= 0) continue;

        final rate = _getEnteredRate(transaction.id);

        await _allocationService.createAllocation(
          supplierPaymentId: widget.payment.id,
          transactionId: transaction.id,
          rmbAllocated: rmb,
          supplierRate: rate,
        );
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save allocation: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allocate Supplier Payment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPaymentSummary(),
                const Divider(height: 1),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(
                          child: Text('No pending transactions found.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(_transactions[index]);
                          },
                        ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildPaymentSummary() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.payment.paymentNo,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Payment Amount: RM '
              '${widget.payment.amountRm.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Already Allocated: RM '
              '${_allocatedAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Remaining: RM '
              '${_remainingPaymentAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Text(
              'After New Allocation: RM '
              '${_afterNewAllocationRemaining.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final rmbController = _rmbControllers[transaction.id]!;

    final rateController = _rateControllers[transaction.id]!;

    final alreadyAllocated = _transactionAllocatedRmb[transaction.id] ?? 0;

    final remainingRmb = transaction.rmbRequested - alreadyAllocated;

    final isFullyAllocated = remainingRmb <= 0.001;

    final calculatedRm = _getCalculatedRm(transaction.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.transactionNo,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 6),

            Text(
              'RMB Requested: '
              '${transaction.rmbRequested.toStringAsFixed(2)}',
            ),

            const SizedBox(height: 4),

            Text(
              'RMB Allocated: '
              '${alreadyAllocated.toStringAsFixed(2)}',
            ),

            const SizedBox(height: 4),

            Text(
              'RMB Remaining: '
              '${remainingRmb < 0 ? '0.00' : remainingRmb.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (isFullyAllocated)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Fully Allocated',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

            TextField(
              controller: rmbController,
              enabled: !isFullyAllocated,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'RMB Allocation',
                prefixText: '¥ ',
                border: const OutlineInputBorder(),
                suffixIcon: isFullyAllocated ? const Icon(Icons.lock) : null,
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: rateController,
              enabled: !isFullyAllocated,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Supplier Rate',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 12),

            Text(
              'RM Amount: RM '
              '${calculatedRm.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAllocations,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Allocation'),
          ),
        ),
      ),
    );
  }
}
