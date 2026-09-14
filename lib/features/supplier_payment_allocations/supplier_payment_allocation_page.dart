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
  final Map<String, TextEditingController> _controllers = {};

  double _allocatedAmount = 0;
  final Map<String, double> _transactionAllocatedAmounts = {};

  bool _isLoading = true;
  bool _isSaving = false;

  double get _remainingAmount => widget.payment.amountRm - _allocatedAmount;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final transactions = await _transactionService.getPendingTransactions();

      final transactionAllocationMap = <String, double>{};

      for (final transaction in transactions) {
        final totalAllocated = await _allocationService
            .getAllocatedAmountForTransaction(transaction.id);

        transactionAllocationMap[transaction.id] = totalAllocated;
      }

      final allocated = await _allocationService.getAllocatedAmountForPayment(
        widget.payment.id,
      );

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _allocatedAmount = allocated;
        _transactionAllocatedAmounts.addAll(transactionAllocationMap);
        _isLoading = false;
      });

      for (final transaction in transactions) {
        _controllers[transaction.id] = TextEditingController();
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

  double _getEnteredAmount(String transactionId) {
    final controller = _controllers[transactionId];

    if (controller == null || controller.text.trim().isEmpty) {
      return 0;
    }

    return double.tryParse(controller.text.trim()) ?? 0;
  }

  double get _enteredTotal {
    double total = 0;

    for (final transaction in _transactions) {
      total += _getEnteredAmount(transaction.id);
    }

    return total;
  }

  Future<void> _saveAllocations() async {
    if (_isSaving) return;

    final enteredTotal = _enteredTotal;

    if (enteredTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one allocation amount.'),
        ),
      );
      return;
    }

    final availableAmount = _remainingAmount;

    if (enteredTotal > availableAmount + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Allocation exceeds remaining payment amount '
            'of RM ${availableAmount.toStringAsFixed(2)}.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    for (final transaction in _transactions) {
      final amount = _getEnteredAmount(transaction.id);

      if (amount <= 0) continue;

      final totalAllocated = _transactionAllocatedAmounts[transaction.id] ?? 0;

      final amountOut = transaction.amountOutRm ?? 0;

      final remainingTransactionAmount = amountOut - totalAllocated;

      if (amount > remainingTransactionAmount + 0.01) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${transaction.transactionNo} can only receive '
              'RM ${remainingTransactionAmount.toStringAsFixed(2)} '
              'more.',
            ),
          ),
        );

        setState(() {
          _isSaving = false;
        });

        return;
      }

      await _allocationService.createAllocation(
        supplierPaymentId: widget.payment.id,
        transactionId: transaction.id,
        amountRm: amount,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enteredTotal = _enteredTotal;
    final afterEntryRemaining = _remainingAmount - enteredTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Allocate Supplier Payment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPaymentSummary(afterEntryRemaining),
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

  Widget _buildPaymentSummary(double afterEntryRemaining) {
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
              'Payment Amount: RM ${widget.payment.amountRm.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Already Allocated: RM ${_allocatedAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            Text('Remaining: RM ${_remainingAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'After New Allocation: '
              'RM ${afterEntryRemaining.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final controller = _controllers[transaction.id]!;

    final totalAllocated = _transactionAllocatedAmounts[transaction.id] ?? 0;

    final amountOut = transaction.amountOutRm ?? 0;

    final remainingAmount = amountOut - totalAllocated;

    final isFullyAllocated = remainingAmount <= 0.01;

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
              'Amount Out: '
              'RM ${(transaction.amountOutRm ?? 0).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),

            Text('Allocated: RM ${totalAllocated.toStringAsFixed(2)}'),

            Text(
              'Remaining: RM ${remainingAmount < 0 ? 0 : remainingAmount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (isFullyAllocated)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Fully Allocated: '
                  'RM ${totalAllocated.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            TextField(
              controller: controller,
              enabled: !isFullyAllocated,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Allocation Amount (RM)',
                prefixText: 'RM ',
                border: OutlineInputBorder(),
                suffixIcon: isFullyAllocated ? const Icon(Icons.lock) : null,
              ),

              onChanged: (_) {
                setState(() {});
              },
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
