import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/models/financial_advisor_model.dart';
import 'package:kharcha_ai/services/financial_advisor_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? provider;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.provider,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class FinancialAdvisorScreen extends StatefulWidget {
  final FinancialAdvisorService advisorService;

  const FinancialAdvisorScreen({
    super.key,
    required this.advisorService,
  });

  @override
  State<FinancialAdvisorScreen> createState() => _FinancialAdvisorScreenState();
}

class _FinancialAdvisorScreenState extends State<FinancialAdvisorScreen> {
  bool _isLoading = true;
  bool _isSending = false;
  AdvisorOverviewModel? _overview;
  AdvisorInsightsModel? _insights;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  final List<String> _suggestedPrompts = [
    'Can I afford a PKR 50,000 expense?',
    'How can I boost my savings rate?',
    'What bills do I have due?',
    'What are my highest spending areas?',
    'Am I on track with my savings goals?'
  ];

  @override
  void initState() {
    super.initState();
    _loadAdvisorData();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAdvisorData() async {
    setState(() => _isLoading = true);
    try {
      final overviewRes = await widget.advisorService.getOverview();
      final insightsRes = await widget.advisorService.getInsights();

      if (!mounted) return;

      setState(() {
        _overview = overviewRes;
        _insights = insightsRes;
        _isLoading = false;

        if (_messages.isEmpty) {
          _messages.add(ChatMessage(
            text: 'Hello! I am your KharchaAI Financial Intelligence Advisor. '
                'I provide personalized budgeting advice grounded directly in your real cashflow and savings ledgers with zero PII shared.',
            isUser: false,
            provider: insightsRes.providerUsed,
          ));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(String query) async {
    final text = query.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isSending = true;
    });

    _scrollToBottom();

    try {
      final res = await widget.advisorService.sendMessage(text);
      if (!mounted) return;

      setState(() {
        _messages.add(ChatMessage(
          text: res.reply,
          isUser: false,
          provider: res.providerUsed,
        ));
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an issue processing your financial query. Please try again.',
          isUser: false,
        ));
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return const Color(0xFF0284C7);
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildHealthScoreHeader() {
    if (_overview == null) return const SizedBox.shrink();

    final score = _overview!.financialHealthScore;
    final color = _getScoreColor(score);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(
                      value: score / 100.0,
                      backgroundColor: color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeWidth: 6,
                    ),
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_overview!.financialHealthStatus} Health',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_insights != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _insights!.providerUsed.startsWith('gemini') ? 'Gemini AI' : 'Rule Engine',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _insights?.summaryHeadline ?? 'Comprehensive monthly financial review',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('Income', 'PKR ${_currencyFormat.format(_overview!.totalIncomeThisMonth)}', AppColors.success),
              _buildMiniMetric('Expenses', 'PKR ${_currencyFormat.format(_overview!.totalExpensesThisMonth)}', AppColors.error),
              _buildMiniMetric('Surplus', 'PKR ${_currencyFormat.format(_overview!.netCashflow)}', AppColors.primary),
              _buildMiniMetric('Savings Rate', '${_overview!.savingsRate}%', color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsCard() {
    if (_insights == null || _insights!.insights.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Financial Recommendations',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _insights!.keyRecommendation,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._insights!.insights.take(3).map((item) {
            IconData icon = Icons.check_circle_outline;
            Color iconColor = AppColors.success;
            if (item.type == 'alert') {
              icon = Icons.warning_amber_rounded;
              iconColor = AppColors.error;
            } else if (item.type == 'improvement') {
              icon = Icons.trending_up;
              iconColor = AppColors.warning;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChatBubbles() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        if (msg.isUser) {
          return Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(2),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
              ),
            ),
          );
        } else {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(14),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                  bottomLeft: Radius.circular(2),
                ),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.primarySurface,
                        child: Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Advisor AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (msg.provider != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${msg.provider}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg.text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Financial Advisor'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdvisorData,
            tooltip: 'Refresh Intelligence',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildHealthScoreHeader(),
                _buildRecommendationsCard(),
                // Suggested prompt chips
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _suggestedPrompts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final prompt = _suggestedPrompts[index];
                      return ActionChip(
                        label: Text(
                          prompt,
                          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                        ),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.cardBorder),
                        onPressed: () => _sendMessage(prompt),
                      );
                    },
                  ),
                ),
                // Chat conversation area
                Expanded(
                  child: _buildChatBubbles(),
                ),
                if (_isSending)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Advisor is analyzing your finances...',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                // Chat input bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.cardBorder)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Ask advisor (e.g. Can I afford a laptop?)...',
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: AppColors.cardBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: AppColors.cardBorder),
                            ),
                          ),
                          onSubmitted: (text) => _sendMessage(text),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.send, size: 18, color: Colors.white),
                          onPressed: () => _sendMessage(_textController.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
