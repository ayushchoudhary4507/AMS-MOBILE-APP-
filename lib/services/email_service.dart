import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../core/constants/email_config.dart';

class EmailService {
  /// Send Real-Time OTP Email directly to user's Gmail inbox.
  /// Always returns a Future - never throws or crashes the app.
  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otp,
  }) async {
    try {
      final sender = EmailConfig.senderEmail.trim();
      final pass = EmailConfig.appPassword.replaceAll(RegExp(r'\s+'), '').trim();

      if (sender.isEmpty || pass.isEmpty) {
        return false;
      }

      final smtpServer = gmail(sender, pass);

      final message = Message()
        ..from = Address(sender, 'Attendance Management System')
        ..recipients.add(recipientEmail.trim())
        ..subject = 'Your OTP for Attendance System: $otp'
        ..html = _buildHtml(otp)
        ..text =
            'Your OTP for Attendance System is: $otp\n\nThis OTP is valid for 5 minutes. Do not share it with anyone.';

      await send(message, smtpServer);
      return true;
    } catch (_) {
      // Silently fail — never crash the app
      return false;
    }
  }

  static String _buildHtml(String otp) {
    final year = DateTime.now().year;
    return '''<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:Arial,sans-serif;background:#f3f4f6;margin:0;padding:20px;">
  <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:16px;padding:32px;box-shadow:0 4px 12px rgba(0,0,0,0.08);">
    <h2 style="color:#4F46E5;text-align:center;margin-bottom:8px;">Attendance Management System</h2>
    <p style="text-align:center;color:#6B7280;font-size:14px;margin-bottom:24px;">One-Time Password Verification</p>
    <p style="text-align:center;font-size:15px;color:#333;">Use the code below to reset your password:</p>
    <div style="background:linear-gradient(135deg,#4F46E5 0%,#7C3AED 100%);border-radius:12px;padding:20px;text-align:center;margin:24px 0;">
      <div style="font-size:36px;font-weight:800;color:#fff;letter-spacing:8px;font-family:monospace;">$otp</div>
    </div>
    <p style="text-align:center;font-size:13px;color:#4B5563;">Valid for <strong>5 minutes</strong>. Do not share with anyone.</p>
    <p style="text-align:center;font-size:11px;color:#9CA3AF;border-top:1px solid #E5E7EB;padding-top:16px;margin-top:24px;">
      If you did not request this OTP, please ignore this email.<br>&copy; $year Attendance Management System.
    </p>
  </div>
</body>
</html>''';
  }
}
