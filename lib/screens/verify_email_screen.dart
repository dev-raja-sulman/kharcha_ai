import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';
import 'package:kharcha_ai/core/network/api_exception.dart';
import 'package:kharcha_ai/screens/main_navigation_screen.dart';
import 'package:kharcha_ai/services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final AuthService authService;
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.authService,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  // 60-second cooldown timer
  int _cooldownSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
    // Auto-focus first digit field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _otpFocusNodes.isNotEmpty) {
        _otpFocusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldownTimer([int seconds = 60]) {
    setState(() => _cooldownSeconds = seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  String get _enteredOtp => _otpControllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    final otp = _enteredOtp.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of your verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = await widget.authService.verifyEmail(
        email: widget.email,
        otp: otp,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email verified! Welcome, ${user.displayName}.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to Main Dashboard as root
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
      setState(() => _errorMessage = 'Verification failed. Please check the code and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendCode() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await widget.authService.resendOtp(
        email: widget.email,
        purpose: 'registration',
      );

      if (!mounted) return;

      final cooldown = (res['cooldown_seconds'] as int?) ?? 60;
      _startCooldownTimer(cooldown);

      setState(() {
        _successMessage = 'A fresh 6-digit verification code has been dispatched to your inbox.';
      });

      // Clear input fields and focus first field
      for (final c in _otpControllers) {
        c.clear();
      }
      if (_otpFocusNodes.isNotEmpty) {
        _otpFocusNodes[0].requestFocus();
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not resend code. Please try again shortly.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      // Support paste of entire 6-digit code
      if (value.length > 1) {
        final cleanDigits = value.replaceAll(RegExp(r'\D'), '');
        for (int i = 0; i < 6 && i < cleanDigits.length; i++) {
          _otpControllers[i].text = cleanDigits[i];
        }
        if (cleanDigits.length >= 6) {
          _otpFocusNodes[5].unfocus();
          _handleVerify();
        } else {
          _otpFocusNodes[cleanDigits.length].requestFocus();
        }
        return;
      }

      // Single digit entered, move to next field
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        if (_enteredOtp.length == 6) {
          _handleVerify();
        }
      }
    } else {
      // Backspace pressed in empty box
      if (index > 0) {
        _otpFocusNodes[index - 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 5),
                  Text(
                    'SECURE VERIFICATION',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Icon Card
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mark_email_read_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header Texts
                  const Text(
                    'Check your inbox',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the 6-digit verification code sent to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // User Email Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined, color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.email,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Success Banner
                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(
                                color: Color(0xFF6EE7B7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 6 Digit PIN Input Fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 56,
                        child: TextFormField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFF111827),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF1F2937), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (val) => _onDigitChanged(index, val),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Expiry hint
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Code expires in 5 minutes',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Verify & Continue Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      disabledBackgroundColor: const Color(0xFF10B981).withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Verify & Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Resend Code with 60s cooldown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive the code? ",
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                      if (_cooldownSeconds > 0)
                        Text(
                          'Resend in ${_cooldownSeconds}s',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _isResending ? null : _handleResendCode,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: _isResending
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                  ),
                                )
                              : const Text(
                                  'Resend Code',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Security Footnote
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFF64748B), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'KharchaAI protects your financial privacy with end-to-end multi-factor authentication. Never share verification codes with anyone.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
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
