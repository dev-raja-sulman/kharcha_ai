import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/services/bill_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';

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
          content: Text('Bill obligation scheduled successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to schedule bill: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule Bill Reminder'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount Hero Input Card
                    FintechCard(
                      gradient: AppColors.navyHeroGradient,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bill Due Amount',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                'PKR ',
                                style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  cursorColor: Colors.white,
                                  decoration: const InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: TextStyle(color: Colors.white38, fontSize: 32),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter amount';
                                    if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    FintechCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextField(
                            controller: _titleController,
                            label: 'Bill Title *',
                            hint: 'e.g. LESCO Electricity, StormFiber Fiber, Netflix',
                            prefixIcon: Icons.receipt_long_rounded,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a bill title' : null,
                          ),
                          const SizedBox(height: 18),

                          // Category Picker
                          const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                          ),
                          const SizedBox(height: 18),

                          // Frequency selector
                          const Text('Recurring Frequency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _frequencies.map((f) {
                              final isSelected = _selectedFrequency == f['value'];
                              return ChoiceChip(
                                label: Text(f['label']!),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedFrequency = f['value']!),
                                selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Due Date
                          const Text('Due Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectDueDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('MMMM dd, yyyy').format(_dueDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Reminder Toggle
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Receive proactive alerts before the due date', style: TextStyle(fontSize: 12)),
                            value: _reminderEnabled,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setState(() => _reminderEnabled = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    CustomButton(
                      text: 'Schedule Bill',
                      icon: Icons.check_circle_rounded,
                      isLoading: _isLoading,
                      onPressed: _submitBill,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
