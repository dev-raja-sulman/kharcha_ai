import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/financial_advisor_model.dart';
import 'package:kharcha_ai/services/financial_advisor_service.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';

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
  final String? preferredCurrency;

  const FinancialAdvisorScreen({
    super.key,
    required this.advisorService,
    this.preferredCurrency,
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
      final response = await widget.advisorService.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: response.reply,
          isUser: false,
          provider: response.providerUsed,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: 'I encountered an issue analyzing your request. Please try again.',
          isUser: false,
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('AI Financial Advisor'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAdvisorData),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Context Ribbon
            if (_overview != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(bottom: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLedgerChip('Income', CurrencyFormatter.format(_overview!.totalIncomeThisMonth, currency: widget.preferredCurrency, compact: true), AppColors.success),
                    _buildLedgerChip('Expenses', CurrencyFormatter.format(_overview!.totalExpensesThisMonth, currency: widget.preferredCurrency, compact: true), AppColors.error),
                    _buildLedgerChip('Net', CurrencyFormatter.format(_overview!.netCashflow, currency: widget.preferredCurrency, compact: true), AppColors.primary),
                    _buildLedgerChip('Savings', '${_overview!.savingsRate.toStringAsFixed(0)}%', AppColors.purpleAccent),
                  ],
                ),
              ),
            ],

            if (_insights != null && _insights!.keyRecommendation.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _insights!.keyRecommendation,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Chat Messages List
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: SkeletonList(count: 3))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _buildChatBubble(msg, isDark);
                      },
                    ),
            ),

            if (_isSending) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(
                      'AI analyzing cashflow & ledger...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Suggested Prompts
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestedPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _suggestedPrompts[index];
                  return ActionChip(
                    label: Text(prompt),
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                    side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                    labelStyle: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    onPressed: _isSending ? null : () => _sendMessage(prompt),
                  );
                },
              ),
            ),

            // Message Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(top: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: 'Ask financial advisor a question...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF2F4F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildChatBubble(ChatMessage msg, bool isDark) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'KharchaAI Advisor',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                if (msg.provider != null) ...[
                  const Spacer(),
                  Text(
                    msg.provider!,
                    style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
