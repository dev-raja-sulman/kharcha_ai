import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/services/bill_service.dart';

class AddBillScreen extends StatefulWidget {
  final BillService billService;

  const AddBillScreen({
    super.key,
    required this.billService,
  });

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedCategory = 'Electricity';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  String _selectedFrequency = 'monthly';
  bool _reminderEnabled = true;
  bool _isLoading = false;

  final List<String> _categories = [
    'Electricity',
    'Gas',
    'Internet',
    'Mobile',
    'Rent',
    'Water',
    'Education',
    'Subscriptions',
    'Other',
  ];

  final List<Map<String, String>> _frequencies = [
    {'value': 'one_time', 'label': 'One-time'},
    {'value': 'monthly', 'label': 'Monthly'},
    {'value': 'quarterly', 'label': 'Quarterly'},
    {'value': 'yearly', 'label': 'Yearly'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submitBill() async {
    if (!_formKey.currentState!.validate()) return;

    final amountVal = double.tryParse(_amountController.text.trim());
    if (amountVal == null || amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid bill amount greater than zero.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.billService.createBill(
        title: _titleController.text.trim(),
        category: _selectedCategory,
        amount: amountVal,
        dueDate: _dueDate,
        frequency: _selectedFrequency,
        reminderEnabled: _reminderEnabled,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM dd, yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add New Bill'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title field
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Bill Title *',
                          hintText: 'e.g. LESCO Electricity, Fiber Net',
                          prefixIcon: Icon(Icons.receipt_long, color: AppColors.primary),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title for the bill';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category, color: AppColors.primary),
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount (PKR) *',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.currency_exchange, color: AppColors.primary),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an amount';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Due date & Schedule
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Due Date & Schedule',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectDueDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Due Date',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      dateFormat.format(_dueDate),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Recurrence Frequency',
                          prefixIcon: Icon(Icons.repeat, color: AppColors.primary),
                          border: OutlineInputBorder(),
                        ),
                        items: _frequencies.map((freq) {
                          return DropdownMenuItem(
                            value: freq['value'],
                            child: Text(freq['label']!),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedFrequency = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Payment Reminders',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        subtitle: const Text(
                          'Show in upcoming obligations and alert cards',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        value: _reminderEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _reminderEnabled = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitBill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Bill',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
