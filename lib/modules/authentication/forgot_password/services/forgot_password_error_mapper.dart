import 'package:cloud_functions/cloud_functions.dart';

String forgotPasswordErrorMessage(Object error, {required String fallback}) {
  if (error is FirebaseFunctionsException) {
    final code = error.code.trim();
    final message = (error.message ?? '').trim();

    if (message.isNotEmpty &&
        message.toLowerCase() != 'internal' &&
        message.toLowerCase() != code.toLowerCase()) {
      return message;
    }

    switch (code) {
      case 'invalid-argument':
        return 'Please enter a valid registered email address.';
      case 'failed-precondition':
        return 'Invalid or expired OTP. Please request a new OTP and try again.';
      case 'not-found':
        return 'Password reset service is not deployed yet. Please deploy Firebase Functions first.';
      case 'permission-denied':
        return 'Password reset service permission is denied. Please check Firebase Function permissions.';
      case 'unavailable':
        return 'Password reset service is temporarily unavailable. Please try again.';
      case 'internal':
        return 'OTP could not be sent because the password reset service is not active or email service failed. Please deploy the latest Firebase Functions and check Gmail secrets.';
      default:
        return fallback;
    }
  }

  final text = error.toString().replaceFirst('Exception: ', '').trim();
  if (text.isNotEmpty && text.toLowerCase() != 'internal') {
    return text;
  }

  return fallback;
}
