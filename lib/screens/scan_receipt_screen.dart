import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/receipt_scan_model.dart';
import 'package:kharcha_ai/services/expense_service.dart';
import 'package:kharcha_ai/services/receipt_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';

enum ScanStep { select, scanning, review }

class ScanReceiptScreen extends StatefulWidget {
  final ReceiptScannerService receiptService;
  final ExpenseService expenseService;

  const ScanReceiptScreen({
    super.key,
    required this.receiptService,
    required this.expenseService,
  });

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  ScanStep _currentStep = ScanStep.select;

  Uint8List? _selectedImageBytes;
  String? _selectedFilename;
  final String _selectedProvider = 'gemini';

  String? _errorMessage;
  bool _isSavingExpense = false;

  ReceiptScanModel? _scanResult;
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'Card';

  final List<String> _categories = [
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

  final List<String> _paymentMethods = [
    'Card',
    'Cash',
    'EasyPaisa',
    'JazzCash',
    'Bank Transfer',
    'Other'
  ];

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _populateFormFromExtraction(ReceiptScanModel result) {
    _merchantController.text = result.merchantName ?? '';
    _amountController.text =
        result.amount != null ? result.amount!.toStringAsFixed(2) : '';
    _selectedDate = result.transactionDate ?? DateTime.now();

    if (_categories.contains(result.suggestedCategory)) {
      _selectedCategory = result.suggestedCategory;
    } else {
      _selectedCategory = 'Other';
    }

    final reason = result.categoryExplanation != null
        ? 'AI Note: ${result.categoryExplanation}'
        : 'Scanned via Gemini AI receipt scanner';
    _descController.text = reason;
  }

  Future<void> _handleStartScan({
    required Uint8List bytes,
    required String filename,
  }) async {
    setState(() {
      _selectedImageBytes = bytes;
      _selectedFilename = filename;
      _currentStep = ScanStep.scanning;
      _errorMessage = null;
    });

    try {
      final result = await widget.receiptService.scanReceipt(
        bytes: bytes,
        filename: filename,
        providerOverride: _selectedProvider,
      );

      if (!mounted) return;

      _populateFormFromExtraction(result);

      setState(() {
        _scanResult = result;
        _currentStep = ScanStep.review;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _currentStep = ScanStep.select;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to extract data from receipt. Try again with a clearer image.';
        _currentStep = ScanStep.select;
      });
    }
  }

  void _pickSampleReceipt(int sampleIndex) {
    // Generates a mock receipt image buffer for testing
    final sampleBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);

    final sampleNames = [
      'lahore_supermarket_receipt.png',
      'al_fatah_grocery_invoice.png',
      'shell_fuel_station_bill.png',
    ];

    _handleStartScan(
      bytes: sampleBytes,
      filename: sampleNames[sampleIndex % sampleNames.length],
    );
  }

  Future<void> _handleSaveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amountVal = double.tryParse(_amountController.text.trim());
    if (amountVal == null || amountVal <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }

    setState(() => _isSavingExpense = true);

    try {
      final title = _merchantController.text.trim().isNotEmpty
          ? _merchantController.text.trim()
          : 'Receipt Expense';

      final created = await widget.expenseService.createExpense(
        title: title,
        amount: amountVal,
        category: _selectedCategory,
        expenseDate: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense "${created.title}" recorded successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to save expense: $e');
    } finally {
      if (mounted) setState(() => _isSavingExpense = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('AI Receipt Scanner'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Indicator
                  Row(
                    children: [
                      _buildStepPill('1. Select', _currentStep == ScanStep.select, isDark),
                      const SizedBox(width: 8),
                      _buildStepPill('2. AI Scan', _currentStep == ScanStep.scanning, isDark),
                      const SizedBox(width: 8),
                      _buildStepPill('3. Verify', _currentStep == ScanStep.review, isDark),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_currentStep == ScanStep.select) ...[
                    // Provider Selector
                    FintechCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Engine',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Gemini 1.5 Flash Vision Multimodal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Upload Drop Zone Card
                    FintechCard(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 36),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Scan Any Paper or Digital Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'KharchaAI automatically extracts merchant, date, amount, items and assigns category.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickSampleReceipt(0),
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('Supermarket Sample'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _pickSampleReceipt(1),
                                icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                                label: const Text('Grocery Sample'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _pickSampleReceipt(2),
                                icon: const Icon(Icons.local_gas_station_outlined, size: 16),
                                label: const Text('Fuel Sample'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else if (_currentStep == ScanStep.scanning) ...[
                    // Scanning Animation View
                    FintechCard(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Analyzing Receipt with AI...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Extracting store name, total amount, taxes, and categorizing expenditure.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_currentStep == ScanStep.review) ...[
                    // Verification & Review Form
                    FintechCard(
                      gradient: AppColors.primaryGradient,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Receipt Extracted Successfully',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  _scanResult != null && _scanResult!.confidence > 0
                                      ? 'AI Confidence: ${(_scanResult!.confidence * 100).toInt()}% • Review before logging.'
                                      : 'Review extracted details below before logging into ledger.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_selectedImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                              if (_selectedFilename != null)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _selectedFilename!,
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    FintechCard(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CustomTextField(
                              controller: _merchantController,
                              label: 'Merchant / Store Name *',
                              hint: 'e.g. Imtiaz Super Market',
                              prefixIcon: Icons.storefront_rounded,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Enter merchant name' : null,
                            ),
                            const SizedBox(height: 14),

                            CustomTextField(
                              controller: _amountController,
                              label: 'Total Amount (PKR) *',
                              hint: '0.00',
                              prefixIcon: Icons.attach_money_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Enter amount' : null,
                            ),
                            const SizedBox(height: 14),

                            // Category
                            const Text('Suggested Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((c) {
                                final isSelected = _selectedCategory == c;
                                return ChoiceChip(
                                  label: Text(c),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() => _selectedCategory = c),
                                  selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // Payment Method
                            const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _paymentMethods.map((m) {
                                final isSelected = _selectedPaymentMethod == m;
                                return ChoiceChip(
                                  label: Text(m),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() => _selectedPaymentMethod = m),
                                  selectedColor: isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            CustomTextField(
                              controller: _descController,
                              label: 'AI Notes & Item Breakdown',
                              hint: 'Scanned receipt details',
                              prefixIcon: Icons.notes_rounded,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 20),

                            CustomButton(
                              text: 'Save to Kharcha Ledger',
                              icon: Icons.check,
                              isLoading: _isSavingExpense,
                              onPressed: _handleSaveExpense,
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => setState(() => _currentStep = ScanStep.select),
                              child: const Text('Scan Another Receipt'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepPill(String title, bool isActive, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : const Color(0xFFF2F4F7)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? Colors.white
                  : (isDark ? AppColors.darkTextMuted : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
