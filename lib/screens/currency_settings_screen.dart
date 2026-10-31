import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/currency/currency_controller.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/user_model.dart';
import 'package:kharcha_ai/services/currency_service.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';

class CurrencySettingsScreen extends StatefulWidget {
  final CurrencyService currencyService;
  final UserModel? currentUser;
  final String? currentCurrency;
  final ValueChanged<String>? onCurrencyChanged;

  const CurrencySettingsScreen({
    super.key,
    required this.currencyService,
    this.currentUser,
    this.currentCurrency,
    this.onCurrencyChanged,
  });

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  late String _selectedCurrency;
  bool _isSaving = false;
  String _searchFilter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.currentUser?.preferredCurrency ?? widget.currentCurrency ?? 'PKR';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSelectCurrency(String code) async {
    if (code == _selectedCurrency || _isSaving) return;

    setState(() {
      _selectedCurrency = code;
      _isSaving = true;
    });

    try {
      final updatedUser = await widget.currencyService.updatePreferredCurrency(code);
      widget.onCurrencyChanged?.call(code);

      // Also update local CurrencyController
      final match = CurrencyController.supportedCurrencies.firstWhere(
        (c) => c.code == code,
        orElse: () => CurrencyInfo(code: code, symbol: code, name: CurrencyFormatter.getName(code), flag: '🌐'),
      );
      await CurrencyController.instance.setCurrency(match);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Display currency updated to $code (${CurrencyFormatter.getName(code)})'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, updatedUser);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _selectedCurrency = widget.currentUser?.preferredCurrency ?? widget.currentCurrency ?? 'PKR';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update currency: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredList = CurrencyFormatter.supportedCurrencies.where((c) {
      final name = CurrencyFormatter.getName(c).toLowerCase();
      final q = _searchFilter.toLowerCase().trim();
      return c.toLowerCase().contains(q) || name.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Display Currency'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Active Currency Highlight Card
                  FintechCard(
                    gradient: AppColors.navyHeroGradient,
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            CurrencyFormatter.getSymbol(_selectedCurrency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Active Display Currency',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_selectedCurrency — ${CurrencyFormatter.getName(_selectedCurrency)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search Filter
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchFilter = val),
                    decoration: InputDecoration(
                      hintText: 'Search currency by name or code...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchFilter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchFilter = '');
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Available Currencies',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All summaries and insights convert to your selected display currency.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Currency Options List
                  FintechCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
                      ),
                      itemBuilder: (context, index) {
                        final code = filteredList[index];
                        final name = CurrencyFormatter.getName(code);
                        final symbol = CurrencyFormatter.getSymbol(code);
                        final isSelected = code == _selectedCurrency;

                        return ListTile(
                          onTap: _isSaving ? null : () => _handleSelectCurrency(code),
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? (isDark ? AppColors.darkPrimarySurface : AppColors.primarySurface)
                                : (isDark ? const Color(0xFF1E2838) : const Color(0xFFF2F4F7)),
                            child: Text(
                              symbol,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                code,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                              : Icon(
                                  Icons.circle_outlined,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  size: 22,
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
