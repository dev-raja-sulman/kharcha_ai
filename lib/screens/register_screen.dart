import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/screens/main_navigation_screen.dart';
import 'package:kharcha_ai/screens/verify_email_screen.dart';
import 'package:kharcha_ai/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;

  const RegisterScreen({
    super.key,
    required this.authService,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSocialLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      await widget.authService.register(
        email: email,
        password: _passwordController.text,
        fullName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Please enter the 6-digit verification code sent to your email.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            authService: widget.authService,
            email: email,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'An unexpected error occurred during registration.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialAuth(String provider) async {
    setState(() {
      _isSocialLoading = true;
      _errorMessage = null;
    });

    try {
      final defaultEmail = provider == 'google'
          ? 'google.user@gmail.com'
          : 'apple.user@icloud.com';
      final defaultName = provider == 'google' ? 'Google User' : 'Apple User';

      final user = await widget.authService.socialLogin(
        provider: provider,
        email: defaultEmail,
        name: defaultName,
        token: 'mock_${provider}_token',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${user.displayName}! Signed in with ${provider == 'google' ? 'Google' : 'Apple'}.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            authService: widget.authService,
            initialUser: user,
          ),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Social signup failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Join KharchaAI to optimize your personal financial health.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Full Name
                          const Text(
                            'Full Name (Optional)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration('Raja Sulman', Icons.person_outline_rounded),
                          ),
                          const SizedBox(height: 16),

                          // Email Address
                          const Text(
                            'Email Address',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration('name@example.com', Icons.mail_outline_rounded),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Please enter an email';
                              if (!val.contains('@')) return 'Please enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          const Text(
                            'Password',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration(
                              '••••••••',
                              Icons.lock_outline_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please enter a password';
                              if (val.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password
                          const Text(
                            'Confirm Password',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: _inputDecoration(
                              '••••••••',
                              Icons.lock_reset_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please confirm your password';
                              if (val != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Create Account Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add_alt_1_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 20),

                          // Divider
                          const Row(
                            children: [
                              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR SIGN UP WITH',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Social Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: (_isLoading || _isSocialLoading)
                                      ? null
                                      : () => _handleSocialAuth('google'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'G',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFFEA4335)),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Google',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: (_isLoading || _isSocialLoading)
                                      ? null
                                      : () => _handleSocialAuth('apple'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.apple_rounded, size: 20, color: Color(0xFF0F172A)),
                                      SizedBox(width: 8),
                                      Text(
                                        'Apple',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
      ),
    );
  }
}
