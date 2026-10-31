import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/bill_model.dart';
import 'package:kharcha_ai/screens/add_bill_screen.dart';
import 'package:kharcha_ai/services/bill_service.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';
import 'package:kharcha_ai/widgets/stat_badge.dart';

class BillsScreen extends StatefulWidget {
  final BillService billService;
  final String? preferredCurrency;

  const BillsScreen({
    super.key,
    required this.billService,
    this.preferredCurrency,
  });

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<BillModel> _bills = [];
  BillSummaryModel? _summary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final billsResult = await widget.billService.getBills();
      final summaryResult = await widget.billService.getBillSummary();

      if (!mounted) return;
      setState(() {
        _bills = billsResult.items;
        _summary = summaryResult;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<BillModel> _getFilteredBills(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _bills.where((b) => b.status == 'unpaid').toList();
      case 2:
        return _bills.where((b) => b.status == 'overdue').toList();
      case 3:
        return _bills.where((b) => b.status == 'paid').toList();
      case 0:
      default:
        return _bills;
    }
  }

  Future<void> _handlePayBill(BillModel bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Bill as Paid'),
        content: Text(
          'Mark "${bill.title}" as paid and automatically record an expense of ${CurrencyFormatter.format(bill.amount, currency: widget.preferredCurrency)}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Pay & Log Expense'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.billService.markAsPaid(id: bill.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill marked as paid and expense logged!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleDeleteBill(BillModel bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text('Delete bill reminder for "${bill.title}"?'),
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
        await widget.billService.deleteBill(bill.id);
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPendingAmount = _summary?.totalPendingAmount ?? 0.0;
    final pendingCount = _summary?.pendingCount ?? 0;
    final overdueCount = _summary?.overdueCount ?? 0;

    final filteredList = _getFilteredBills(_tabController.index);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Bills & Recurring Obligations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddBillScreen(billService: widget.billService)),
          ).then((_) => _loadData());
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Bill', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            children: [
              // Pending Commitments Hero Card
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
                          'Total Unpaid Bill Obligations',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        if (overdueCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$overdueCount OVERDUE',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$pendingCount pending',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(totalPendingAmount, currency: widget.preferredCurrency),
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

              // Segmented Tab Filter
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? AppColors.darkPrimarySurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'All (${_bills.length})'),
                    Tab(text: 'Unpaid ($pendingCount)'),
                    Tab(text: 'Overdue ($overdueCount)'),
                    const Tab(text: 'Paid'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bills List
              if (_isLoading) ...[
                const SkeletonList(count: 4),
              ] else if (filteredList.isEmpty) ...[
                EmptyStateView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No Bills in this Section',
                  description: 'All clear! Add recurring obligations like Electricity, Gas, Rent or Subscriptions.',
                  actionText: 'Add Bill',
                  actionIcon: Icons.add,
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddBillScreen(billService: widget.billService)),
                    ).then((_) => _loadData());
                  },
                ),
              ] else ...[
                ...filteredList.map((bill) {
                  final isPaid = bill.status == 'paid';
                  final isOverdue = bill.status == 'overdue';

                  return FintechCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CategoryIconAvatar(category: bill.category, size: 38, iconSize: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bill.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Due: ${DateFormat('MMM dd, yyyy').format(bill.dueDate)} • ${bill.frequency}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOverdue ? AppColors.error : (isDark ? AppColors.darkTextMuted : AppColors.textSecondary),
                                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(bill.amount, currency: widget.preferredCurrency),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isPaid ? AppColors.success : (isOverdue ? AppColors.error : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                StatBadge.fromStatus(bill.status),
                              ],
                            ),
                          ],
                        ),
                        if (!isPaid) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handlePayBill(bill),
                                  icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                                  label: const Text('Mark Paid & Log Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                    side: const BorderSide(color: AppColors.success),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                                onPressed: () => _handleDeleteBill(bill),
                              ),
                            ],
                          ),
                        ],
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
