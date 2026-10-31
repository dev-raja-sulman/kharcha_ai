import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/recurring_expense_model.dart';
import 'package:kharcha_ai/services/recurring_service.dart';

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
  String _selectedFilter = 'all'; // all, active, paused, cancelled
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
              : 'All recurring expenses are already up to date.'),
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
        content: Text('Are you sure you want to cancel "${rule.title}"? No further expenses will be generated, but previous expenses are saved.'),
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
    DateTime? endDate = editRule?.endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          editRule == null ? 'Create Recurring Expense' : 'Edit Recurring Rule',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Netflix, Gym, Rent', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount (PKR)', hintText: '2500.00', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) {
                              if (v != null) setSheetState(() => selectedCategory = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedFreq,
                            decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
                            items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(),
                            onChanged: (v) {
                              if (v != null) setSheetState(() => selectedFreq = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPayment,
                      decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                      items: _paymentMethods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => selectedPayment = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (editRule == null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start Date'),
                        subtitle: Text(startDate.toIso8601String().split('T')[0]),
                        trailing: const Icon(Icons.calendar_today, color: AppColors.primary),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setSheetState(() => startDate = picked);
                        },
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Optional End Date'),
                      subtitle: Text(endDate != null ? endDate!.toIso8601String().split('T')[0] : 'No end date (Never stops)'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => setSheetState(() => endDate = null),
                            ),
                          const Icon(Icons.event, color: AppColors.primary),
                        ],
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? startDate.add(const Duration(days: 90)),
                          firstDate: startDate,
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setSheetState(() => endDate = picked);
                      },
                    ),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Notes (Optional)', hintText: 'Monthly subscription...', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final amount = double.tryParse(amountController.text) ?? 0.0;
                        if (title.isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid title and positive amount.')),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        try {
                          if (editRule == null) {
                            await widget.recurringService.createRecurringRule(
                              title: title,
                              amount: amount,
                              category: selectedCategory,
                              frequency: selectedFreq,
                              paymentMethod: selectedPayment,
                              startDate: startDate,
                              endDate: endDate,
                              description: descController.text.trim(),
                            );
                          } else {
                            await widget.recurringService.updateRecurringRule(
                              id: editRule.id,
                              title: title,
                              amount: amount,
                              category: selectedCategory,
                              frequency: selectedFreq,
                              paymentMethod: selectedPayment,
                              endDate: endDate,
                              description: descController.text.trim(),
                            );
                          }
                          _loadRules();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Error saving rule: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      child: Text(editRule == null ? 'Create Recurring Rule' : 'Save Changes'),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'paused':
        return Colors.orange;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: AppColors.primary),
            tooltip: 'Process Due Occurrences',
            onPressed: _processDueExpenses,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRules,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Rule'),
        onPressed: () => _showAddOrEditSheet(),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: ['all', 'active', 'paused', 'cancelled'].map((f) {
                final isSelected = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f[0].toUpperCase() + f.substring(1)),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() => _selectedFilter = f);
                      _loadRules();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Rules List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rules.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_repeat, size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            const Text(
                              'No Recurring Expenses',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Automate your bills, rent, or subscriptions.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _showAddOrEditSheet(),
                              child: const Text('Create Rule'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRules,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                          itemCount: _rules.length,
                          itemBuilder: (context, index) {
                            final rule = _rules[index];
                            final statusColor = _getStatusColor(rule.status);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            rule.title,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            rule.status.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          rule.formattedAmount,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            rule.formattedFrequency,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            rule.category,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Next: ${rule.nextScheduledDate.toIso8601String().split('T')[0]}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        if (rule.endDate != null) ...[
                                          const SizedBox(width: 12),
                                          const Icon(Icons.flag_outlined, size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ends: ${rule.endDate!.toIso8601String().split('T')[0]}',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.history, size: 16),
                                          label: const Text('History'),
                                          onPressed: () => _showHistoryDialog(rule),
                                        ),
                                        if (!rule.isCancelled && !rule.isCompleted) ...[
                                          IconButton(
                                            icon: Icon(
                                              rule.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                              color: rule.isActive ? Colors.orange : AppColors.success,
                                            ),
                                            tooltip: rule.isActive ? 'Pause Rule' : 'Resume Rule',
                                            onPressed: () => _togglePauseResume(rule),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            tooltip: 'Edit Rule',
                                            onPressed: () => _showAddOrEditSheet(rule),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                                            tooltip: 'Cancel Rule',
                                            onPressed: () => _cancelRule(rule),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
