import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/budget_model.dart';
import 'package:kharcha_ai/services/budget_service.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';
import 'package:kharcha_ai/widgets/stat_badge.dart';

class BudgetScreen extends StatefulWidget {
  final BudgetService budgetService;
  final String? preferredCurrency;

  const BudgetScreen({
    super.key,
    required this.budgetService,
    this.preferredCurrency,
  });

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
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Set Monthly Budget',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (modalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(modalError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  CustomTextField(
                    controller: nameCtrl,
                    label: 'Budget Name (Optional)',
                    hint: 'e.g. Dining Out Budget',
                    prefixIcon: Icons.label_outline_rounded,
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: amtCtrl,
                    label: 'Monthly Limit (PKR) *',
                    hint: 'e.g. 25000',
                    prefixIcon: Icons.attach_money_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),

                  const Text('Select Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'Save Budget Limit',
                    isLoading: isSaving,
                    onPressed: () async {
                      final amt = double.tryParse(amtCtrl.text.trim());
                      if (amt == null || amt <= 0) {
                        setModalState(() => modalError = 'Please enter a valid amount');
                        return;
                      }

                      setModalState(() {
                        isSaving = true;
                        modalError = null;
                      });

                      final catToSave = selectedCategory.contains('(No Category)') ? null : selectedCategory;

                      try {
                        await widget.budgetService.createBudget(
                          name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : (catToSave ?? 'Monthly Budget'),
                          category: catToSave,
                          amount: amt,
                          month: _selectedMonth,
                          year: _selectedYear,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadBudgets();
                      } catch (e) {
                        setModalState(() {
                          isSaving = false;
                          modalError = e.toString();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDeleteBudget(BudgetModel budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete budget limit for ${budget.category ?? "Monthly Spending"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.budgetService.deleteBudget(budget.id);
        _loadBudgets();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalBudget = _budgets.fold<double>(0, (sum, b) => sum + b.amount);
    final totalSpent = _budgets.fold<double>(0, (sum, b) => sum + b.spent);
    final overallRatio = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Smart Budgets'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadBudgets),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBudgetDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Budget', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBudgets,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              // Overall Monthly Budget Hero Card
              FintechCard(
                gradient: AppColors.navyHeroGradient,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Overall Monthly Budget',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_budgets.length} limits active',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          CurrencyFormatter.format(totalSpent, currency: widget.preferredCurrency),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          ' / ${CurrencyFormatter.format(totalBudget, currency: widget.preferredCurrency)}',
                          style: const TextStyle(color: Colors.white60, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: overallRatio,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overallRatio >= 1.0
                              ? AppColors.error
                              : overallRatio >= 0.85
                                  ? AppColors.warning
                                  : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                ),
                const SizedBox(height: 14),
              ],

              // Budgets List
              if (_isLoading) ...[
                const SkeletonList(count: 4),
              ] else if (_budgets.isEmpty) ...[
                EmptyStateView(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'No Budgets Set',
                  description: 'Create category spending caps to prevent overspending and hit your savings targets.',
                  actionText: 'Create Budget',
                  actionIcon: Icons.add,
                  onAction: _showCreateBudgetDialog,
                ),
              ] else ...[
                ..._budgets.map((b) {
                  final ratio = b.amount > 0 ? (b.spent / b.amount).clamp(0.0, 1.0) : 0.0;
                  final isOver = b.spent > b.amount;
                  final isWarning = ratio >= 0.85 && !isOver;

                  return FintechCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CategoryIconAvatar(category: b.category ?? 'Other', size: 36, iconSize: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(ratio * 100).toStringAsFixed(0)}% of limit used',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOver)
                              const StatBadge(label: 'OVER LIMIT', type: StatBadgeType.error, showDot: true)
                            else if (isWarning)
                              const StatBadge(label: '85%+ USED', type: StatBadgeType.warning, showDot: true)
                            else
                              const StatBadge(label: 'ON TRACK', type: StatBadgeType.success, showDot: true),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                              onPressed: () => _handleDeleteBudget(b),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFF2F4F7),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isOver
                                  ? AppColors.error
                                  : isWarning
                                      ? AppColors.warning
                                      : AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spent: ${CurrencyFormatter.format(b.spent, currency: widget.preferredCurrency)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isOver ? AppColors.error : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              ),
                            ),
                            Text(
                              'Cap: ${CurrencyFormatter.format(b.amount, currency: widget.preferredCurrency)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
