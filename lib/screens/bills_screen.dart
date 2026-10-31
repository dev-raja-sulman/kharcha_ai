import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/bill_model.dart';
import 'package:kharcha_ai/screens/add_bill_screen.dart';
import 'package:kharcha_ai/services/bill_service.dart';

class BillsScreen extends StatefulWidget {
  final BillService billService;

  const BillsScreen({
    super.key,
    required this.billService,
  });

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<BillModel> _bills = [];
  BillSummaryModel? _summary;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
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
      case 1: // Pending
        return _bills.where((b) => b.status == 'unpaid').toList();
      case 2: // Overdue
        return _bills.where((b) => b.status == 'overdue').toList();
      case 3: // Paid
        return _bills.where((b) => b.status == 'paid').toList();
      case 0: // All
      default:
        return _bills;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electricity':
        return Icons.electric_bolt;
      case 'gas':
        return Icons.local_fire_department;
      case 'internet':
        return Icons.wifi;
      case 'mobile':
        return Icons.phone_android;
      case 'rent':
        return Icons.home;
      case 'water':
        return Icons.water_drop;
      case 'education':
        return Icons.school;
      case 'subscriptions':
        return Icons.subscriptions;
      default:
        return Icons.receipt_long;
    }
  }

  Future<void> _showMarkPaidDialog(BillModel bill) async {
    DateTime paidDate = DateTime.now();
    bool createExpense = true;
    String paymentMethod = 'Bank Transfer';
    final methods = ['Bank Transfer', 'JazzCash', 'EasyPaisa', 'Cash', 'Credit Card'];

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mark Bill as Paid',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bill: ${bill.title} (PKR ${_currencyFormat.format(bill.amount)})',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment method dropdown
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: methods.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Paid Date picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: paidDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 90)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => paidDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            'Paid On: ${_dateFormat.format(paidDate)}',
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Expense sync switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Log as Expense',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Records a linked expense without double-counting',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    value: createExpense,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setSheetState(() => createExpense = val),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Confirm Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        await widget.billService.markAsPaid(
          id: bill.id,
          paidDate: paidDate,
          createExpense: createExpense,
          paymentMethod: paymentMethod,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill marked as paid!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteBill(BillModel bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text('Are you sure you want to delete "${bill.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.billService.deleteBill(bill.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
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

  Widget _buildSummaryCards() {
    final pendingAmt = _summary?.totalPendingAmount ?? 0.0;
    final overdueAmt = _summary?.totalOverdueAmount ?? 0.0;
    final paidAmt = _summary?.totalPaidThisMonth ?? 0.0;
    final overdueCount = _summary?.overdueCount ?? 0;

    return Column(
      children: [
        if (overdueCount > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Attention: You have $overdueCount overdue bill(s) totaling PKR ${_currencyFormat.format(overdueAmt)}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // Pending
              Expanded(
                child: _buildMetricTile(
                  label: 'Pending',
                  amount: 'PKR ${_currencyFormat.format(pendingAmt)}',
                  count: '${_summary?.pendingCount ?? 0} bills',
                  color: AppColors.warning,
                  bgColor: AppColors.warningBg,
                ),
              ),
              const SizedBox(width: 8),
              // Overdue
              Expanded(
                child: _buildMetricTile(
                  label: 'Overdue',
                  amount: 'PKR ${_currencyFormat.format(overdueAmt)}',
                  count: '$overdueCount bills',
                  color: AppColors.error,
                  bgColor: AppColors.errorBg,
                ),
              ),
              const SizedBox(width: 8),
              // Paid this month
              Expanded(
                child: _buildMetricTile(
                  label: 'Paid (Month)',
                  amount: 'PKR ${_currencyFormat.format(paidAmt)}',
                  count: '${_summary?.paidCountThisMonth ?? 0} paid',
                  color: AppColors.success,
                  bgColor: AppColors.successBg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String amount,
    required String count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(BillModel bill) {
    Color badgeColor;
    Color badgeBg;
    String badgeText;

    if (bill.isPaid) {
      badgeColor = AppColors.success;
      badgeBg = AppColors.successBg;
      badgeText = 'PAID';
    } else if (bill.isOverdue) {
      badgeColor = AppColors.error;
      badgeBg = AppColors.errorBg;
      badgeText = 'OVERDUE';
    } else {
      badgeColor = AppColors.warning;
      badgeBg = AppColors.warningBg;
      badgeText = 'UNPAID';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(
                    _getCategoryIcon(bill.category),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              bill.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            bill.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                          Text(
                            'Due: ${_dateFormat.format(bill.dueDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: bill.isOverdue ? FontWeight.bold : FontWeight.normal,
                              color: bill.isOverdue ? AppColors.error : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppColors.cardBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    Text(
                      'PKR ${_currencyFormat.format(bill.amount)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!bill.isPaid)
                      ElevatedButton.icon(
                        onPressed: () => _showMarkPaidDialog(bill),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Mark Paid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              bill.paidDate != null
                                  ? 'Paid ${_dateFormat.format(bill.paidDate!)}'
                                  : 'Paid',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                      onPressed: () => _deleteBill(bill),
                      tooltip: 'Delete Bill',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsList(List<BillModel> bills) {
    if (bills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No bills found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the "+" button below to add your first bill.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 4),
        itemCount: bills.length,
        itemBuilder: (context, index) => _buildBillCard(bills[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bills & Obligations'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Overdue'),
            Tab(text: 'Paid'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildSummaryCards(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBillsList(_getFilteredBills(0)),
                      _buildBillsList(_getFilteredBills(1)),
                      _buildBillsList(_getFilteredBills(2)),
                      _buildBillsList(_getFilteredBills(3)),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AddBillScreen(billService: widget.billService),
            ),
          );
          if (added == true) {
            _loadData();
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
