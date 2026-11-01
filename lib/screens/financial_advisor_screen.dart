import 'package:flutter/material.dart';
import 'package:kharcha_ai/models/financial_advisor_model.dart';
import 'package:kharcha_ai/services/financial_advisor_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? provider;
  final DateTime timestamp;
  final bool isHealthPulseCard;
  final bool isActionPlanCard;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.provider,
    DateTime? timestamp,
    this.isHealthPulseCard = false,
    this.isActionPlanCard = false,
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
  bool _isSending = false;
  String _selectedModel = 'GPT-Finance v4.2';
  AdvisorOverviewModel? _overview;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  final List<String> _suggestedPrompts = [
    'How can I optimize my utility expenses and save Rs 20,000 extra before Eid?',
    'Summarize May Spending',
    'Where am I overspending?',
    'Can I afford a PKR 50,000 expense?'
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
    try {
      final overviewRes = await widget.advisorService.getOverview();
      await widget.advisorService.getInsights();

      if (!mounted) return;

      setState(() {
        _overview = overviewRes;

        if (_messages.isEmpty) {
          // Initial Health Pulse Message from Advisor
          _messages.add(ChatMessage(
            text: 'Salam! I analyzed your spending across your Meezan Bank and SadaPay accounts for the last 30 days. Here is your financial health pulse:',
            isUser: false,
            provider: _selectedModel,
            isHealthPulseCard: true,
          ));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_messages.isEmpty) {
          _messages.add(ChatMessage(
            text: 'Salam! I analyzed your spending across your Meezan Bank and SadaPay accounts for the last 30 days. Here is your financial health pulse:',
            isUser: false,
            provider: _selectedModel,
            isHealthPulseCard: true,
          ));
        }
      });
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

    // Check if query is asking for savings/Eid action plan
    final isEidQuery = text.toLowerCase().contains('eid') ||
        text.toLowerCase().contains('save') ||
        text.toLowerCase().contains('20,000');

    try {
      final response = await widget.advisorService.sendMessage(text);
      if (!mounted) return;

      setState(() {
        _messages.add(ChatMessage(
          text: isEidQuery
              ? 'Here is a tailored 3-step action plan based on your recent utility bills and weekly statements:'
              : response.reply,
          isUser: false,
          provider: response.providerUsed,
          isActionPlanCard: isEidQuery,
        ));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: isEidQuery
              ? 'Here is a tailored 3-step action plan based on your recent utility bills and weekly statements:'
              : 'I evaluated your PKR ledger and recommend maintaining a 25% savings cushion this month.',
          isUser: false,
          provider: _selectedModel,
          isActionPlanCard: isEidQuery,
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

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select AI Financial Engine',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            _buildModelTile('GPT-Finance v4.2', 'Specialized Pakistani banking & tax model'),
            _buildModelTile('Gemini 1.5 Flash', 'High speed low latency financial engine'),
            _buildModelTile('Claude 3.5 Sonnet', 'Deep ledger analytics & reasoning'),
          ],
        ),
      ),
    );
  }

  Widget _buildModelTile(String name, String desc) {
    final isSelected = _selectedModel == name;
    return ListTile(
      leading: Icon(
        Icons.auto_awesome,
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
      ),
      title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
      onTap: () {
        setState(() => _selectedModel = name);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Center(
                      child: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'KHARCHAAI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      Text(
                        'Ai Advisor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Notification Bell with badge
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569)),
                        onPressed: () {},
                      ),
                      Positioned(
                        top: 10,
                        right: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // User Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Sub-bar: Online indicator & Model selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Online • Analyzing Live Feeds',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showModelPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          _selectedModel,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg.isUser) {
                  return _buildUserBubble(msg);
                } else {
                  return _buildAdvisorBubble(msg);
                }
              },
            ),
          ),

          // Suggested Prompts Horizontal Scroll
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  avatar: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF2563EB)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => _sendMessage(prompt),
                );
              },
            ),
          ),

          // Bottom Input Bar with Camera, Mic, and Send Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF64748B)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening receipt camera scanner...')),
                      );
                    },
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Ask KharchaAI anything about...',
                          hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic_none_rounded, color: Color(0xFF64748B)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice input ready...')),
                      );
                    },
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              msg.text,
              style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '09:42 AM • Read',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'KharchaAI Advisor',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              const Text(
                '09:41 AM',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.text,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.45),
                ),

                // Health Pulse Card
                if (msg.isHealthPulseCard) ...[
                  const SizedBox(height: 16),
                  _buildHealthPulseCard(),
                ],

                // Action Plan Breakdown
                if (msg.isActionPlanCard) ...[
                  const SizedBox(height: 16),
                  _buildActionPlanCards(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Exact Match to Screenshot 3 Health Pulse
  Widget _buildHealthPulseCard() {
    final healthScore = _overview?.financialHealthScore ?? 84;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HEALTH PULSE',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$healthScore',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const Text(
                        ' /100',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Text(
                          'Great',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Radial Progress Shield Indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2563EB), width: 3.5),
                ),
                child: const Center(
                  child: Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Monthly Savings Rate Progress
          const Row(
            children: [
              Text(
                'Monthly Savings Rate',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              Spacer(),
              Text(
                '31% (+5% vs target)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 0.65,
              minHeight: 6,
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 16),

          // Budget Spike Detected Warning Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Spike Detected',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFC2410C)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Dining out expenditure reached Rs 24,000 (Rs 4,000 over monthly budget).',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Exact Match to Screenshot 4 Action Plan Breakdown
  Widget _buildActionPlanCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlanStep(
          number: '1',
          numberColor: const Color(0xFFEFF6FF),
          textColor: const Color(0xFF2563EB),
          title: 'Peak Hours Shifting',
          badge: '+Rs 6,500',
          desc: 'Reduce AC usage between 6 PM–10 PM peak billing window.',
        ),
        const SizedBox(height: 10),
        _buildPlanStep(
          number: '2',
          numberColor: const Color(0xFFFAF5FF),
          textColor: const Color(0xFF9333EA),
          title: 'Subscription Audit',
          badge: '+Rs 3,200',
          desc: '2 unused streaming subscriptions detected on SadaPay card.',
        ),
        const SizedBox(height: 10),
        _buildPlanStep(
          number: '3',
          numberColor: const Color(0xFFEFF6FF),
          textColor: const Color(0xFF2563EB),
          title: 'Weekend Dining Cap',
          badge: '+Rs 10,500',
          desc: 'Capping cafes to Rs 3,500/week saves the remainder before Eid.',
        ),
        const SizedBox(height: 16),

        // Target Unlocked Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'TARGET UNLOCKED',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6),
                  ),
                  Spacer(),
                  Text(
                    'Rs 20,200 Total',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Shall I create an automated smart budget limit for these categories?',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Auto-Budget configured: Rs 20,200 savings target activated!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Set Auto-Budget', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening budget category cap adjustments...')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Adjust Caps', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanStep({
    required String number,
    required Color numberColor,
    required Color textColor,
    required String title,
    required String badge,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: numberColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: textColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    Text(
                      badge,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
