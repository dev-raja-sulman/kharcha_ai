import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/analytics_model.dart';
import 'package:kharcha_ai/services/analytics_service.dart';
import 'package:kharcha_ai/widgets/category_icon_avatar.dart';
import 'package:kharcha_ai/widgets/empty_state_view.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';

class AnalyticsScreen extends StatefulWidget {
  final AnalyticsService analyticsService;
  final String? preferredCurrency;

  const AnalyticsScreen({
    super.key,
    required this.analyticsService,
    this.preferredCurrency,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  SpendingAnalyticsModel? _analytics;
  List<SpendingInsightItemModel> _insights = [];

  final int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait([
        widget.analyticsService.getSpendingAnalytics(month: _selectedMonth, year: _selectedYear),
        widget.analyticsService.getInsights(month: _selectedMonth, year: _selectedYear),
      ]);

      if (!mounted) return;
      setState(() {
        _analytics = futures[0] as SpendingAnalyticsModel;
        _insights = futures[1] as List<SpendingInsightItemModel>;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics & AI Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(18.0),
                child: SkeletonList(count: 4),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                      ),

                    if (_analytics != null) ...[
                      // Total Spent Hero Card
                      FintechCard(
                        gradient: AppColors.navyHeroGradient,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Monthly Total Expenditure',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.format(_analytics!.totalSpent, currency: widget.preferredCurrency),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Builder(
                              builder: (context) {
                                final momChange = _analytics!.momChangePercentage;
                                final isPositiveOrNeutral = momChange <= 0;
                                return Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPositiveOrNeutral
                                            ? AppColors.success.withOpacity(0.2)
                                            : AppColors.error.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isPositiveOrNeutral
                                                ? Icons.trending_down_rounded
                                                : Icons.trending_up_rounded,
                                            size: 14,
                                            color: isPositiveOrNeutral
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${momChange.abs().toStringAsFixed(1)}% vs Last Month',
                                            style: TextStyle(
                                              color: isPositiveOrNeutral
                                                  ? AppColors.success
                                                  : AppColors.error,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Metrics Two-Column Row
                      Row(
                        children: [
                          Expanded(
                            child: FintechCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySurface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Daily Average',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.format(_analytics!.dailyAverage, currency: widget.preferredCurrency, compact: true),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
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
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.purpleBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.purpleAccent),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Transactions',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_analytics!.transactionCount} logged',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Spending by Category Card
                      FintechCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category Distribution',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ..._analytics!.categoryBreakdown.map((cat) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CategoryIconAvatar(category: cat.category, size: 30, iconSize: 15, borderRadius: 8),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            cat.category,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(cat.amount, currency: widget.preferredCurrency),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${cat.percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (cat.percentage / 100).clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: isDark ? const Color(0xFF1E2838) : const Color(0xFFF2F4F7),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          CategoryIconAvatar.getMeta(cat.category).color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // AI Insights Section
                    if (_insights.isNotEmpty) ...[
                      Text(
                        'Proactive AI Insights',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._insights.map((insight) {
                        return FintechCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      insight.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      insight.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    if (_analytics == null && !_isLoading) ...[
                      const EmptyStateView(
                        icon: Icons.insights_rounded,
                        title: 'No Analytics Data',
                        description: 'Record some income and expenses to view category breakdowns and trends.',
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}
