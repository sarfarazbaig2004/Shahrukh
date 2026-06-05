import 'package:firebase_auth/firebase_auth.dart';
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
  bool _rememberMe = true;

  void _toast(String msg, {bool err = false, SnackBarAction? action}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.red : zSuccess,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: err ? 3 : 2),
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

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      // Company isolation must be enforced after login in:
      // 1) auth_wrapper.dart
      // 2) user/company profile fetch
      // 3) Firestore security rules
      // 4) all company-scoped queries
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase login error code: ${e.code}');
      debugPrint('Firebase login error message: ${e.message}');

      final msg = switch (e.code) {
        'invalid-email' => 'Wrong email address.',
        'too-many-requests' =>
          'Too many wrong attempts. Please wait and try again.',
        'user-disabled' => 'This account has been disabled.',
        _ => 'Wrong email address or password.',
      };

      _toast(msg, err: true);
    } catch (e) {
      debugPrint('Login non-Firebase error: $e');
      _toast('Wrong email address or password.', err: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim().toLowerCase();

    if (email.isEmpty) {
      _toast('Enter your work email first', err: true);
      return;
    }

    final emailError = _validateEmail(email);
    if (emailError != null) {
      _toast(emailError, err: true);
      return;
    }

    await _sendPasswordReset(email);
  }

  Future<void> _sendPasswordReset(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      _toast('Enter your work email first', err: true);
      return;
    }

    try {
      debugPrint('Password reset requested for: $normalizedEmail');
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: normalizedEmail,
      );
      _toast('Password reset link sent to $normalizedEmail');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase reset error code: ${e.code}');
      debugPrint('Firebase reset error message: ${e.message}');
      _toast(
        'Firebase Auth: ${e.code} - ${e.message ?? 'Unable to send password reset email.'}',
        err: true,
      );
    } catch (e) {
      debugPrint('Password reset non-Firebase error: $e');
      _toast('Failed: $e', err: true);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: label,
      prefixIcon: Icon(icon, color: zMuted, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: zBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: zBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: zBlue, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      labelStyle: const TextStyle(
        color: zMuted,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: zMuted, fontSize: 13.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final isWide = screen.width > 1120;
    final compactHeight = screen.height < 780;

    return Scaffold(
      backgroundColor: zLoginBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned(
            top: -70,
            left: -50,
            child: _BgGlow(size: 280, color: Color(0x442563EB)),
          ),
          const Positioned(
            bottom: -130,
            right: -40,
            child: _BgGlow(size: 340, color: Color(0x331D4ED8)),
          ),
          const Positioned(
            top: 120,
            right: 140,
            child: _BgGlow(size: 170, color: Color(0x2216A34A)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: isWide ? 28 : 18,
                    right: isWide ? 28 : 18,
                    top: compactHeight ? 14 : 22,
                    bottom: media.viewInsets.bottom + 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight - (compactHeight ? 28 : 42),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (isWide) ...[
                            const Expanded(
                              flex: 6,
                              child: _LoginSideBranding(),
                            ),
                            const SizedBox(width: 28),
                          ],
                          Expanded(
                            flex: isWide ? 5 : 1,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isWide ? 455 : 460,
                                ),
                                child: Container(
                                  padding: EdgeInsets.all(
                                    compactHeight ? 22 : 28,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: zBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.07),
                                        blurRadius: 30,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 54,
                                              height: 54,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                color: zBlueSoft,
                                                border: Border.all(
                                                  color: zBorder,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Image.asset(
                                                  'assets/images/logo.png',
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        Icons.business,
                                                        size: 28,
                                                        color: zBlue,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    kAppName,
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: zText,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Sign in to your ERP workspace',
                                                    style: TextStyle(
                                                      color: zMuted,
                                                      fontSize: 13,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: compactHeight ? 14 : 20,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FBFF),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(color: zBorder),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.verified_user_outlined,
                                                color: zSuccess,
                                                size: 17,
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Secure access with company-level data protection and role-based control',
                                                  style: TextStyle(
                                                    color: zMuted,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          height: compactHeight ? 14 : 20,
                                        ),
                                        TextFormField(
                                          controller: _email,
                                          textInputAction: TextInputAction.next,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          autofillHints: const [
                                            AutofillHints.username,
                                            AutofillHints.email,
                                          ],
                                          validator: _validateEmail,
                                          decoration: _input(
                                            'Work email',
                                            Icons.email_outlined,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        TextFormField(
                                          controller: _pass,
                                          obscureText: _obscure,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          validator: _validatePassword,
                                          onFieldSubmitted: (_) => _login(),
                                          decoration:
                                              _input(
                                                'Password',
                                                Icons.lock_outline,
                                              ).copyWith(
                                                suffixIcon: IconButton(
                                                  onPressed: () {
                                                    setState(
                                                      () =>
                                                          _obscure = !_obscure,
                                                    );
                                                  },
                                                  icon: Icon(
                                                    _obscure
                                                        ? Icons
                                                              .visibility_off_outlined
                                                        : Icons
                                                              .visibility_outlined,
                                                    color: zMuted,
                                                  ),
                                                ),
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _rememberMe,
                                              activeColor: zBlue,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onChanged: (v) {
                                                setState(() {
                                                  _rememberMe = v ?? false;
                                                });
                                              },
                                            ),
                                            const Text(
                                              'Remember me',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: zText,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton(
                                              onPressed: _loading
                                                  ? null
                                                  : _forgot,
                                              child: const Text(
                                                'Forgot password?',
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  color: zBlue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 48,
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: zBlue,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            onPressed: _loading ? null : _login,
                                            child: _loading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Text(
                                                    'Sign In',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 46,
                                          child: OutlinedButton(
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
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFF8FAFC,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              side: const BorderSide(
                                                color: zBorder,
                                              ),
                                            ),
                                            child: const Text(
                                              'Create New ERP Workspace',
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: zText,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          height: compactHeight ? 12 : 16,
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: zBorder,
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                              ),
                                              child: Text(
                                                'or',
                                                style: TextStyle(
                                                  color: zMuted,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: zBorder,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: compactHeight ? 12 : 16,
                                        ),
                                        SizedBox(
                                          height: 46,
                                          child: OutlinedButton.icon(
                                            onPressed: _loading
                                                ? null
                                                : () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const ScreenJoinCompany(),
                                                      ),
                                                    );
                                                  },
                                            icon: const Icon(
                                              Icons.group_add_outlined,
                                              size: 18,
                                              color: zBlue,
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              side: const BorderSide(
                                                color: zBorder,
                                              ),
                                            ),
                                            label: const Text(
                                              'Join Existing Company Workspace',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: zText,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          height: compactHeight ? 12 : 18,
                                        ),
                                        const Text(
                                          'QUIK ERP for operations, sales, customers, inventory, finance and team management',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: zMuted,
                                            fontSize: 12,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BgGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _BgGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
        ),
      ),
    );
  }
}

class _LoginSideBranding extends StatelessWidget {
  const _LoginSideBranding();

  Widget _miniMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color chipColor,
    required Color chipTextColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: chipTextColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.90),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF7FAFF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: zBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: zBlueSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: zBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.business_center_outlined,
                        size: 30,
                        color: zBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kAppName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: zText,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Unified business ERP platform',
                      style: TextStyle(
                        color: zMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Run your business with one secure and connected ERP workspace.',
              style: TextStyle(
                fontSize: 34,
                height: 1.16,
                fontWeight: FontWeight.w900,
                color: zText,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Manage sales, customers, quotations, inventory, users, approvals and day-to-day business operations from one professional SaaS platform.',
              style: TextStyle(
                fontSize: 15,
                height: 1.65,
                color: zMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatPill(icon: Icons.groups_outlined, text: 'Customers'),
                _StatPill(icon: Icons.inventory_2_outlined, text: 'Inventory'),
                _StatPill(
                  icon: Icons.request_quote_outlined,
                  text: 'Quotations',
                ),
                _StatPill(
                  icon: Icons.admin_panel_settings_outlined,
                  text: 'Permissions',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF3B82F6),
                                Color(0xFF1D4ED8),
                                Color(0xFF1E40AF),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: zBlue.withValues(alpha: 0.28),
                                blurRadius: 28,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -18,
                                right: -10,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -26,
                                left: -18,
                                child: Container(
                                  width: 145,
                                  height: 145,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _miniMetricCard(
                                          title: 'Orders',
                                          value: '128',
                                          icon: Icons.shopping_bag_outlined,
                                          chipColor: Colors.white,
                                          chipTextColor: zBlue,
                                        ),
                                        const SizedBox(width: 12),
                                        _miniMetricCard(
                                          title: 'Approved',
                                          value: '24',
                                          icon: Icons.check_circle_outline,
                                          chipColor: zSuccessSoft,
                                          chipTextColor: zSuccess,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Business activity',
                                                    style: TextStyle(
                                                      color: zText,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                                _TagBadge(
                                                  text: '+18%',
                                                  bg: zSuccessSoft,
                                                  fg: zSuccess,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Expanded(
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: const [
                                                  _Bar(h: 42, color: zPurple),
                                                  SizedBox(width: 10),
                                                  _Bar(h: 74, color: zBlue),
                                                  SizedBox(width: 10),
                                                  _Bar(h: 58, color: zOrange),
                                                  SizedBox(width: 10),
                                                  _Bar(h: 98, color: zSuccess),
                                                  SizedBox(width: 10),
                                                  _Bar(h: 70, color: zBlueDeep),
                                                  SizedBox(width: 10),
                                                  _Bar(h: 114, color: zBlue),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: zBlueSoft,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(
                                                    Icons.auto_graph,
                                                    color: zBlue,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Track operations, approvals, quotations and team activity in one place.',
                                                      style: TextStyle(
                                                        color: zText,
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: 86,
                          right: -20,
                          child: _FloatingInfoCard(
                            icon: Icons.domain_verification_outlined,
                            title: '42 New Requests',
                            subtitle: 'This week',
                            bg: Colors.white,
                            accent: zOrange,
                          ),
                        ),
                        const Positioned(
                          bottom: 26,
                          left: -18,
                          child: _FloatingInfoCard(
                            icon: Icons.request_quote_outlined,
                            title: '7 Pending Quotes',
                            subtitle: 'Need action',
                            bg: Colors.white,
                            accent: zSuccess,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _BrandFeatureCard(
                          icon: Icons.shield_outlined,
                          title: 'Company isolation',
                          subtitle:
                              'Each company works inside its own protected data boundary.',
                          tint: zBlueSoft,
                          iconColor: zBlue,
                        ),
                        SizedBox(height: 14),
                        _BrandFeatureCard(
                          icon: Icons.manage_accounts_outlined,
                          title: 'Role permissions',
                          subtitle:
                              'Control admin, manager and user access with clear visibility rules.',
                          tint: zSuccessSoft,
                          iconColor: zSuccess,
                        ),
                        SizedBox(height: 14),
                        _BrandFeatureCard(
                          icon: Icons.approval_outlined,
                          title: 'Connected workflows',
                          subtitle:
                              'Run sales, operations and approvals with one unified ERP experience.',
                          tint: zOrangeSoft,
                          iconColor: zOrange,
                        ),
                      ],
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
}

class _FloatingInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bg;
  final Color accent;

  const _FloatingInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: zBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: zText,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: zMuted,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _TagBadge({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: zBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: zBlue),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: zText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color iconColor;

  const _BrandFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: zBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: zText,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: zMuted,
                height: 1.45,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double h;
  final Color color;

  const _Bar({required this.h, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
