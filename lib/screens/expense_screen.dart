import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/expense_summary.dart';
import 'package:kharcha_ai/services/expense_service.dart';
import 'package:kharcha_ai/widgets/add_expense_sheet.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';

class ExpenseScreen extends StatefulWidget {
  final ExpenseService expenseService;
  final String? preferredCurrency;

  const ExpenseScreen({
    super.key,
    required this.expenseService,
    this.preferredCurrency,
  });

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<ExpenseModel> _expenses = [];
  ExpenseSummaryModel? _summary;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
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
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        widget.expenseService.getSummary(),
        widget.expenseService.getExpenses(
          category: _selectedCategory == 'All' ? null : _selectedCategory,
          limit: 100,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = futures[0] as ExpenseSummaryModel;
        final list = futures[1] as List<ExpenseModel>;
        if (_searchQuery.trim().isEmpty) {
          _expenses = list;
        } else {
          final q = _searchQuery.toLowerCase();
          _expenses = list.where((e) {
            return e.title.toLowerCase().contains(q) ||
                (e.description?.toLowerCase().contains(q) ?? false) ||
                e.paymentMethod.toLowerCase().contains(q);
          }).toList();
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showAddExpenseModal([ExpenseModel? expenseToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(
        expenseService: widget.expenseService,
        expenseToEdit: expenseToEdit,
        onSuccess: () {
          _loadData();
        },
      ),
    );
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.expenseService.deleteExpense(expense.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalStr = _summary != null
        ? CurrencyFormatter.format(_summary!.totalAmount, currency: widget.preferredCurrency)
        : '0.00';
    final count = _summary?.totalCount ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Expenses Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseModal(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Kharcha', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              // Summary Banner Card
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
                          'Total Monthly Expenses',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count transactions',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Input
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _loadData();
                },
                decoration: InputDecoration(
                  hintText: 'Search expenses by name or description...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadData();
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),

              // Category Filter Pills
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                        _loadData();
                      },
                      selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // List of Expenses
              if (_isLoading) ...[
                const SkeletonList(count: 6),
              ] else if (_expenses.isEmpty) ...[
                EmptyStateView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No Expenses Found',
                  description: _searchQuery.isNotEmpty || _selectedCategory != 'All'
                      ? 'No expenses matching your filter. Try adjusting your search query.'
                      : 'You have not recorded any expenses yet. Tap "Add Kharcha" to begin!',
                  actionText: 'Add Kharcha',
                  actionIcon: Icons.add,
                  onAction: () => _showAddExpenseModal(),
                ),
              ] else ...[
                ..._expenses.map((expense) {
                  return FintechCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CategoryIconAvatar(category: expense.category),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    expense.formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkBackground
                                          : const Color(0xFFF2F4F7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      expense.paymentMethod,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (expense.description != null &&
                                  expense.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  expense.description!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '-${CurrencyFormatter.format(expense.amount, currency: widget.preferredCurrency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.error,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showAddExpenseModal(expense);
                                } else if (val == 'delete') {
                                  _deleteExpense(expense);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              ],
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
