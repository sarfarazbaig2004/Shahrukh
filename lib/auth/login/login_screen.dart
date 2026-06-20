// lib/auth/login/login_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/auth/register/register_screen_local.dart' as reg;
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/administration/company/screen_join_company.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _loading = false;
  bool _resettingPassword = false;
  bool _rememberMe = true;

  // Added ValueNotifier to sync background image index with marketing caption
  final ValueNotifier<int> _currentSlideIndex = ValueNotifier<int>(0);

  final List<String> _slideCaptions = [
    "Intelligent CRM & Pipeline Workflows",
    "Real-time Enterprise Inventory Tracking",
    "Automated Financial & Invoice Reporting",
    "Streamlined Field Service Management",
    "Advanced Data Analytics & Dashboards",
    "Secure & Scalable Cloud Infrastructure",
  ];

  void _toast(String msg, {bool err = false, SnackBarAction? action}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.red : zSuccess,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Work email is required';

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid work email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final pass = value ?? '';
    if (pass.isEmpty) return 'Password is required';
    if (pass.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _toast('Please correct the highlighted fields', err: true);
      return;
    }

    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text;

    debugPrint('Login attempt email: $email');
    debugPrint('Login attempt password length: ${pass.length}');

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // Company isolation must be enforced after login in:
      // 1) auth_wrapper.dart
      // 2) user/company profile fetch
      // 3) Firestore security rules
      // 4) all company-scoped queries
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase login error code: ${e.code}');
      debugPrint('Firebase login error message: ${e.message}');

      final msg = switch (e.code) {
        'user-not-found' =>
          'Firebase Auth: user-not-found - No account found for this email.',
        'wrong-password' =>
          'Firebase Auth: wrong-password - Incorrect password.',
        'invalid-email' =>
          'Firebase Auth: invalid-email - Invalid email format.',
        'invalid-credential' =>
          'Firebase Auth: invalid-credential - Invalid email or password.',
        'user-disabled' =>
          'Firebase Auth: user-disabled - This account has been disabled.',
        'too-many-requests' =>
          'Firebase Auth: too-many-requests - Too many attempts. Please wait and try again.',
        _ => 'Firebase Auth: ${e.code} - ${e.message ?? 'Sign in failed.'}',
      };
      _toast(
        msg,
        err: true,
        action: SnackBarAction(
          label: 'Reset password',
          textColor: Colors.white,
          onPressed: () => _sendPasswordReset(email),
        ),
      );
    } catch (e) {
      debugPrint('Login non-Firebase error: $e');
      _toast('Sign in failed: $e', err: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgot() async {
    await _openForgotPasswordDialog();
  }

  Future<void> _openForgotPasswordDialog({String? initialEmail}) async {
    final resetEmailController = TextEditingController(
      text: (initialEmail ?? _email.text).trim().toLowerCase(),
    );
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    int step = 0;
    bool isSending = false;
    String? errorMessage;
    String? infoMessage;
    String verifiedEmail = '';
    String resetToken = '';

    Future<void> requestOtp(StateSetter setDialogState) async {
      final normalizedEmail = resetEmailController.text.trim().toLowerCase();
      final emailError = _validateEmail(normalizedEmail);

      if (emailError != null) {
        setDialogState(() {
          errorMessage = emailError;
          infoMessage = null;
        });
        return;
      }

      setDialogState(() {
        isSending = true;
        errorMessage = null;
        infoMessage = null;
      });

      try {
        await FirebaseFunctions.instance
            .httpsCallable('requestPasswordOtp')
            .call({'email': normalizedEmail});

        verifiedEmail = normalizedEmail;

        setDialogState(() {
          step = 1;
          infoMessage =
              'OTP sent to $normalizedEmail. Please check inbox and spam.';
        });
      } on FirebaseFunctionsException catch (e) {
        debugPrint('requestPasswordOtp error: ${e.code} ${e.message}');
        setDialogState(() {
          errorMessage = e.message ?? 'OTP could not be sent.';
        });
      } catch (e) {
        debugPrint('requestPasswordOtp non-Firebase error: $e');
        setDialogState(() {
          errorMessage = 'OTP could not be sent. Please try again.';
        });
      } finally {
        setDialogState(() {
          isSending = false;
        });
      }
    }

    Future<void> verifyOtp(StateSetter setDialogState) async {
      final otp = otpController.text.trim();

      if (otp.length != 6) {
        setDialogState(() {
          errorMessage = 'Enter the 6 digit OTP.';
          infoMessage = null;
        });
        return;
      }

      setDialogState(() {
        isSending = true;
        errorMessage = null;
        infoMessage = null;
      });

      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('verifyPasswordOtp')
            .call({'email': verifiedEmail, 'otp': otp});

        final data = Map<String, dynamic>.from(result.data as Map);
        resetToken = (data['resetToken'] ?? '').toString();

        if (resetToken.isEmpty) {
          throw Exception('Reset token missing.');
        }

        setDialogState(() {
          step = 2;
          infoMessage = 'OTP verified. Create your new password.';
        });
      } on FirebaseFunctionsException catch (e) {
        debugPrint('verifyPasswordOtp error: ${e.code} ${e.message}');
        setDialogState(() {
          errorMessage = e.message ?? 'Invalid or expired OTP.';
        });
      } catch (e) {
        debugPrint('verifyPasswordOtp non-Firebase error: $e');
        setDialogState(() {
          errorMessage = 'Invalid or expired OTP.';
        });
      } finally {
        setDialogState(() {
          isSending = false;
        });
      }
    }

    Future<void> updatePassword(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      final newPassword = newPasswordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();

      if (newPassword.length < 6) {
        setDialogState(() {
          errorMessage = 'Password must be at least 6 characters.';
          infoMessage = null;
        });
        return;
      }

      if (newPassword != confirmPassword) {
        setDialogState(() {
          errorMessage = 'New password and confirm password do not match.';
          infoMessage = null;
        });
        return;
      }

      setDialogState(() {
        isSending = true;
        errorMessage = null;
        infoMessage = null;
      });

      try {
        await FirebaseFunctions.instance
            .httpsCallable('resetPasswordWithOtp')
            .call({
              'email': verifiedEmail,
              'resetToken': resetToken,
              'newPassword': newPassword,
            });

        if (!dialogContext.mounted) return;
        Navigator.pop(dialogContext, true);
      } on FirebaseFunctionsException catch (e) {
        debugPrint('resetPasswordWithOtp error: ${e.code} ${e.message}');
        setDialogState(() {
          errorMessage = e.message ?? 'Password could not be updated.';
        });
      } catch (e) {
        debugPrint('resetPasswordWithOtp non-Firebase error: $e');
        setDialogState(() {
          errorMessage = 'Password could not be updated. Please try again.';
        });
      } finally {
        setDialogState(() {
          isSending = false;
        });
      }
    }

    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSending,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final title = step == 0
                ? 'Forgot Password'
                : step == 1
                ? 'Verify OTP'
                : 'Create New Password';

            final primaryLabel = step == 0
                ? 'Send OTP'
                : step == 1
                ? 'Verify OTP'
                : 'Update Password';

            Widget content;

            if (step == 0) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your registered work email. A 6 digit OTP will be sent to your email.',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    enabled: !isSending,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => requestOtp(setDialogState),
                    decoration: InputDecoration(
                      labelText: 'Work Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              );
            } else if (step == 1) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the 6 digit OTP sent to $verifiedEmail.',
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    enabled: !isSending,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => verifyOtp(setDialogState),
                    decoration: InputDecoration(
                      labelText: 'OTP',
                      counterText: '',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a new password for your ERP account.',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    enabled: !isSending,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    enabled: !isSending,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        updatePassword(dialogContext, setDialogState),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  if (infoMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      infoMessage!,
                      style: const TextStyle(
                        color: zSuccess,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () {
                          if (step == 0) {
                            Navigator.pop(dialogContext, false);
                            return;
                          }

                          setDialogState(() {
                            step -= 1;
                            errorMessage = null;
                            infoMessage = null;
                          });
                        },
                  child: Text(step == 0 ? 'Cancel' : 'Back'),
                ),
                FilledButton.icon(
                  onPressed: isSending
                      ? null
                      : () {
                          if (step == 0) {
                            requestOtp(setDialogState);
                          } else if (step == 1) {
                            verifyOtp(setDialogState);
                          } else {
                            updatePassword(dialogContext, setDialogState);
                          }
                        },
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          step == 0
                              ? Icons.mark_email_read_outlined
                              : step == 1
                              ? Icons.verified_user_outlined
                              : Icons.lock_reset_outlined,
                        ),
                  label: Text(isSending ? 'Please wait...' : primaryLabel),
                ),
              ],
            );
          },
        );
      },
    );

    resetEmailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    if (completed == true) {
      _toast('Password updated successfully. Please login with new password.');
    }
  }

  Future<bool> _sendPasswordReset(
    String email, {
    bool showSuccessToast = true,
  }) async {
    if (!showSuccessToast) {
      debugPrint('Opening password OTP reset without success toast.');
    }

    if (mounted) setState(() => _resettingPassword = true);

    try {
      await _openForgotPasswordDialog(initialEmail: email);
      return true;
    } finally {
      if (mounted) setState(() => _resettingPassword = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _currentSlideIndex.dispose();
    super.dispose();
  }

  // Updated Minimalist Input
  InputDecoration _input(String placeholder) {
    return InputDecoration(
      hintText: placeholder,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: zBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildModuleBadge(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildMarketingSection(bool isWide) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 60.0 : 24.0,
        vertical: 40.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Branding Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.business, size: 24, color: zBlue),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUIK ERP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Modern Business Management Platform',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isWide ? 80 : 40),

          // Headline
          const Text(
            'Run Your Entire\nBusiness From\nOne Platform',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Subheadline
          Text(
            'CRM, Inventory, Finance, Service Management and Analytics in one connected workspace.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 18,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),

          // Module Badges
          Wrap(
            children: [
              _buildModuleBadge('CRM'),
              _buildModuleBadge('Inventory'),
              _buildModuleBadge('Finance'),
              _buildModuleBadge('Service'),
              _buildModuleBadge('Analytics'),
            ],
          ),

          if (isWide) const Spacer(),
          if (!isWide) const SizedBox(height: 40),

          // Slide-specific Dynamic Caption
          ValueListenableBuilder<int>(
            valueListenable: _currentSlideIndex,
            builder: (context, index, child) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Row(
                  key: ValueKey(index),
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: zBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _slideCaptions[index % _slideCaptions.length],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your credentials to access your workspace.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 32),

                // Email Field
                TextFormField(
                  controller: _email,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  validator: _validateEmail,
                  decoration: _input('name@company.com'),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _pass,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _login(),
                  decoration: _input('Password').copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscure = !_obscure);
                      },
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Remember Me & Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 18,
                          width: 18,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: zBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            onChanged: (v) {
                              setState(() {
                                _rememberMe = v ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: (_loading || _resettingPassword)
                          ? null
                          : _forgot,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Sign In Action (Primary)
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A), // Premium Dark
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // Secondary Links
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const reg.RegisterScreenLocal(),
                                ),
                              );
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Create Workspace',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: zBlue,
                        ),
                      ),
                    ),
                    const Text(
                      '·',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ScreenJoinCompany(),
                                ),
                              );
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Join Company',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: zBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Full Screen Hero Carousel Background
          Positioned.fill(
            child: _LoginHeroCarousel(
              onSlideChanged: (index) {
                _currentSlideIndex.value = index;
              },
            ),
          ),

          // 2. Main Content Layer
          Positioned.fill(
            child: SafeArea(
              child: isWide
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: _buildMarketingSection(true)),
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(40),
                              child: _buildLoginCard(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight:
                              media.size.height -
                              media.padding.top -
                              media.padding.bottom,
                        ),
                        padding: EdgeInsets.only(
                          bottom: media.viewInsets.bottom > 0
                              ? media.viewInsets.bottom + 20
                              : 40,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildMarketingSection(false),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: _buildLoginCard(),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeroCarousel extends StatefulWidget {
  final ValueChanged<int> onSlideChanged;

  const _LoginHeroCarousel({required this.onSlideChanged});

  @override
  State<_LoginHeroCarousel> createState() => _LoginHeroCarouselState();
}

class _LoginHeroCarouselState extends State<_LoginHeroCarousel> {
  final List<String> _images = [
    'assets/images/login_hero_1.png',
    'assets/images/login_hero_2.png',
    'assets/images/login_hero_3.png',
    'assets/images/login_hero_4.png',
    'assets/images/login_hero_5.png',
    'assets/images/login_hero_6.png',
  ];

  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _images.length;
        });
        widget.onSlideChanged(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full screen fading images
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 1500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Image.asset(
            _images[_currentIndex],
            key: ValueKey<int>(_currentIndex),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: const Color(0xFF0F172A)); // Dark fallback
            },
          ),
        ),
        // Dark gradient scrim for optimal text & glassmorphism contrast
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.40),
                Colors.black.withValues(alpha: 0.20),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
