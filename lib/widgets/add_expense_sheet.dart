import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/services/expense_service.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';

class AddExpenseSheet extends StatefulWidget {
  final ExpenseService expenseService;
  final ExpenseModel? expenseToEdit;
  final VoidCallback onSuccess;

  const AddExpenseSheet({
    super.key,
    required this.expenseService,
    this.expenseToEdit,
    required this.onSuccess,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'Cash';
  String _selectedCurrency = 'PKR';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Healthcare',
    'Education',
    'Entertainment',
    'Rent',
    'Travel',
    'Other'
  ];

  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'EasyPaisa',
    'JazzCash',
    'Bank Transfer',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final exp = widget.expenseToEdit!;
      _titleController.text = exp.title;
      _amountController.text = exp.amount.toStringAsFixed(2);
      _descController.text = exp.description ?? '';
      _selectedCategory = exp.category;
      _selectedPaymentMethod = exp.paymentMethod;
      _selectedCurrency = exp.currency;
      _selectedDate = exp.expenseDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final amountVal = double.tryParse(_amountController.text.trim());
    if (amountVal == null || amountVal <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount greater than zero.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.expenseToEdit != null) {
        await widget.expenseService.updateExpense(
          widget.expenseToEdit!.id,
          title: _titleController.text.trim(),
          amount: amountVal,
          category: _selectedCategory,
          currency: _selectedCurrency,
          expenseDate: _selectedDate,
          paymentMethod: _selectedPaymentMethod,
          description: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : null,
        );
      } else {
        await widget.expenseService.createExpense(
          title: _titleController.text.trim(),
          amount: amountVal,
          category: _selectedCategory,
          currency: _selectedCurrency,
          expenseDate: _selectedDate,
          paymentMethod: _selectedPaymentMethod,
          description: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : null,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Failed to save expense. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.expenseToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF243049) : const Color(0xFFE4E7EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Kharcha' : 'Record New Kharcha',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Amount Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          '-',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCurrency,
                              isDense: true,
                              dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                              items: CurrencyFormatter.supportedCurrencies.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCurrency = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: !isEdit,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter amount';
                              if (double.tryParse(v.trim()) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Title Field
              CustomTextField(
                controller: _titleController,
                label: 'Title *',
                hint: 'e.g. Lunch with colleagues, Metro fare',
                prefixIcon: Icons.title_rounded,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter title';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Category Grid
              const Text(
                'Category',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryIconAvatar(category: cat, size: 20, iconSize: 11, borderRadius: 6),
                          const SizedBox(width: 6),
                          Text(cat),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Date Picker
              const Text(
                'Expense Date',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
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
              const SizedBox(height: 14),

              // Payment Method Chips
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paymentMethods.map((m) {
                  final isSelected = _selectedPaymentMethod == m;
                  return ChoiceChip(
                    label: Text(m),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedPaymentMethod = m),
                    selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Description
              CustomTextField(
                controller: _descController,
                label: 'Notes / Memo (Optional)',
                hint: 'Any extra details...',
                prefixIcon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              CustomButton(
                text: isEdit ? 'Update Kharcha' : 'Save Kharcha',
                icon: Icons.check_circle_rounded,
                isLoading: _isLoading,
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
