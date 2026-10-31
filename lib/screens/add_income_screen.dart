import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/income_model.dart';
import 'package:kharcha_ai/services/income_service.dart';

class AddIncomeScreen extends StatefulWidget {
  final IncomeService incomeService;
  final IncomeModel? existingIncome;

  const AddIncomeScreen({
    super.key,
    required this.incomeService,
    this.existingIncome,
  });

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late DateTime _selectedDate;
  int? _selectedSourceId;
  String _selectedPaymentMethod = 'Bank Transfer';
  bool _isLoading = false;
  bool _isLoadingSources = true;
  List<IncomeSourceModel> _sources = [];

  final List<String> _paymentMethods = [
    'Bank Transfer',
    'Cash',
    'Card',
    'EasyPaisa',
    'JazzCash',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final inc = widget.existingIncome;
    _titleController = TextEditingController(text: inc?.title ?? '');
    _amountController = TextEditingController(
      text: inc != null ? inc.amount.toStringAsFixed(2) : '',
    );
    _descriptionController = TextEditingController(text: inc?.description ?? '');
    _selectedDate = inc?.incomeDate ?? DateTime.now();
    _selectedSourceId = inc?.sourceId;
    _selectedPaymentMethod = inc?.paymentMethod ?? 'Bank Transfer';

    _loadSources();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    try {
      final list = await widget.incomeService.getIncomeSources();
      if (!mounted) return;
      setState(() {
        _sources = list;
        _isLoadingSources = false;
        if (_selectedSourceId == null && _sources.isNotEmpty) {
          _selectedSourceId = _sources.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSources = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final amountVal = double.tryParse(_amountController.text.trim());
    if (amountVal == null || amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than zero.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.existingIncome != null) {
        await widget.incomeService.updateIncome(
          widget.existingIncome!.id,
          title: _titleController.text.trim(),
          amount: amountVal,
          incomeDate: _selectedDate,
          paymentMethod: _selectedPaymentMethod,
          description: _descriptionController.text.trim(),
          sourceId: _selectedSourceId,
        );
      } else {
        await widget.incomeService.createIncome(
          title: _titleController.text.trim(),
          amount: amountVal,
          incomeDate: _selectedDate,
          paymentMethod: _selectedPaymentMethod,
          description: _descriptionController.text.trim(),
          sourceId: _selectedSourceId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingIncome != null
                ? 'Income updated successfully'
                : 'Income recorded successfully',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingIncome != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Income' : 'Add Income'),
      ),
      body: _isLoadingSources
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title Field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Income Title *',
                        hintText: 'e.g. October Salary, Freelance Web App',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (PKR) *',
                        hintText: 'e.g. 50000.00',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Amount is required';
                        }
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter an amount greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Source Dropdown
                    if (_sources.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: _selectedSourceId,
                        decoration: const InputDecoration(
                          labelText: 'Income Source',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _sources.map((s) {
                          return DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedSourceId = val);
                        },
                      ),
                    if (_sources.isNotEmpty) const SizedBox(height: 16),

                    // Payment Method Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: _paymentMethods.map((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(m),
                        );
                      }).toList(),
                      onChanged: (val) {

                        if (val != null) setState(() => _selectedPaymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date Picker Tile
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Income Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Notes (Optional)',
                        hintText: 'e.g. Bonus included or client invoice #104',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
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
                          : Text(
                              isEditing ? 'Save Changes' : 'Record Income',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
