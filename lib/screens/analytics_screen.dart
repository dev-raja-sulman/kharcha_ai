import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/analytics_model.dart';
import 'package:kharcha_ai/services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final AnalyticsService analyticsService;

  const AnalyticsScreen({super.key, required this.analyticsService});

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics & AI Insights'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                    ),

                  if (_analytics != null) ...[
                    // Metric Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Total Spending',
                            'PKR ${_analytics!.totalSpent.toStringAsFixed(2)}',
                            Icons.account_balance_wallet_outlined,
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Daily Velocity',
                            'PKR ${_analytics!.averageDailySpending.toStringAsFixed(2)}',
                            Icons.speed_outlined,
                            AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Month-over-Month Comparison Card
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.cardBorder),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Month-over-Month Trend',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Previous Month', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    Text(
                                      'PKR ${_analytics!.monthComparison.previousMonthTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _analytics!.monthComparison.trend == 'decreased'
                                        ? AppColors.success.withOpacity(0.12)
                                        : (_analytics!.monthComparison.trend == 'increased'
                                            ? AppColors.error.withOpacity(0.12)
                                            : AppColors.primarySurface),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _analytics!.monthComparison.trend == 'no_previous_data'
                                        ? 'Baseline'
                                        : '${_analytics!.monthComparison.percentageChange >= 0 ? '+' : ''}${_analytics!.monthComparison.percentageChange.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _analytics!.monthComparison.trend == 'decreased'
                                          ? AppColors.success
                                          : (_analytics!.monthComparison.trend == 'increased'
                                              ? AppColors.error
                                              : AppColors.primary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // AI Spending Insights Section
                    const Text('AI Spending Observations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ..._insights.map((ins) {
                      Color badgeCol = AppColors.primary;
                      if (ins.severity == 'warning') badgeCol = Colors.orange;
                      if (ins.severity == 'success') badgeCol = AppColors.success;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppColors.cardBorder),
                        ),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: badgeCol.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.lightbulb_outline, size: 18, color: badgeCol),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ins.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(ins.message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),

                    // Category Breakdown
                    const Text('Category-Wise Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ..._analytics!.categoryBreakdown.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${cat.category} (${cat.count} txns)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('PKR ${cat.amount.toStringAsFixed(2)} (${cat.percentage.toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (cat.percentage / 100.0).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}
