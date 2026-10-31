import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/recurring_expense_model.dart';
import 'package:kharcha_ai/services/recurring_service.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';
import 'package:kharcha_ai/widgets/stat_badge.dart';

class RecurringExpensesScreen extends StatefulWidget {
  final RecurringService recurringService;

  const RecurringExpensesScreen({
    super.key,
    required this.recurringService,
  });

  @override
  State<RecurringExpensesScreen> createState() => _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> {
  bool _isLoading = false;
  String _selectedFilter = 'all';
  List<RecurringExpenseModel> _rules = [];

  final List<String> _categories = [
    'Bills',
    'Food',
    'Transport',
    'Shopping',
    'Healthcare',
    'Education',
    'Entertainment',
    'Rent',
    'Travel',
    'Other'
  ];

  final List<String> _frequencies = ['daily', 'weekly', 'monthly', 'yearly'];
  final List<String> _paymentMethods = ['Cash', 'Card', 'Bank Transfer', 'EasyPaisa', 'JazzCash'];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.recurringService.getRecurringRules(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      if (!mounted) return;
      setState(() => _rules = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recurring rules: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processDueExpenses() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.recurringService.processDueExpenses();
      if (!mounted) return;
      final generated = result['generated_count'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(generated > 0
              ? 'Successfully generated $generated recurring expenses!'
              : 'All recurring rules are up to date.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadRules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePauseResume(RecurringExpenseModel rule) async {
    try {
      if (rule.isActive) {
        await widget.recurringService.pauseRule(rule.id);
      } else if (rule.isPaused) {
        await widget.recurringService.resumeRule(rule.id);
      }
      _loadRules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _cancelRule(RecurringExpenseModel rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Recurring Rule'),
        content: Text('Are you sure you want to cancel "${rule.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Cancel Rule'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.recurringService.cancelRule(rule.id);
        _loadRules();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel rule: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _showHistoryDialog(RecurringExpenseModel rule) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<ExpenseModel>>(
        future: widget.recurringService.getRuleHistory(rule.id),
        builder: (context, snapshot) {
          return AlertDialog(
            title: Text('${rule.title} History'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                      ? Center(child: Text('Error: ${snapshot.error}'))
                      : (snapshot.data == null || snapshot.data!.isEmpty)
                          ? const Center(child: Text('No expenses generated yet.'))
                          : ListView.separated(
                              itemCount: snapshot.data!.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final exp = snapshot.data![i];
                                return ListTile(
                                  dense: true,
                                  title: Text(exp.formattedDate),
                                  subtitle: Text(exp.paymentMethod),
                                  trailing: Text(
                                    exp.formattedAmount,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                );
                              },
                            ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  void _showAddOrEditSheet([RecurringExpenseModel? editRule]) {
    final titleController = TextEditingController(text: editRule?.title ?? '');
    final amountController = TextEditingController(text: editRule?.amount.toString() ?? '');
    final descController = TextEditingController(text: editRule?.description ?? '');
    String selectedCategory = editRule?.category ?? 'Bills';
    String selectedFreq = editRule?.frequency ?? 'monthly';
    String selectedPayment = editRule?.paymentMethod ?? 'Cash';
    DateTime startDate = editRule?.startDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (modalCtx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
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
                    Text(
                      editRule != null ? 'Edit Recurring Rule' : 'New Recurring Rule',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: titleController,
                      label: 'Rule Title *',
                      hint: 'e.g. Netflix, Gym Membership, Internet',
                      prefixIcon: Icons.title,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      controller: amountController,
                      label: 'Amount (PKR) *',
                      hint: '0.00',
                      prefixIcon: Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 14),
                    const Text('Frequency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _frequencies.map((f) {
                        final isSel = selectedFreq == f;
                        return ChoiceChip(
                          label: Text(f.toUpperCase()),
                          selected: isSel,
                          onSelected: (_) => setSheetState(() => selectedFreq = f),
                          selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedPayment,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedPayment = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      controller: descController,
                      label: 'Description (Optional)',
                      hint: 'Subscription notes...',
                      prefixIcon: Icons.notes,
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: editRule != null ? 'Update Rule' : 'Save Recurring Rule',
                      onPressed: () async {
                        final amt = double.tryParse(amountController.text.trim());
                        final title = titleController.text.trim();
                        if (title.isEmpty || amt == null || amt <= 0) return;

                        try {
                          if (editRule != null) {
                            await widget.recurringService.updateRecurringRule(
                              id: editRule.id,
                              title: title,
                              amount: amt,
                              category: selectedCategory,
                              frequency: selectedFreq,
                              paymentMethod: selectedPayment,
                              description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                            );
                          } else {
                            await widget.recurringService.createRecurringRule(
                              title: title,
                              amount: amt,
                              category: selectedCategory,
                              frequency: selectedFreq,
                              paymentMethod: selectedPayment,
                              startDate: startDate,
                              description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                            );
                          }
                          if (!modalCtx.mounted) return;
                          Navigator.pop(modalCtx);
                          _loadRules();
                        } catch (e) {
                          if (!modalCtx.mounted) return;
                          ScaffoldMessenger.of(modalCtx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount = _rules.where((r) => r.isActive).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Run due auto-expenses',
            onPressed: _processDueExpenses,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRules,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditSheet(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Rule', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRules,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              // Recurring Hero Card
              FintechCard(
                gradient: AppColors.navyHeroGradient,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.event_repeat_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Auto-Subscriptions',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$activeCount Active Rules',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _processDueExpenses,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: const Text('Sync Due', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Filter Chips
              Row(
                children: ['all', 'active', 'paused', 'cancelled'].map((f) {
                  final isSel = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(f.toUpperCase()),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() => _selectedFilter = f);
                        _loadRules();
                      },
                      selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                      labelStyle: TextStyle(
                        color: isSel ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              if (_isLoading) ...[
                const SkeletonList(count: 3),
              ] else if (_rules.isEmpty) ...[
                EmptyStateView(
                  icon: Icons.event_repeat_rounded,
                  title: 'No Recurring Rules',
                  description: 'Automate repetitive subscriptions like streaming services, gym, and bills.',
                  actionText: 'Add Rule',
                  actionIcon: Icons.add,
                  onAction: () => _showAddOrEditSheet(),
                ),
              ] else ...[
                ..._rules.map((rule) {
                  return FintechCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CategoryIconAvatar(category: rule.category, size: 40, iconSize: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rule.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    rule.frequency.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Next: ${DateFormat('MMM d').format(rule.nextScheduledDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
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
                              rule.formattedAmount,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 4),
                            StatBadge.fromStatus(rule.status),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                          onSelected: (val) {
                            if (val == 'history') {
                              _showHistoryDialog(rule);
                            } else if (val == 'pause') {
                              _togglePauseResume(rule);
                            } else if (val == 'cancel') {
                              _cancelRule(rule);
                            } else if (val == 'edit') {
                              _showAddOrEditSheet(rule);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'history', child: Text('Execution History')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit Rule')),
                            PopupMenuItem(
                              value: 'pause',
                              child: Text(rule.isActive ? 'Pause Rule' : 'Resume Rule'),
                            ),
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Text('Cancel Rule', style: TextStyle(color: AppColors.error)),
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
