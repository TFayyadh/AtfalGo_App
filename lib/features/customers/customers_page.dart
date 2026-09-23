import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/customer_service.dart';

import 'customer_details_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final CustomerService _customerService = CustomerService();

  List<Customer> _customers = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _loading = true;
    });

    try {
      final customers = await _customerService.getCustomers();

      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading customers: $e')));
      }
    }
  }

  List<Customer> get _filteredCustomers {
    if (_search.trim().isEmpty) {
      return _customers;
    }

    final search = _search.toLowerCase();

    return _customers.where((customer) {
      return customer.customerCode.toLowerCase().contains(search) ||
          (customer.name ?? '').toLowerCase().contains(search) ||
          (customer.phone ?? '').toLowerCase().contains(search) ||
          (customer.alipayId ?? '').toLowerCase().contains(search);
    }).toList();
  }

  Future<void> _showCustomerDialog({Customer? customer}) async {
    final isEditing = customer != null;

    final codeController = TextEditingController(
      text: customer?.customerCode ?? '',
    );

    final nameController = TextEditingController(text: customer?.name ?? '');

    final phoneController = TextEditingController(text: customer?.phone ?? '');

    final alipayController = TextEditingController(
      text: customer?.alipayId ?? '',
    );

    final notesController = TextEditingController(text: customer?.notes ?? '');

    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Code',
                      hintText: 'e.g. C001',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Customer Code is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: alipayController,
                    decoration: const InputDecoration(labelText: 'Alipay ID'),
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
                    await _customerService.updateCustomer(
                      id: customer.id,
                      customerCode: codeController.text.trim(),
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      alipayId: alipayController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                  } else {
                    await _customerService.createCustomer(
                      customerCode: codeController.text.trim(),
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      alipayId: alipayController.text.trim(),
                      notes: notesController.text.trim(),
                    );
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error saving customer: $e')),
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

    // Only reload AFTER the dialog has completely closed.
    if (saved == true && mounted) {
      await _loadCustomers();
    }
  }

  Future<void> _showCustomerOptions(Customer customer) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Customer'),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomerDialog(customer: customer);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_off),
                title: const Text('Deactivate Customer'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deactivateCustomer(customer);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deactivateCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate Customer'),
          content: Text(
            'Are you sure you want to deactivate '
            '${customer.customerCode}?',
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
      await _customerService.deactivateCustomer(customer.id);
      await _loadCustomers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deactivating customer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = _filteredCustomers;

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search customers',
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
                : customers.isEmpty
                ? const Center(child: Text('No customers found'))
                : RefreshIndicator(
                    onRefresh: _loadCustomers,
                    child: ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        final customer = customers[index];

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(customer.customerCode),
                          ),
                          title: Text(
                            customer.name?.isNotEmpty == true
                                ? customer.name!
                                : customer.customerCode,
                          ),
                          subtitle: Text(
                            '${customer.customerCode}'
                            '${customer.phone != null && customer.phone!.isNotEmpty ? ' • ${customer.phone}' : ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              _showCustomerOptions(customer);
                            },
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CustomerDetailsPage(customer: customer),
                              ),
                            );

                            await _loadCustomers();
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
          _showCustomerDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
