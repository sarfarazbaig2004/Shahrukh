import 'package:cloud_functions/cloud_functions.dart';

class ForgotPasswordService {
  ForgotPasswordService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> requestOtp(String email) async {
    await _functions.httpsCallable('requestPasswordOtp').call({
      'email': email.trim().toLowerCase(),
    });
  }

  Future<String> verifyOtp({required String email, required String otp}) async {
    final result = await _functions.httpsCallable('verifyPasswordOtp').call({
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final token = (data['resetToken'] ?? '').toString();

    if (token.isEmpty) {
      throw Exception('Password reset session could not be created.');
    }

    return token;
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _functions.httpsCallable('resetPasswordWithOtp').call({
      'email': email.trim().toLowerCase(),
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }
}
