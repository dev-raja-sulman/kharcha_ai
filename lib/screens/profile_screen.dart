import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/config/api_config.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/core/theme/theme_controller.dart';
import 'package:kharcha_ai/core/utils/currency_formatter.dart';
import 'package:kharcha_ai/models/user_model.dart';
import 'package:kharcha_ai/screens/currency_settings_screen.dart';
import 'package:kharcha_ai/screens/login_screen.dart';
import 'package:kharcha_ai/services/auth_service.dart';
import 'package:kharcha_ai/services/currency_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';
import 'package:kharcha_ai/widgets/fintech_card.dart';
import 'package:kharcha_ai/widgets/skeleton_loader.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService authService;
  final UserModel? initialUser;

  const ProfileScreen({
    super.key,
    required this.authService,
    this.initialUser,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel? _user;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    if (_user == null) {
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await widget.authService.getProfile();
      setState(() {
        _user = user;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load profile details.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of KharchaAI?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(authService: widget.authService),
        ),
        (route) => false,
      );
    }
  }

  void _openCurrencySettings() async {
    if (_user == null) return;
    final currencyService = CurrencyService(apiClient: widget.authService.apiClient);
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => CurrencySettingsScreen(
          currencyService: currencyService,
          currentUser: _user!,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _user = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = _user != null
        ? DateFormat('MMMM dd, yyyy').format(_user!.createdAt)
        : 'Loading...';
    final userCurrency = _user?.preferredCurrency ?? 'PKR';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _fetchProfile,
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _user == null
            ? const Padding(padding: EdgeInsets.all(20), child: SkeletonList(count: 3))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar Header Card
                        FintechCard(
                          padding: const EdgeInsets.all(22),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _user?.displayName ?? 'KharchaAI Member',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified, color: AppColors.primary, size: 16),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _user?.email ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(10)),
                            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // App Preferences Section
                        Text(
                          'Preferences',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FintechCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              // Theme Switch
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                subtitle: Text(
                                  isDark ? 'Dark theme enabled' : 'Light theme enabled',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Switch(
                                  value: isDark,
                                  activeColor: AppColors.primary,
                                  onChanged: (_) => ThemeController.instance.toggleTheme(),
                                ),
                              ),
                              const Divider(height: 1),

                              // Currency Settings
                              ListTile(
                                onTap: _openCurrencySettings,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.successBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.currency_exchange_rounded, color: AppColors.success, size: 20),
                                ),
                                title: const Text('Display Currency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                subtitle: Text(
                                  '$userCurrency (${CurrencyFormatter.getName(userCurrency)})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(Icons.chevron_right, size: 20),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Account Details Section
                        Text(
                          'Account Information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FintechCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildRow('Account ID', '#${_user?.id ?? '—'}', Icons.tag, isDark),
                              const Divider(height: 18),
                              _buildRow('Full Name', _user?.fullName ?? 'Not provided', Icons.person_outline, isDark),
                              const Divider(height: 18),
                              _buildRow('Email', _user?.email ?? '—', Icons.email_outlined, isDark),
                              const Divider(height: 18),
                              _buildRow('Member Since', formattedDate, Icons.calendar_today_outlined, isDark),
                              const Divider(height: 18),
                              _buildRow('Backend Server', ApiConfig.baseUrl, Icons.cloud_done_outlined, isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Logout
                        CustomButton(
                          text: 'Log Out of KharchaAI',
                          icon: Icons.logout_rounded,
                          backgroundColor: AppColors.errorBg,
                          textColor: AppColors.error,
                          onPressed: _handleLogout,
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

  Widget _buildRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
