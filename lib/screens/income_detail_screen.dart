import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/income_model.dart';
import 'package:kharcha_ai/screens/add_income_screen.dart';
import 'package:kharcha_ai/services/income_service.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';

class IncomeDetailScreen extends StatefulWidget {
  final IncomeModel income;
  final IncomeService incomeService;

  const IncomeDetailScreen({
    super.key,
    required this.income,
    required this.incomeService,
  });

  @override
  State<IncomeDetailScreen> createState() => _IncomeDetailScreenState();
}

class _IncomeDetailScreenState extends State<IncomeDetailScreen> {
  late IncomeModel _income;

  @override
  void initState() {
    super.initState();
    _income = widget.income;
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Income'),
        content: Text('Are you sure you want to delete "${_income.title}"?'),
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
        await widget.incomeService.deleteIncome(_income.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Income deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddIncomeScreen(
          incomeService: widget.incomeService,
          existingIncome: _income,
        ),
      ),
    );

    if (updated == true && mounted) {
      try {
        final refreshed = await widget.incomeService.getIncomeById(_income.id);
        if (!mounted) return;
        setState(() => _income = refreshed);
      } catch (_) {
        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmount = CurrencyFormatter.format(_income.amount, currency: _income.currency);
    final dateStr = DateFormat('MMMM dd, yyyy').format(_income.incomeDate);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Income Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _handleEdit,
            tooltip: 'Edit Income',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _handleDelete,
            tooltip: 'Delete Income',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  // Amount Banner
                  FintechCard(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _income.sourceName ?? 'Income',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '+$formattedAmount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _income.title,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Detail Card
                  FintechCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.calendar_today_rounded, 'Received On', dateStr, isDark),
                        Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                        _buildDetailRow(Icons.account_balance_rounded, 'Payment Method', _income.paymentMethod, isDark),
                        Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                        _buildDetailRow(Icons.paid_outlined, 'Original Currency', _income.currency, isDark),
                        if (_income.description != null && _income.description!.isNotEmpty) ...[
                          Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                          _buildDetailRow(Icons.notes_rounded, 'Notes / Description', _income.description!, isDark),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Entry'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _handleDelete,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete Entry'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.errorBg,
                            foregroundColor: AppColors.error,
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
