import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/income_model.dart';
import 'package:kharcha_ai/services/income_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';

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
          sourceId: _selectedSourceId,
          incomeDate: _selectedDate,
          paymentMethod: _selectedPaymentMethod,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        );
      } else {
        await widget.incomeService.createIncome(
          title: _titleController.text.trim(),
          amount: amountVal,
          sourceId: _selectedSourceId,
          incomeDate: _selectedDate,
          paymentMethod: _selectedPaymentMethod,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingIncome != null
                ? 'Income updated successfully!'
                : 'Income logged successfully!',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save income: $e'),
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
    final isEdit = widget.existingIncome != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Income' : 'Add New Income'),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Income Amount',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                '+',
                                style: TextStyle(color: Colors.white70, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
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
                    const SizedBox(height: 18),

                    FintechCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextField(
                            controller: _titleController,
                            label: 'Title / Description *',
                            hint: 'e.g. October Salary, Freelance project',
                            prefixIcon: Icons.title_rounded,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter a title';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Source Selection
                          const Text(
                            'Income Source',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (_isLoadingSources) ...[
                            const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ] else if (_sources.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _sources.map((s) {
                                final isSelected = _selectedSourceId == s.id;
                                return ChoiceChip(
                                  label: Text(s.name),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() => _selectedSourceId = s.id),
                                  selectedColor: AppColors.successBg,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppColors.success : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 18),

                          // Date Picker Row
                          const Text(
                            'Received Date',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('MMMM dd, yyyy').format(_selectedDate),
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

                          // Payment Method Chips
                          const Text(
                            'Payment Method',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _paymentMethods.map((m) {
                              final isSelected = _selectedPaymentMethod == m;
                              return ChoiceChip(
                                label: Text(m),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedPaymentMethod = m),
                                selectedColor: AppColors.primarySurface,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Notes
                          CustomTextField(
                            controller: _descriptionController,
                            label: 'Additional Notes (Optional)',
                            hint: 'Any extra details or memo...',
                            prefixIcon: Icons.notes_rounded,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    CustomButton(
                      text: isEdit ? 'Update Income' : 'Record Income',
                      icon: Icons.check_circle_rounded,
                      backgroundColor: AppColors.success,
                      isLoading: _isLoading,
                      onPressed: _handleSubmit,
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
