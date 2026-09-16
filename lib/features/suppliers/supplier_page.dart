import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../services/supplier_service.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final SupplierService _supplierService = SupplierService();

  List<Supplier> _suppliers = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _loading = true;
    });

    try {
      final suppliers = await _supplierService.getSuppliers();

      if (!mounted) return;

      setState(() {
        _suppliers = suppliers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading suppliers: $e')));
    }
  }

  List<Supplier> get _filteredSuppliers {
    if (_search.trim().isEmpty) {
      return _suppliers;
    }

    final search = _search.toLowerCase();

    return _suppliers.where((supplier) {
      return supplier.supplierCode.toLowerCase().contains(search) ||
          supplier.name.toLowerCase().contains(search) ||
          (supplier.phone ?? '').toLowerCase().contains(search) ||
          (supplier.bankAccount ?? '').toLowerCase().contains(search);
    }).toList();
  }

  Future<void> _showSupplierDialog({Supplier? supplier}) async {
    final isEditing = supplier != null;

    final codeController = TextEditingController(
      text: supplier?.supplierCode ?? '',
    );

    final nameController = TextEditingController(text: supplier?.name ?? '');

    final phoneController = TextEditingController(text: supplier?.phone ?? '');

    final bankNameController = TextEditingController(
      text: supplier?.bankName ?? '',
    );

    final bankAccountController = TextEditingController(
      text: supplier?.bankAccount ?? '',
    );

    final accountNameController = TextEditingController(
      text: supplier?.accountName ?? '',
    );

    final notesController = TextEditingController(text: supplier?.notes ?? '');

    final formKey = GlobalKey<FormState>();

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Supplier' : 'Add Supplier'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Code',
                        hintText: 'e.g. S001',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Supplier Code is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Supplier Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: bankNameController,
                      decoration: const InputDecoration(labelText: 'Bank Name'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: bankAccountController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Account',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: accountNameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Name',
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
                    if (isEditing) {
                      await _supplierService.updateSupplier(
                        id: supplier.id,
                        supplierCode: codeController.text.trim(),
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        bankName: bankNameController.text.trim(),
                        bankAccount: bankAccountController.text.trim(),
                        accountName: accountNameController.text.trim(),
                        notes: notesController.text.trim(),
                      );
                    } else {
                      await _supplierService.createSupplier(
                        supplierCode: codeController.text.trim(),
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        bankName: bankNameController.text.trim(),
                        bankAccount: bankAccountController.text.trim(),
                        accountName: accountNameController.text.trim(),
                        notes: notesController.text.trim(),
                      );
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Error saving supplier: $e')),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'Update' : 'Save'),
              ),
            ],
          );
        },
      );

      if (saved == true && mounted) {
        await _loadSuppliers();
      }
    } finally {
      codeController.dispose();
      nameController.dispose();
      phoneController.dispose();
      bankNameController.dispose();
      bankAccountController.dispose();
      accountNameController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _showSupplierOptions(Supplier supplier) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Supplier'),
                onTap: () {
                  Navigator.pop(context);
                  _showSupplierDialog(supplier: supplier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_off),
                title: const Text('Deactivate Supplier'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deactivateSupplier(supplier);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deactivateSupplier(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate Supplier'),
          content: Text(
            'Are you sure you want to deactivate '
            '${supplier.supplierCode}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _supplierService.deactivateSupplier(supplier.id);
      await _loadSuppliers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deactivating supplier: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = _filteredSuppliers;

    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search suppliers',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _search = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _search = value;
                });
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : suppliers.isEmpty
                ? const Center(child: Text('No suppliers found'))
                : RefreshIndicator(
                    onRefresh: _loadSuppliers,
                    child: ListView.builder(
                      itemCount: suppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = suppliers[index];

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(supplier.supplierCode),
                          ),
                          title: Text(supplier.name),
                          subtitle: Text(
                            '${supplier.supplierCode}'
                            '${supplier.phone != null && supplier.phone!.isNotEmpty ? ' • ${supplier.phone}' : ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              _showSupplierOptions(supplier);
                            },
                          ),
                          onTap: () {
                            _showSupplierDialog(supplier: supplier);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showSupplierDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
