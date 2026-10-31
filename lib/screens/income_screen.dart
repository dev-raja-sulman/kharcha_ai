import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/income_model.dart';
import 'package:kharcha_ai/screens/add_income_screen.dart';
import 'package:kharcha_ai/services/income_service.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';

class IncomeScreen extends StatefulWidget {
  final IncomeService incomeService;
  final String? preferredCurrency;

  const IncomeScreen({
    super.key,
    required this.incomeService,
    this.preferredCurrency,
  });

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  IncomeSummaryModel? _summary;
  List<IncomeModel> _incomes = [];
  List<IncomeSourceModel> _sources = [];
  int? _selectedSourceId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final results = await Future.wait([
        widget.incomeService.getIncomeSummary(month: now.month, year: now.year),
        widget.incomeService.getIncomes(
          sourceId: _selectedSourceId,
          search: _searchQuery.isEmpty ? null : _searchQuery,
          pageSize: 50,
        ),
        widget.incomeService.getIncomeSources(),
      ]);

      if (!mounted) return;

      setState(() {
        _summary = results[0] as IncomeSummaryModel;
        final listModel = results[1] as IncomeListModel;
        _incomes = listModel.items;
        _sources = results[2] as List<IncomeSourceModel>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete(IncomeModel income) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Income Entry'),
        content: Text('Are you sure you want to delete "${income.title}"?'),
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
        await widget.incomeService.deleteIncome(income.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Income record deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllData();
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

  void _navigateToAdd({IncomeModel? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddIncomeScreen(
          incomeService: widget.incomeService,
          existingIncome: existing,
        ),
      ),
    ).then((_) => _loadAllData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalIncomeStr = _summary != null
        ? CurrencyFormatter.format(_summary!.totalIncome, currency: widget.preferredCurrency)
        : '0.00';
    final count = _summary?.totalCount ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Income Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAdd(),
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              // Income Hero Card
              FintechCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Monthly Income',
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
                            '$count entries',
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
                      totalIncomeStr,
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
                  setState(() => _searchQuery = val.trim());
                  _loadAllData();
                },
                decoration: InputDecoration(
                  hintText: 'Search income entries...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadAllData();
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),

              // Source Filter Chips
              if (_sources.isNotEmpty) ...[
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sources.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = _selectedSourceId == null;
                        return FilterChip(
                          label: const Text('All Sources'),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedSourceId = null);
                            _loadAllData();
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
                      }
                      final source = _sources[index - 1];
                      final isSelected = _selectedSourceId == source.id;
                      return FilterChip(
                        label: Text(source.name),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedSourceId = source.id);
                          _loadAllData();
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
              ],

              // Income Ledger List
              if (_isLoading) ...[
                const SkeletonList(count: 5),
              ] else if (_incomes.isEmpty) ...[
                EmptyStateView(
                  icon: Icons.payments_outlined,
                  title: 'No Income Recorded',
                  description: _searchQuery.isNotEmpty || _selectedSourceId != null
                      ? 'No income records match your search filter.'
                      : 'Record your salary, freelance earnings, or business income.',
                  actionText: 'Add Income',
                  actionIcon: Icons.add,
                  onAction: () => _navigateToAdd(),
                ),
              ] else ...[
                ..._incomes.map((income) {
                  final dateStr = DateFormat('MMM dd, yyyy').format(income.incomeDate);
                  return FintechCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CategoryIconAvatar(category: income.sourceName ?? 'salary'),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                income.title,
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
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.successBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      income.sourceName ?? 'Income',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    income.paymentMethod,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+${CurrencyFormatter.format(income.amount, currency: widget.preferredCurrency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.success,
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
                                  _navigateToAdd(existing: income);
                                } else if (val == 'delete') {
                                  _handleDelete(income);
                                }
                              },
                              itemBuilder: (_) => [
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
