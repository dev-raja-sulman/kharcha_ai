import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/saving_goal_model.dart';
import 'package:kharcha_ai/services/saving_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';
import 'package:kharcha_ai/widgets/stat_badge.dart';

class SavingGoalDetailScreen extends StatefulWidget {
  final SavingService savingService;
  final SavingGoalModel goal;
  final String? preferredCurrency;

  const SavingGoalDetailScreen({
    super.key,
    required this.savingService,
    required this.goal,
    this.preferredCurrency,
  });

  @override
  State<SavingGoalDetailScreen> createState() => _SavingGoalDetailScreenState();
}

class _SavingGoalDetailScreenState extends State<SavingGoalDetailScreen> {
  late SavingGoalModel _goal;
  bool _isLoading = true;
  List<ContributionModel> _contributions = [];

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.savingService.getGoalById(_goal.id),
        widget.savingService.getContributions(_goal.id),
      ]);
      if (!mounted) return;
      setState(() {
        _goal = results[0] as SavingGoalModel;
        _contributions = results[1] as List<ContributionModel>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddContributionDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime contribDate = DateTime.now();

    final added = await showModalBottomSheet<bool>(
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
                        'Add to "${_goal.title}"',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx, false)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Remaining target: ${CurrencyFormatter.format(_goal.remainingAmount, currency: widget.preferredCurrency)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: amountController,
                    label: 'Contribution Amount *',
                    hint: 'e.g. 5000',
                    prefixIcon: Icons.attach_money_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: notesController,
                    label: 'Notes / Source (Optional)',
                    hint: 'e.g. Monthly salary savings',
                    prefixIcon: Icons.notes_rounded,
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'Confirm Contribution',
                    icon: Icons.check,
                    backgroundColor: AppColors.success,
                    onPressed: () async {
                      final val = double.tryParse(amountController.text.trim());
                      if (val == null || val <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')),
                        );
                        return;
                      }

                      try {
                        await widget.savingService.addContribution(
                          _goal.id,
                          amount: val,
                          contributionDate: contribDate,
                          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
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

    if (added == true) {
      _loadData();
    }
  }

  Future<void> _handleDeleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${_goal.title}"? Contributions will be removed.'),
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
        await widget.savingService.deleteGoal(_goal.id);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete goal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = (_goal.progressPercentage / 100).clamp(0.0, 1.0);
    final isDone = _goal.isCompleted;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(_goal.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _handleDeleteGoal,
            tooltip: 'Delete Goal',
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(top: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder)),
        ),
        child: CustomButton(
          text: 'Add Contribution',
          icon: Icons.add_circle_outline_rounded,
          backgroundColor: AppColors.success,
          onPressed: _showAddContributionDialog,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Padding(padding: EdgeInsets.all(18), child: SkeletonList(count: 3))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  children: [
                    // Goal Progress Hero Card
                    FintechCard(
                      gradient: isDone
                          ? const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : AppColors.navyHeroGradient,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isDone ? 'GOAL COMPLETED 🎉' : 'IN PROGRESS',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              StatBadge(
                                label: '${_goal.progressPercentage.toStringAsFixed(1)}%',
                                type: isDone ? StatBadgeType.success : StatBadgeType.info,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            CurrencyFormatter.format(_goal.currentAmount, currency: widget.preferredCurrency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: ${CurrencyFormatter.format(_goal.targetAmount, currency: widget.preferredCurrency)} • Due ${DateFormat('MMM dd, yyyy').format(_goal.targetDate)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDone ? AppColors.success : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isDone
                                ? 'Congratulations! You achieved this savings milestone.'
                                : 'Remaining: ${CurrencyFormatter.format(_goal.remainingAmount, currency: widget.preferredCurrency)}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Contributions History Header
                    Text(
                      'Contribution History (${_contributions.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_contributions.isEmpty) ...[
                      const EmptyStateView(
                        icon: Icons.savings_outlined,
                        title: 'No Contributions Yet',
                        description: 'Add your first deposit to this goal using the button below!',
                      ),
                    ] else ...[
                      ..._contributions.map((c) {
                        return FintechCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.successBg,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.notes?.isNotEmpty == true ? c.notes! : 'Deposit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(c.contributionDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+${CurrencyFormatter.format(c.amount, currency: widget.preferredCurrency)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.success,
                                ),
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
