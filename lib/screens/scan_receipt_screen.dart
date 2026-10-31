import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/expense_model.dart';
import 'package:kharcha_ai/models/receipt_scan_model.dart';
import 'package:kharcha_ai/services/expense_service.dart';
import 'package:kharcha_ai/services/receipt_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/custom_text_field.dart';

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

  // Selected file state
  Uint8List? _selectedImageBytes;
  String? _selectedFilename;
  String _selectedProvider = 'gemini'; // 'gemini' or 'rule_based'

  // Processing state
  String? _errorMessage;
  bool _isSavingExpense = false;

  // Extracted data & form controllers
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
    'Cash',
    'Card',
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
        : 'Scanned via AI receipt scanner';
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
      final result = await widget.receiptService.scanReceiptBytes(
        bytes: bytes,
        filename: filename,
        providerOverride: _selectedProvider,
      );

      if (!mounted) return;

      setState(() {
        _scanResult = result;
        _populateFormFromExtraction(result);
        _currentStep = ScanStep.review;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _currentStep = ScanStep.select;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Scan error: ${e.toString()}';
        _currentStep = ScanStep.select;
      });
    }
  }

  Future<void> _handleConfirmAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsedAmount = double.tryParse(_amountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid amount greater than 0.';
      });
      return;
    }

    setState(() {
      _isSavingExpense = true;
      _errorMessage = null;
    });

    try {
      final ExpenseModel expense = await widget.expenseService.createExpense(
        title: _merchantController.text.trim(),
        amount: parsedAmount,
        category: _selectedCategory,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        expenseDate: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense "${expense.title}" created successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, expense);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSavingExpense = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save expense: ${e.toString()}';
        _isSavingExpense = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Receipt Scanner'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStepWidget(),
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case ScanStep.select:
        return _buildSelectStep();
      case ScanStep.scanning:
        return _buildScanningStep();
      case ScanStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildSelectStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.document_scanner, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Receipt OCR',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upload a receipt photo to automatically extract merchant, amount, date & category.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Provider selector
          const Text(
            'Select AI / Extraction Provider',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProvider,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'gemini',
                    child: Text('Google Gemini Vision (Cloud AI)'),
                  ),
                  DropdownMenuItem(
                    value: 'rule_based',
                    child: Text('Deterministic Rule-Based Engine (Local)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedProvider = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Quick sample generator button for immediate testing
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Ready to Scan Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Supports JPEG, PNG, and WebP up to 5MB.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Generate a sample receipt payload in bytes for testing
                      final sampleBytes = Uint8List.fromList([
                        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46,
                        0x00, 0x01, 0x01, 0x01, 0x00, 0x60, 0x00, 0x60, 0x00, 0x00,
                        0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06,
                        0x05, 0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C,
                        0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F,
                        0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
                        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28,
                        0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
                        0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF,
                        0xC0, 0x00, 0x0B, 0x08, 0x00, 0x64, 0x00, 0x64, 0x01, 0x01,
                        0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05,
                        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
                        0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01,
                        0x01, 0x00, 0x00, 0x3F, 0x00, 0x3F, 0xFF, 0xD9
                      ]);
                      _handleStartScan(
                        bytes: sampleBytes,
                        filename: 'kfc_family_meal_1850.jpg',
                      );
                    },
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Scan Sample Receipt (KFC 1850)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildScanningStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              _selectedProvider == 'gemini'
                  ? 'Analyzing receipt with Google Gemini Vision...'
                  : 'Processing receipt with local OCR engine...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Extracting merchant name, total, date, and suggested category.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final result = _scanResult!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status & Confidence Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            result.confidence >= 0.7
                                ? Icons.verified
                                : Icons.warning_amber_rounded,
                            color: result.confidence >= 0.7
                                ? AppColors.success
                                : AppColors.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          result.providerUsed,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (result.warnings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...result.warnings.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '• $w',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedImageBytes != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedImageBytes!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFilename ?? 'Receipt Image',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(_selectedImageBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'Review & Edit Extracted Fields',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 14),

            // Merchant Name
            CustomTextField(
              controller: _merchantController,
              label: 'Merchant / Shop Name',
              hint: 'e.g. KFC, Imtiaz Super Market',
              prefixIcon: Icons.storefront,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter merchant name' : null,
            ),
            const SizedBox(height: 14),

            // Amount
            CustomTextField(
              controller: _amountController,
              label: 'Total Amount (PKR)',
              hint: '0.00',
              prefixIcon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter expense amount';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Must be a valid positive number';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Category Selector
            const Text(
              'Category (Suggested by AI)',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Payment Method Selector
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPaymentMethod,
                  isExpanded: true,
                  items: _paymentMethods.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPaymentMethod = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Date Picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    const Text('Change', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Description / Notes
            CustomTextField(
              controller: _descController,
              label: 'Description / AI Reason',
              hint: 'Optional notes',
              prefixIcon: Icons.notes,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Confirm & Save button
            CustomButton(
              text: 'Confirm & Save Expense',
              isLoading: _isSavingExpense,
              icon: Icons.check_circle_outline,
              onPressed: _handleConfirmAndSave,
            ),
            const SizedBox(height: 12),

            // Retry scan button
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep = ScanStep.select;
                  _scanResult = null;
                  _errorMessage = null;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Scan Another Receipt'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
