import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/report_model.dart';
import 'package:kharcha_ai/services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  final ReportService reportService;

  const ReportsScreen({
    super.key,
    required this.reportService,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = false;
  String _selectedReportType = 'monthly'; // daily, weekly, monthly, yearly, custom
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedCategory;
  AdvancedReportModel? _report;

  final List<String> _reportTypes = ['daily', 'weekly', 'monthly', 'yearly', 'custom'];
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
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final rep = await widget.reportService.getAdvancedReport(
        reportType: _selectedReportType,
        startDate: _selectedReportType == 'custom' ? _startDate : null,
        endDate: _selectedReportType == 'custom' ? _endDate : null,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      if (!mounted) return;
      setState(() => _report = rep);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load report: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating CSV export...')),
      );
      final csvString = await widget.reportService.downloadCsvReport(
        reportType: _selectedReportType,
        startDate: _selectedReportType == 'custom' ? _startDate : null,
        endDate: _selectedReportType == 'custom' ? _endDate : null,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV ready (${csvString.length} bytes downloaded).'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF export...')),
      );
      final pdfBytes = await widget.reportService.downloadPdfReport(
        reportType: _selectedReportType,
        startDate: _selectedReportType == 'custom' ? _startDate : null,
        endDate: _selectedReportType == 'custom' ? _endDate : null,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF ready (${pdfBytes.length} bytes downloaded).'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_outlined),
            tooltip: 'Download CSV',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download PDF',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadReport,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Column(
              children: [
                // Report Type Segments
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _reportTypes.map((type) {
                      final isSelected = _selectedReportType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type[0].toUpperCase() + type.substring(1)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedReportType = type);
                              _loadReport();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Custom Date Range Selectors
                if (_selectedReportType == 'custom') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range, size: 16),
                          label: Text(
                            'From: ${_startDate.toIso8601String().split('T')[0]}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: _endDate,
                            );
                            if (picked != null) {
                              setState(() => _startDate = picked);
                              _loadReport();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(
                            'To: ${_endDate.toIso8601String().split('T')[0]}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _endDate = picked);
                              _loadReport();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                // Category Filter Chips
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = (_selectedCategory == null && cat == 'All') || _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withOpacity(0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _selectedCategory = cat == 'All' ? null : cat;
                            });
                            _loadReport();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Main Report Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _report == null
                    ? const Center(child: Text('No report data available.'))
                    : RefreshIndicator(
                        onRefresh: _loadReport,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Period Banner
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDFA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCCFBF1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Period: ${_report!.startDate.toIso8601String().split('T')[0]} to ${_report!.endDate.toIso8601String().split('T')[0]}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 2. Summary Metric Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      'Total Spent',
                                      _report!.formattedTotalExpenditure,
                                      Icons.account_balance_wallet_outlined,
                                      AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMetricCard(
                                      'Transactions',
                                      '${_report!.totalExpenses}',
                                      Icons.receipt_long_outlined,
                                      Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      'Daily Average',
                                      _report!.formattedAverageDaily,
                                      Icons.trending_up,
                                      Colors.teal,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMetricCard(
                                      'Top Category',
                                      _report!.highestSpendingCategory?.category ?? '—',
                                      Icons.star_outline,
                                      Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 3. Recurring vs Regular Breakdown Card
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Recurring vs One-Off Spending',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Recurring (Commitments)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                              const SizedBox(height: 2),
                                              Text(
                                                _report!.recurringVsRegular.formattedRecurringAmount,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                                              ),
                                              Text(
                                                '${_report!.recurringVsRegular.recurringPercentage.toStringAsFixed(1)}% (${_report!.recurringVsRegular.recurringCount} txs)',
                                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Regular (One-Off)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                              const SizedBox(height: 2),
                                              Text(
                                                _report!.recurringVsRegular.formattedRegularAmount,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                              ),
                                              Text(
                                                '${_report!.recurringVsRegular.regularPercentage.toStringAsFixed(1)}% (${_report!.recurringVsRegular.regularCount} txs)',
                                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 4. Period Comparison Card
                              if (_report!.periodComparison != null) ...[
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  elevation: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Period-over-Period Comparison',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Compared to previous period: ${_report!.periodComparison!.previousStartDate.toIso8601String().split('T')[0]} to ${_report!.periodComparison!.previousEndDate.toIso8601String().split('T')[0]}',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Previous Spend: ${_report!.periodComparison!.formattedPreviousExpenditure}'),
                                            Row(
                                              children: [
                                                Icon(
                                                  _report!.periodComparison!.trend == 'increased'
                                                      ? Icons.arrow_upward
                                                      : _report!.periodComparison!.trend == 'decreased'
                                                          ? Icons.arrow_downward
                                                          : Icons.remove,
                                                  size: 16,
                                                  color: _report!.periodComparison!.trend == 'increased'
                                                      ? AppColors.error
                                                      : _report!.periodComparison!.trend == 'decreased'
                                                          ? AppColors.success
                                                          : AppColors.textSecondary,
                                                ),
                                                Text(
                                                  '${_report!.periodComparison!.difference >= 0 ? '+' : ''}${_report!.periodComparison!.percentageChange.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: _report!.periodComparison!.trend == 'increased'
                                                        ? AppColors.error
                                                        : _report!.periodComparison!.trend == 'decreased'
                                                            ? AppColors.success
                                                            : AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // 5. Category Breakdown
                              const Text(
                                'Category Breakdown',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              if (_report!.categoryBreakdown.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: Text('No categories recorded in this period.')),
                                )
                              else
                                ..._report!.categoryBreakdown.map((item) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(item.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              Text(item.formattedAmount, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          LinearProgressIndicator(
                                            value: (item.percentage / 100.0).clamp(0.0, 1.0),
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            color: AppColors.primary,
                                            minHeight: 6,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '${item.formattedPercentage} (${item.count} transactions)',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              const SizedBox(height: 24),

                              // 6. Action Export Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.table_chart, size: 18),
                                      label: const Text('Export CSV'),
                                      onPressed: _exportCsv,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E293B),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                                      label: const Text('Export PDF'),
                                      onPressed: _exportPdf,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const BorderSide(color: Color(0xFFE2E8F0)).color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color == AppColors.primary ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
