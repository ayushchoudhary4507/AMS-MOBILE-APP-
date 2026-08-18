import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../core/constants/email_config.dart';

class EmailService {
  /// Send Real-Time OTP Email directly to user's Gmail inbox
  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otp,
  }) async {
    final sender = EmailConfig.senderEmail.trim();
    final pass = EmailConfig.appPassword.replaceAll(RegExp(r'\s+'), '').trim();

    if (sender.isEmpty || pass.isEmpty) {
      debugPrint('⚠️ [EmailService] senderEmail or appPassword is not set in EmailConfig.');
      return false;
    }

    try {
      final smtpServer = gmail(sender, pass);

      final message = Message()
        ..from = Address(sender, 'Attendance System')
        ..recipients.add(recipientEmail.trim())
        ..subject = 'Your OTP for Attendance System: $otp'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f3f4f6; margin: 0; padding: 20px; }
    .card { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
    .header { font-size: 22px; font-weight: 700; color: #4F46E5; margin-bottom: 8px; text-align: center; }
    .sub { font-size: 14px; color: #6B7280; text-align: center; margin-bottom: 24px; }
    .otp-box { background: linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%); border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0; }
    .otp-code { font-size: 36px; font-weight: 800; color: #ffffff; letter-spacing: 8px; font-family: monospace; }
    .info { font-size: 13px; color: #4B5563; line-height: 1.6; text-align: center; }
    .footer { font-size: 11px; color: #9CA3AF; text-align: center; margin-top: 24px; border-top: 1px solid #E5E7EB; padding-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">Attendance Management System</div>
    <div class="sub">One-Time Password (OTP) Verification</div>
    <p class="info">Hello,<br>Use the verification code below to reset your password or sign in:</p>
    <div class="otp-box">
      <div class="otp-code">$otp</div>
    </div>
    <p class="info">
      This OTP is valid for <strong>5 minutes</strong>.<br>
      Please do not share this code with anyone for security purposes.
    </p>
    <div class="footer">
      If you did not request this OTP, please ignore this email.<br>
      &copy; ${DateTime.now().year} Attendance Management System. All rights reserved.
    </div>
  </div>
</body>
</html>
'''
        ..text = 'Your OTP for Attendance System is: $otp\n\nThis OTP is valid for 5 minutes. Do not share it with anyone.';

      final sendReport = await send(message, smtpServer);
      debugPrint('✅ [EmailService] OTP email sent successfully to $recipientEmail! Result: $sendReport');
      return true;
    } catch (e) {
      debugPrint('❌ [EmailService] Failed to send OTP email: $e');
      return false;
    }
  }
}
