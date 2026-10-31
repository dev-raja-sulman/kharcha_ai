import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/report_model.dart';
import 'package:kharcha_ai/services/report_service.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';

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
  String _selectedReportType = 'monthly';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Financial Reports & Export'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? AppColors.darkSurface : Colors.white,
              child: Column(
                children: [
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
                            selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
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
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = (_selectedCategory ?? 'All') == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 11,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedCategory = cat == 'All' ? null : cat);
                                _loadReport();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_selectedReportType == 'custom') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range, size: 14),
                            label: Text(
                              'From: ${DateFormat('yyyy-MM-dd').format(_startDate)}',
                              style: const TextStyle(fontSize: 11),
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
                            icon: const Icon(Icons.event, size: 14),
                            label: Text(
                              'To: ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                              style: const TextStyle(fontSize: 11),
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
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),

            // Content
            Expanded(
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(18), child: SkeletonList(count: 4))
                  : _report == null
                      ? const Center(child: Text('No report data available.'))
                      : RefreshIndicator(
                          onRefresh: _loadReport,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Period Banner
                                FintechCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month, color: AppColors.primary, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Period: ${DateFormat('MMM dd').format(_report!.startDate)} — ${DateFormat('MMM dd, yyyy').format(_report!.endDate)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Summary Metric Cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: FintechCard(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Total Spent', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary)),
                                            const SizedBox(height: 4),
                                            Text(
                                              _report!.formattedTotalExpenditure,
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FintechCard(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Daily Average', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary)),
                                            const SizedBox(height: 4),
                                            Text(
                                              _report!.formattedAverageDaily,
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Recurring vs One-Off Breakdown Card
                                FintechCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Recurring vs One-Off Commitments',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Recurring', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary, fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text(_report!.recurringVsRegular.formattedRecurringAmount, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.blue)),
                                              Text('${_report!.recurringVsRegular.recurringPercentage.toStringAsFixed(1)}% (${_report!.recurringVsRegular.recurringCount} txs)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('One-Off', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary, fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text(_report!.recurringVsRegular.formattedRegularAmount, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
                                              Text('${_report!.recurringVsRegular.regularPercentage.toStringAsFixed(1)}% (${_report!.recurringVsRegular.regularCount} txs)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Category Distribution
                                if (_report!.categoryBreakdown.isNotEmpty) ...[
                                  FintechCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Category Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                                        const SizedBox(height: 12),
                                        ..._report!.categoryBreakdown.map((cat) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10.0),
                                            child: Row(
                                              children: [
                                                CategoryIconAvatar(category: cat.category, size: 26, iconSize: 13, borderRadius: 6),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(cat.category, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                                                ),
                                                Text(cat.formattedAmount, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                                                const SizedBox(width: 8),
                                                Text('${cat.percentage.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),

                                // Export Buttons Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _exportCsv,
                                        icon: const Icon(Icons.table_view_outlined, size: 16),
                                        label: const Text('Export CSV'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: const BorderSide(color: AppColors.primary),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _exportPdf,
                                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                                        label: const Text('Export PDF'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
