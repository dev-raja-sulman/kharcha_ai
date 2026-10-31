import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/saving_goal_model.dart';
import 'package:kharcha_ai/screens/saving_goal_detail_screen.dart';
import 'package:kharcha_ai/services/saving_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';
import 'package:kharcha_ai/widgets/stat_badge.dart';

class SavingsGoalsScreen extends StatefulWidget {
  final SavingService savingService;
  final String? preferredCurrency;

  const SavingsGoalsScreen({
    super.key,
    required this.savingService,
    this.preferredCurrency,
  });

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  bool _isLoading = true;
  List<SavingGoalModel> _goals = [];
  double _totalSavings = 0.0;
  String _selectedStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);

    try {
      final statusQuery = _selectedStatusFilter == 'All'
          ? null
          : _selectedStatusFilter == 'In Progress'
              ? 'in_progress'
              : 'completed';

      final result = await widget.savingService.getGoals(statusFilter: statusQuery);

      if (!mounted) return;

      setState(() {
        _goals = result.items;
        _totalSavings = result.totalSavings;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateGoalDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final targetController = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 90));

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                        'Create Savings Goal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: titleController,
                    label: 'Goal Title *',
                    hint: 'e.g. Emergency Fund, New Laptop, Umrah Trip',
                    prefixIcon: Icons.flag_rounded,
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: targetController,
                    label: 'Target Amount (PKR) *',
                    hint: 'e.g. 150000',
                    prefixIcon: Icons.attach_money_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),

                  const Text('Target Completion Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => targetDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(targetDate),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: descriptionController,
                    label: 'Description / Purpose (Optional)',
                    hint: 'Why are you saving for this goal?',
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'Create Goal',
                    icon: Icons.check,
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final targetVal = double.tryParse(targetController.text.trim());

                      if (title.isEmpty || targetVal == null || targetVal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter valid goal details')),
                        );
                        return;
                      }

                      try {
                        await widget.savingService.createGoal(
                          title: title,
                          targetAmount: targetVal,
                          targetDate: targetDate,
                          description: descriptionController.text.trim().isNotEmpty
                              ? descriptionController.text.trim()
                              : null,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error creating goal: $e')),
                        );
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

    if (created == true) {
      _loadGoals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadGoals,
            tooltip: 'Refresh Goals',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGoalDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Goal', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGoals,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              // Total Savings Hero Card
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
                          'Total Accumulated Savings',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_goals.length} Goals',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(_totalSavings, currency: widget.preferredCurrency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Status Filter Chips
              Row(
                children: ['All', 'In Progress', 'Completed'].map((status) {
                  final isSelected = _selectedStatusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedStatusFilter = status);
                        _loadGoals();
                      },
                      selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Goals List
              if (_isLoading) ...[
                const SkeletonList(count: 3),
              ] else if (_goals.isEmpty) ...[
                EmptyStateView(
                  icon: Icons.savings_outlined,
                  title: 'No Goals Found',
                  description: 'Set ambitious savings milestones for future investments or peace of mind.',
                  actionText: 'Create Goal',
                  actionIcon: Icons.add,
                  onAction: _showCreateGoalDialog,
                ),
              ] else ...[
                ..._goals.map((g) {
                  final ratio = (g.progressPercentage / 100).clamp(0.0, 1.0);
                  final isDone = g.isCompleted;

                  return FintechCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SavingGoalDetailScreen(
                            savingService: widget.savingService,
                            goal: g,
                            preferredCurrency: widget.preferredCurrency,
                          ),
                        ),
                      ).then((_) => _loadGoals());
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDone ? AppColors.successBg : AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isDone ? Icons.check_circle_rounded : Icons.savings_rounded,
                                color: isDone ? AppColors.success : AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Target: ${DateFormat('MMM yyyy').format(g.targetDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatBadge(
                              label: '${g.progressPercentage.toStringAsFixed(0)}%',
                              type: isDone ? StatBadgeType.success : StatBadgeType.info,
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
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
                              isDone ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saved: ${CurrencyFormatter.format(g.currentAmount, currency: widget.preferredCurrency)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDone ? AppColors.success : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                              ),
                            ),
                            Text(
                              'Goal: ${CurrencyFormatter.format(g.targetAmount, currency: widget.preferredCurrency)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
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
