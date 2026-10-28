import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/models/user_model.dart';
import 'package:kharcha_ai/screens/login_screen.dart';
import 'package:kharcha_ai/services/auth_service.dart';
import 'package:kharcha_ai/widgets/custom_button.dart';

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _user != null
        ? DateFormat('MMMM dd, yyyy').format(_user!.createdAt)
        : 'Loading...';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _isLoading ? null : _fetchProfile,
            tooltip: 'Refresh Profile from API',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _user == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        // Avatar & Header
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 42,
                                backgroundColor: AppColors.primarySurface,
                                child: Text(
                                  _user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _user?.displayName ?? 'KharchaAI User',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _user?.email ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error Banner
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Profile Details Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.cardBorder),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  icon: Icons.tag,
                                  label: 'Account ID',
                                  value: '#${_user?.id ?? '—'}',
                                ),
                                const Divider(height: 1, color: AppColors.cardBorder),
                                _buildInfoRow(
                                  icon: Icons.person_outline,
                                  label: 'Full Name',
                                  value: _user?.fullName ?? 'Not provided',
                                ),
                                const Divider(height: 1, color: AppColors.cardBorder),
                                _buildInfoRow(
                                  icon: Icons.email_outlined,
                                  label: 'Email Address',
                                  value: _user?.email ?? '—',
                                ),
                                const Divider(height: 1, color: AppColors.cardBorder),
                                _buildInfoRow(
                                  icon: Icons.verified_user_outlined,
                                  label: 'Account Status',
                                  value: (_user?.isActive ?? true) ? 'Active' : 'Inactive',
                                  valueColor: (_user?.isActive ?? true) ? AppColors.success : AppColors.error,
                                ),
                                const Divider(height: 1, color: AppColors.cardBorder),
                                _buildInfoRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Member Since',
                                  value: formattedDate,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Logout Button
                        CustomButton(
                          text: 'Log Out',
                          icon: Icons.logout_rounded,
                          backgroundColor: AppColors.errorBg,
                          textColor: AppColors.error,
                          onPressed: _handleLogout,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
