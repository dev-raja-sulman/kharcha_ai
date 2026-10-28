import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/budget_model.dart';
import 'package:kharcha_ai/services/budget_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';

class BudgetScreen extends StatefulWidget {
  final BudgetService budgetService;

  const BudgetScreen({super.key, required this.budgetService});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<BudgetModel> _budgets = [];

  final int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  final List<String> _categories = [
    'Overall Monthly (No Category)',
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

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.budgetService.getBudgets(
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (!mounted) return;
      setState(() {
        _budgets = items;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateBudgetDialog() {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String selectedCategory = _categories[0];
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Smart Budget',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (modalError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(modalError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              CustomTextField(
                controller: nameCtrl,
                label: 'Budget Name',
                hint: 'e.g. Monthly Grocery Cap, Overall October',
                prefixIcon: Icons.bookmark_border,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: amtCtrl,
                label: 'Budget Limit (PKR)',
                hint: '25000',
                prefixIcon: Icons.payments_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),
              const Text('Target Category', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedCategory = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Save Budget',
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final amt = double.tryParse(amtCtrl.text.trim());
                  if (name.isEmpty) {
                    setModalState(() => modalError = 'Please enter a budget name.');
                    return;
                  }
                  if (amt == null || amt <= 0) {
                    setModalState(() => modalError = 'Please enter a valid amount greater than 0.');
                    return;
                  }

                  final catValue = selectedCategory == _categories[0] ? null : selectedCategory;

                  try {
                    await widget.budgetService.createBudget(
                      name: name,
                      amount: amt,
                      category: catValue,
                      month: _selectedMonth,
                      year: _selectedYear,
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _loadBudgets();
                  } on ApiException catch (e) {
                    setModalState(() => modalError = e.message);
                  } catch (e) {
                    setModalState(() => modalError = e.toString());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAlertColor(String level) {
    switch (level) {
      case 'exceeded_100':
        return AppColors.error;
      case 'warning_80':
        return Colors.orange;
      case 'warning_50':
        return Colors.amber.shade700;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Smart Monthly Budgets'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBudgets,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBudgetDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Budget'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBudgets,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                    ),
                  if (_budgets.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.pie_chart_outline, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              'No Budgets Set For This Month',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create overall or category spending limits to track progress and receive real-time threshold alerts.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._budgets.map((b) {
                      final alertCol = _getAlertColor(b.alertLevel);
                      final progress = (b.percentageUsed / 100.0).clamp(0.0, 1.0);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.cardBorder),
                        ),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          b.category != null ? 'Category: ${b.category}' : 'Overall Monthly Budget',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: alertCol.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${b.percentageUsed.toStringAsFixed(1)}%',
                                      style: TextStyle(color: alertCol, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSecondary),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Budget'),
                                          content: Text('Delete "${b.name}"?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await widget.budgetService.deleteBudget(b.id);
                                        _loadBudgets();
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: AppColors.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(alertCol),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Spent: ${b.formattedSpent}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(
                                    b.isOverBudget
                                        ? 'Over by PKR ${(-b.remaining).toStringAsFixed(2)}'
                                        : 'Remaining: ${b.formattedRemaining}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: b.isOverBudget ? AppColors.error : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (b.alertLevel != 'normal') ...[
                                const SizedBox(height: 10),
                                Text(
                                  b.alertMessage,
                                  style: TextStyle(color: alertCol, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
