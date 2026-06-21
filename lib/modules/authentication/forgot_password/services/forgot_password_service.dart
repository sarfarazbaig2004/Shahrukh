import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'forgot_password_error_mapper.dart';

class ForgotPasswordException implements Exception {
  const ForgotPasswordException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ForgotPasswordService {
  ForgotPasswordService({FirebaseFunctions? functions, FirebaseAuth? auth})
    : _functions = functions ?? FirebaseFunctions.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  /// No-deploy fallback.
  /// Uses Firebase Auth built-in reset email, so it does not need Cloud Functions deploy.
  Future<void> sendFirebaseResetLink(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      throw const ForgotPasswordException(
        'Please enter a valid email address.',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (e) {
      throw ForgotPasswordException(_firebaseAuthErrorMessage(e));
    } catch (_) {
      throw const ForgotPasswordException(
        'Password reset email could not be sent. Please try again later.',
      );
    }
  }

  /// Custom OTP flow. Requires deployed Cloud Functions.
  Future<void> requestOtp(String email) async {
    try {
      await _functions.httpsCallable('requestPasswordOtp').call({
        'email': email.trim().toLowerCase(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw ForgotPasswordException(
        forgotPasswordErrorMessage(
          e,
          fallback: 'OTP could not be sent. Please try again.',
        ),
      );
    } catch (e) {
      throw ForgotPasswordException(
        forgotPasswordErrorMessage(
          e,
          fallback: 'OTP could not be sent. Please try again.',
        ),
      );
    }
  }

  Future<String> verifyOtp({required String email, required String otp}) async {
    try {
      final result = await _functions.httpsCallable('verifyPasswordOtp').call({
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final token = (data['resetToken'] ?? '').toString();

      if (token.isEmpty) {
        throw const ForgotPasswordException(
          'Password reset session could not be created. Please request a new OTP.',
        );
      }

      return token;
    } on ForgotPasswordException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw ForgotPasswordException(
        forgotPasswordErrorMessage(e, fallback: 'Invalid or expired OTP.'),
      );
    } catch (e) {
      throw ForgotPasswordException(
        forgotPasswordErrorMessage(e, fallback: 'Invalid or expired OTP.'),
      );
    }
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _functions.httpsCallable('resetPasswordWithOtp').call({
        'email': email.trim().toLowerCase(),
        'resetToken': resetToken,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ForgotPasswordException(
        forgotPasswordErrorMessage(
          e,
          fallback: 'Password could not be reset. Please request a new OTP.',
        ),
      );
    } catch (e) {
      throw ForgotPasswordException(
        forgotPasswordErrorMessage(
          e,
          fallback: 'Password could not be reset. Please request a new OTP.',
        ),
      );
    }
  }

  String _firebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'If this email is registered, a password reset link will be sent.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      case 'network-request-failed':
        return 'Network issue. Please check your internet connection.';
      default:
        return 'Password reset email could not be sent. Please try again later.';
    }
  }
}
