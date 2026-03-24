# Quickstart Guide: Email Verification and Password Recovery

**Feature**: `015-email-verification-recovery` | **Date**: March 11, 2026

## For Backend Developers

### 1. Set Up Database Migrations

Run migrations in order to create required tables:

```bash
cd backend
dart run migrations/007_create_verification_tokens_table.dart
dart run migrations/008_create_password_reset_tokens_table.dart
dart run migrations/009_create_password_reset_attempts_table.dart
dart run migrations/010_add_verified_at_to_users.dart
```

Or automatically via Docker:
```bash
docker-compose up --build
# Migrations run automatically on startup (if configured in entrypoint)
```

Verify tables created:
```bash
docker exec mobile-messenger-db psql -U messenger_user -d messenger_db -c "\dt"
# Output should show: verification_tokens, password_reset_tokens, password_reset_attempts tables
```

### 2. Set Up Email Service

Configure SendGrid or SMTP provider via environment variables:

**`.env` (Backend root directory)**:
```env
# ========== Email Service Configuration ==========
EMAIL_PROVIDER=sendgrid  # Options: 'sendgrid' or 'smtp'

# SendGrid Configuration (if EMAIL_PROVIDER=sendgrid)
SENDGRID_API_KEY=sg_test_key_here_...
SENDGRID_FROM_EMAIL=noreply@messenger.example.com

# OR SMTP Configuration (if EMAIL_PROVIDER=smtp)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password  # NOT your regular password—use app password
SMTP_FROM_EMAIL=noreply@messenger.example.com

# ========== Token Configuration ==========
TOKEN_EXPIRATION_HOURS=24
TOKEN_LENGTH_BYTES=32  # 256-bit = 32 bytes
PASSWORD_RESET_MAX_ATTEMPTS_PER_HOUR=5
PASSWORD_RESET_ATTEMPT_WINDOW_MINUTES=60

# ========== Backend & Frontend URLs ==========
BACKEND_URL=http://localhost:8081
FRONTEND_URL=http://localhost:8080

# ========== Timezone ==========
TZ=UTC  # CRITICAL: All timestamps must be in UTC
```

**For SendGrid**:
1. Sign up at sendgrid.com (free tier available)
2. Create API key: Settings → API Keys → Generate
3. Copy key to `SENDGRID_API_KEY`

**For Gmail/SMTP**:
1. Enable 2-factor authentication on Gmail
2. Generate app password: Account → Security → App passwords
3. Copy password to `SMTP_PASSWORD` (NOT your Gmail password)

### 3. Implement Backend Services

#### 3a. TokenService

**File**: `backend/lib/src/services/token_service.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/random/secure_random.dart';

class TokenService {
  /// Generate a cryptographically secure random token (32 bytes = 256-bit entropy)
  static String generateToken({int lengthBytes = 32}) {
    final secureRandom = SecureRandom('Fortuna')..seed(KeyParameter(_getRandomBytes(32)));
    final values = secureRandom.nextBytes(lengthBytes);
    
    // Base64URL encode and remove padding (RFC 4648)
    return base64Url.encode(values).replaceAll('=', '');
  }
  
  /// Helper to get initial random bytes for seeding
  static List<int> _getRandomBytes(int count) {
    final random = Random.secure();
    return List<int>.generate(count, (i) => random.nextInt(256));
  }
  
  /// Hash token using SHA256
  static String hashToken(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }
  
  /// Timing-safe token comparison (prevents timing attacks)
  static bool verifyTokenHash(String token, String storedHash) {
    final hash = hashToken(token);
    
    // Ensure both strings same length before comparison
    if (hash.length != storedHash.length) {
      // Still compare for consistent timing
      int result = hash.length ^ storedHash.length;
      return false; // Different lengths = mismatch
    }
    
    // Timing-safe comparison: check all characters even if mismatch found early
    int result = 0;
    for (int i = 0; i < hash.length; i++) {
      result |= hash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    
    return result == 0;
  }
  
  /// Check if token expired
  static bool isTokenExpired(DateTime expiresAt) {
    return DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  }
}
```

**Unit Tests**:
```dart
import 'package:test/test.dart';

void main() {
  group('TokenService', () {
    test('generateToken produces valid Base64URL string', () {
      final token = TokenService.generateToken();
      
      // Should be 44 chars (32 bytes * 4/3 = 42.67, rounded to 44 with padding removed)
      expect(token.length, 44);
      
      // Should only contain Base64URL chars (no +, /, or =)
      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]*$')));
    });
    
    test('generateToken produces different tokens', () {
      final token1 = TokenService.generateToken();
      final token2 = TokenService.generateToken();
      expect(token1, isNot(token2));
    });
    
    test('hashToken produces consistent hash', () {
      final token = 'test-token';
      final hash1 = TokenService.hashToken(token);
      final hash2 = TokenService.hashToken(token);
      expect(hash1, equals(hash2));
    });
    
    test('verifyTokenHash accepts correct token', () {
      final token = TokenService.generateToken();
      final hash = TokenService.hashToken(token);
      expect(TokenService.verifyTokenHash(token, hash), isTrue);
    });
    
    test('verifyTokenHash rejects incorrect token', () {
      final token = TokenService.generateToken();
      final hash = TokenService.hashToken(token);
      expect(TokenService.verifyTokenHash('wrong-token', hash), isFalse);
    });
    
    test('isTokenExpired detects expired token', () {
      final expiresAt = DateTime.now().subtract(Duration(hours: 25));
      expect(TokenService.isTokenExpired(expiresAt), isTrue);
    });
    
    test('isTokenExpired accepts valid token', () {
      final expiresAt = DateTime.now().add(Duration(hours: 1));
      expect(TokenService.isTokenExpired(expiresAt), isFalse);
    });
  });
}
```

#### 3b. EmailService

**File**: `backend/lib/src/services/email_service.dart`

```dart
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  final String provider;
  final String fromEmail;
  final String? sendgridApiKey;
  final String? smtpHost;
  final int? smtpPort;
  final String? smtpUser;
  final String? smtpPassword;
  final String frontendUrl;

  EmailService({
    required this.provider,
    required this.fromEmail,
    required this.frontendUrl,
    this.sendgridApiKey,
    this.smtpHost,
    this.smtpPort,
    this.smtpUser,
    this.smtpPassword,
  });

  /// Send verification email
  Future<bool> sendVerificationEmail({
    required String email,
    required String username,
    required String token,
  }) async {
    try {
      final verificationLink = '$frontendUrl/verify-email?token=$token';
      final subject = 'Verify Your Mobile Messenger Account';
      final htmlBody = _buildVerificationEmailHtml(username, verificationLink);
      final textBody = _buildVerificationEmailText(username, verificationLink);
      
      return await _sendEmail(
        to: email,
        subject: subject,
        htmlBody: htmlBody,
        textBody: textBody,
      );
    } catch (e) {
      print('ERROR: Failed to send verification email: $e');
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail({
    required String email,
    required String username,
    required String token,
  }) async {
    try {
      final resetLink = '$frontendUrl/reset-password?token=$token';
      final subject = 'Reset Your Mobile Messenger Password';
      final htmlBody = _buildPasswordResetEmailHtml(username, resetLink);
      final textBody = _buildPasswordResetEmailText(username, resetLink);
      
      return await _sendEmail(
        to: email,
        subject: subject,
        htmlBody: htmlBody,
        textBody: textBody,
      );
    } catch (e) {
      print('ERROR: Failed to send password reset email: $e');
      return false;
    }
  }

  /// Internal email sending implementation
  Future<bool> _sendEmail({
    required String to,
    required String subject,
    required String htmlBody,
    required String textBody,
  }) async {
    if (provider == 'sendgrid') {
      return await _sendViaSendGrid(to, subject, htmlBody, textBody);
    } else if (provider == 'smtp') {
      return await _sendViaSMTP(to, subject, htmlBody, textBody);
    }
    return false;
  }

  /// SendGrid implementation
  Future<bool> _sendViaSendGrid(
    String to,
    String subject,
    String htmlBody,
    String textBody,
  ) async {
    // In production, use sendgrid HTTP API
    // This is a placeholder—implement actual SendGrid integration
    // See: https://pub.dev/packages/sendgrid
    print('SENDGRID: Send email to $to');
    return true;
  }

  /// SMTP implementation
  Future<bool> _sendViaSMTP(
    String to,
    String subject,
    String htmlBody,
    String textBody,
  ) async {
    try {
      final smtpServer = gmail(smtpUser!, smtpPassword!);
      
      final message = Message()
        ..from = Address(fromEmail)
        ..recipients.add(to)
        ..subject = subject
        ..html = htmlBody
        ..text = textBody;

      await send(message, smtpServer);
      print('SMTP: Email sent to $to');
      return true;
    } catch (e) {
      print('SMTP ERROR: $e');
      return false;
    }
  }

  /// Build HTML email body for verification
  String _buildVerificationEmailHtml(String username, String link) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #007bff; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
    .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; border-radius: 0 0 5px 5px; }
    .button { display: inline-block; background-color: #007bff; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Mobile Messenger</h1>
    </div>
    <div class="content">
      <p>Hi \$username,</p>
      <p>Thank you for signing up! To complete your registration, please verify your email address.</p>
      <p>This link expires in 24 hours.</p>
      <center>
        <a href="\$link" class="button">Verify Email</a>
      </center>
      <p>Or copy and paste this link:</p>
      <p style="word-break: break-all;"><a href="\$link">\$link</a></p>
      <p>If you didn't create this account, please ignore this email.</p>
    </div>
    <div class="footer">
      <p>&copy; 2026 Mobile Messenger. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
    '''.replaceAll('\$username', username).replaceAll('\$link', link);
  }

  /// Build plain text email body for verification
  String _buildVerificationEmailText(String username, String link) {
    return '''
Mobile Messenger - Verify Your Email

Hi \$username,

Thank you for signing up! To complete your registration, please verify your email address.

Click this link to verify: \$link

This link expires in 24 hours.

If you didn't create this account, please ignore this email.

---
Mobile Messenger Team
    '''.replaceAll('\$username', username).replaceAll('\$link', link);
  }

  /// Build HTML email body for password reset
  String _buildPasswordResetEmailHtml(String username, String link) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #dc3545; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
    .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; border-radius: 0 0 5px 5px; }
    .button { display: inline-block; background-color: #dc3545; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Password Reset Request</h1>
    </div>
    <div class="content">
      <p>Hi \$username,</p>
      <p>We received a request to reset your password. Click the button below to create a new password.</p>
      <p>This link expires in 24 hours.</p>
      <center>
        <a href="\$link" class="button">Reset Password</a>
      </center>
      <p>Or copy and paste this link:</p>
      <p style="word-break: break-all;"><a href="\$link">\$link</a></p>
      <p>If you didn't request this password reset, please ignore this email or contact support.</p>
    </div>
    <div class="footer">
      <p>&copy; 2026 Mobile Messenger. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
    '''.replaceAll('\$username', username).replaceAll('\$link', link);
  }

  /// Build plain text email body for password reset
  String _buildPasswordResetEmailText(String username, String link) {
    return '''
Mobile Messenger - Reset Your Password

Hi \$username,

We received a request to reset your password. Click the link below to create a new password.

\$link

This link expires in 24 hours.

If you didn't request this password reset, please ignore this email or contact support.

---
Mobile Messenger Team
    '''.replaceAll('\$username', username).replaceAll('\$link', link);
  }
}
```

#### 3c. RateLimitService

**File**: `backend/lib/src/services/rate_limit_service.dart`

```dart
import 'package:postgres/postgres.dart';

class RateLimitService {
  final Connection db;
  final int maxAttempts;
  final int windowMinutes;

  RateLimitService({
    required this.db,
    this.maxAttempts = 5,
    this.windowMinutes = 60,
  });

  /// Check if email has exceeded rate limit
  /// Returns: { 'allowed': bool, 'remainingSeconds': int }
  Future<Map<String, dynamic>> checkRateLimit(String email) async {
    final result = await db.query(
      '''
      SELECT COUNT(*) as count, 
             MIN(attempted_at) as oldest_attempt
      FROM password_reset_attempts
      WHERE email = \$1 AND attempted_at > NOW() - INTERVAL '\$2 minutes'
      ''',
      parameters: [email.toLowerCase(), windowMinutes],
    );

    final count = result.isNotEmpty ? result.first['count'] as int : 0;
    
    if (count < maxAttempts) {
      // Under limit, allowed
      return {'allowed': true, 'remainingSeconds': 0};
    } else {
      // Exceeded limit, calculate when they can retry
      final oldestAttempt = result.isNotEmpty ? result.first['oldest_attempt'] as DateTime : DateTime.now();
      final retryTime = oldestAttempt.add(Duration(minutes: windowMinutes));
      final secondsUntilRetry = retryTime.difference(DateTime.now().toUtc()).inSeconds;
      
      return {
        'allowed': false,
        'remainingSeconds': max(0, secondsUntilRetry),
      };
    }
  }

  /// Record a password reset attempt
  Future<void> recordAttempt(String email) async {
    await db.query(
      '''
      INSERT INTO password_reset_attempts (email, attempted_at)
      VALUES (\$1, NOW())
      ''',
      parameters: [email.toLowerCase()],
    );
  }

  /// Clear rate limit for email after successful reset
  Future<void> clearAttempts(String email) async {
    await db.query(
      '''
      DELETE FROM password_reset_attempts
      WHERE email = \$1
      ''',
      parameters: [email.toLowerCase()],
    );
  }

  /// Cleanup old attempts (called by scheduled job, hourly)
  static Future<void> cleanupOldAttempts(Connection db) async {
    final result = await db.query(
      '''
      DELETE FROM password_reset_attempts
      WHERE attempted_at < NOW() - INTERVAL '1 day'
      ''',
    );
    print('✓ Cleaned up old password reset attempts');
  }
}
```

### 4. Create API Endpoint Handlers

#### 4a. Send Verification Email Handler

**File**: `backend/lib/src/handlers/send_verification_handler.dart`

```dart
import 'package:shelf/shelf.dart';

Future<Response> sendVerificationEmailHandler(
  Request request,
  VerificationService verificationService,
) async {
  try {
    // Get JWT from header
    final userId = request.context['user_id'] as String?;
    if (userId == null) {
      return Response(401, body: jsonEncode({'success': false, 'error': 'Unauthorized'}));
    }

    // Send verification email
    final success = await verificationService.sendVerificationEmail(userId);
    if (!success) {
      return Response(500, body: jsonEncode({'success': false, 'error': 'Failed to send email'}));
    }

    return Response(200, body: jsonEncode({
      'success': true,
      'message': 'Verification email sent',
      'resend_after_seconds': 60,
    }));
  } catch (e) {
    return Response(500, body: jsonEncode({'success': false, 'error': 'Server error'}));
  }
}
```

#### 4b. Verify Email Handler

**File**: `backend/lib/src/handlers/verify_email_handler.dart`

```dart
import 'package:shelf/shelf.dart';

Future<Response> verifyEmailHandler(
  Request request,
  VerificationService verificationService,
) async {
  try {
    final body = jsonDecode(await request.readAsString()) as Map;
    final token = body['token'] as String?;
    
    if (token == null || token.isEmpty) {
      return Response(400, body: jsonEncode({'success': false, 'error': 'Token required'}));
    }

    // Verify token and update user
    final user = await verificationService.verifyEmail(token);

    return Response(200, body: jsonEncode({
      'success': true,
      'message': 'Email verified successfully',
      'user': {
        'id': user.id,
        'email': user.email,
        'email_verified': true,
      },
    }));
  } on VerificationException catch (e) {
    return Response(400, body: jsonEncode({
      'success': false,
      'error': e.message,
    }));
  } catch (e) {
    return Response(500, body: jsonEncode({'success': false, 'error': 'Server error'}));
  }
}
```

#### 4c. Send Password Reset Email Handler

**File**: `backend/lib/src/handlers/send_password_reset_handler.dart`

```dart
import 'package:shelf/shelf.dart';

Future<Response> sendPasswordResetEmailHandler(
  Request request,
  PasswordResetService passwordResetService,
  RateLimitService rateLimitService,
) async {
  try {
    final body = jsonDecode(await request.readAsString()) as Map;
    final email = body['email'] as String??;
    
    if (email == null || email.isEmpty) {
      return Response(400, body: jsonEncode({'success': false, 'error': 'Email required'}));
    }

    // Check rate limit
    final rateLimit = await rateLimitService.checkRateLimit(email);
    if (!rateLimit['allowed']) {
      return Response(429, headers: {
        'Retry-After': rateLimit['remainingSeconds'].toString(),
      }, body: jsonEncode({
        'success': false,
        'error': 'Too many password reset requests. Try again in ${(rateLimit['remainingSeconds'] / 60).ceil()} minutes.',
        'retry_after_seconds': rateLimit['remainingSeconds'],
      }));
    }

    // Record attempt
    await rateLimitService.recordAttempt(email);

    // Send reset email (if user exists) without revealing whether email registered
    await passwordResetService.sendPasswordResetEmail(email);

    // Always return same response (user enumeration prevention)
    return Response(200, body: jsonEncode({
      'success': true,
      'message': 'If email is registered, password reset link will be sent',
    }));
  } catch (e) {
    return Response(500, body: jsonEncode({'success': false, 'error': 'Server error'}));
  }
}
```

#### 4d. Reset Password Handler

**File**: `backend/lib/src/handlers/reset_password_handler.dart`

```dart
import 'package:shelf/shelf.dart';

Future<Response> resetPasswordHandler(
  Request request,
  PasswordResetService passwordResetService,
) async {
  try {
    final body = jsonDecode(await request.readAsString()) as Map;
    final token = body['token'] as String?;
    final newPassword = body['new_password'] as String?;
    final confirmPassword = body['confirm_password'] as String?;

    if (token == null || newPassword == null || confirmPassword == null) {
      return Response(400, body: jsonEncode({'success': false, 'error': 'Missing fields'}));
    }

    if (newPassword != confirmPassword) {
      return Response(400, body: jsonEncode({
        'success': false,
        'error': 'Passwords do not match',
      }));
    }

    // Reset password
    final user = await passwordResetService.resetPassword(token, newPassword);

    return Response(200, body: jsonEncode({
      'success': true,
      'message': 'Password reset successfully. Please log in with your new password.',
      'user': {
        'id': user.id,
        'email': user.email,
      },
    }));
  } on PasswordResetException catch (e) {
    return Response(400, body: jsonEncode({
      'success': false,
      'error': e.message,
      'validation_details': e.validationDetails,
    }));
  } catch (e) {
    return Response(500, body: jsonEncode({'success': false, 'error': 'Server error'}));
  }
}
```

---

## For Frontend Developers

### 1. Configure Deep Linking

#### Android Configuration

**File**: `frontend/android/app/src/main/AndroidManifest.xml`

Add intent filter to MainActivity:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="messenger" android:host="verify" />
    <data android:scheme="messenger" android:host="reset" />
</intent-filter>
```

#### iOS Configuration

**File**: `frontend/ios/Runner/Info.plist`

Add URL scheme configuration:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>messenger</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>messenger</string>
        </array>
    </dict>
</array>
```

### 2. Implement Deep Link Handler

**File**: `frontend/lib/core/routing/deep_link_handler.dart`

```dart
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

class DeepLinkHandler {
  static final AppLinks _appLinks = AppLinks();

  static void setupDeepLinkListener(BuildContext context) {
    _appLinks.uriLinkStream.listen((Uri link) {
      _handleDeepLink(context, link);
    });
  }

  static Future<void> _handleDeepLink(BuildContext context, Uri link) async {
    if (link.scheme != 'messenger') return;

    if (link.host == 'verify') {
      final token = link.queryParameters['token'];
      if (token != null) {
        Navigator.pushNamed(
          context,
          '/email-verification',
          arguments: {'token': token},
        );
      }
    } else if (link.host == 'reset') {
      final token = link.queryParameters['token'];
      if (token != null) {
        Navigator.pushNamed(
          context,
          '/password-reset',
          arguments: {'token': token},
        );
      }
    }
  }
}
```

### 3. Implement Frontend Services

#### 3a. Email Verification Service

**File**: `frontend/lib/features/email_verification/services/email_verification_service.dart`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailVerificationService {
  final String baseUrl;
  final String token;  // JWT from login

  EmailVerificationService({required this.baseUrl, required this.token});

  /// Send verification email
  Future<void> sendVerificationEmail(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-verification-email'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send verification email');
    }
  }

  /// Verify email with token
  Future<Map<String, dynamic>> verifyEmail(String verificationToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': verificationToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data as Map<String, dynamic>;
    } else if (response.statusCode == 400) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Verification failed');
    } else {
      throw Exception('Server error during verification');
    }
  }
}
```

#### 3b. Password Recovery Service

**File**: `frontend/lib/features/password_recovery/services/password_recovery_service.dart`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class PasswordRecoveryService {
  final String baseUrl;

  PasswordRecoveryService({required this.baseUrl});

  /// Request password reset email
  Future<void> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-password-reset-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 429) {
      final data = jsonDecode(response.body);
      throw RateLimitException(
        data['error'] ?? 'Too many requests',
        data['retry_after_seconds'] ?? 0,
      );
    } else if (response.statusCode != 200) {
      throw Exception('Failed to request password reset');
    }
  }

  /// Reset password with token
  Future<Map<String, dynamic>> resetPassword(
    String token,
    String newPassword,
    String confirmPassword,
  ) async {
    if (newPassword != confirmPassword) {
      throw Exception('Passwords do not match');
    }

    // Validate password strength
    final validation = _validatePassword(newPassword);
    if (!validation['isValid']) {
      throw PasswordValidationException(validation['errors']);
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data as Map<String, dynamic>;
    } else if (response.statusCode == 400) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Password reset failed');
    } else {
      throw Exception('Server error during password reset');
    }
  }

  /// Validate password strength (client-side)
  Map<String, dynamic> _validatePassword(String password) {
    final errors = <String>[];

    if (password.length < 8) {
      errors.add('At least 8 characters');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Lowercase letter');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Uppercase letter');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Number');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Special character');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }
}

class RateLimitException implements Exception {
  final String message;
  final int retryAfterSeconds;

  RateLimitException(this.message, this.retryAfterSeconds);

  @override
  String toString() => message;
}

class PasswordValidationException implements Exception {
  final List<String> errors;

  PasswordValidationException(this.errors);

  @override
  String toString() => 'Password must contain: ${errors.join(', ')}';
}
```

### 4. Create Frontend Screens

#### 4a. Email Verification Screen

**File**: `frontend/lib/features/email_verification/pages/verification_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VerificationScreen extends StatelessWidget {
  final String? token;

  const VerificationScreen({Key? key, this.token}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify Email')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail, size: 100, color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'Check Your Email',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'We sent a verification link to your email. Click the link to verify your account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            if (token != null) ...[
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Verifying your email...'),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  // TODO: Trigger resend verification email
                },
                child: Text('Resend Verification Email'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

#### 4b. Password Recovery Screens

**File**: `frontend/lib/features/password_recovery/pages/forgot_password_screen.dart`

```dart
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset Password')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 32),
            Icon(Icons.lock_reset, size: 100, color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'Forgot Your Password?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text(
              'Enter your email and we\'ll send you a link to reset your password.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'user@example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            if (_message != null)
              Container(
                padding: EdgeInsets.all(12),
                backgroundColor: Colors.blue[50],
                child: Text(_message!),
              ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleResetPassword() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Call passwordRecoveryService.requestPasswordReset(_emailController.text)
      setState(() {
        _message = 'If email is registered, reset link will be sent';
      });
    } catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
```

---

## End-to-End Testing Procedures

### Manual Testing Checklist

**Email Verification Flow**:
- [ ] User completes registration → redirected to VerificationScreen
- [ ] Verification email arrives within 2 minutes
- [ ] Email contains clickable verification link
- [ ] Clicking link → navigates to app via deep link
- [ ] Token submitted to backend → success message
- [ ] User can now access messaging features
- [ ] Clicking same link again → error or already-verified message
- [ ] Resending verification email → new link works, old doesn't

**Password Recovery Flow**:
- [ ] Login screen has "Forgot password" link
- [ ] Clicking → navigates to ForgotPasswordScreen
- [ ] Entering non-existent email → same response as registered email
- [ ] Valid email → reset email sent
- [ ] Email arrives within 2 minutes
- [ ] Email contains clickable reset link
- [ ] Clicking link → navigates to app via deep link
- [ ] PasswordResetScreen displayed
- [ ] Entering weak password → validation errors shown
- [ ] Entering valid password → submitted to backend
- [ ] Success → redirected to login screen
- [ ] New password works for login, old password doesn't

**Rate Limiting**:
- [ ] Send 5 password reset requests (different emails) → all succeed
- [ ] Send 6th request for same email within 1 hour → blocked with 429
- [ ] Error message indicates wait time
- [ ] After 1 hour → can send new request

### Automated Testing

```bash
# Backend tests
cd backend
dart test test/services/token_service_test.dart
dart test test/services/email_service_test.dart
dart test test/services/rate_limit_service_test.dart
dart test test/handlers/

# Frontend tests
cd frontend
flutter test test/features/email_verification/
flutter test test/features/password_recovery/
```

---

## Troubleshooting

### Email Not Sending

1. **Check email service configuration** (`.env` file)
   ```bash
   echo $EMAIL_PROVIDER
   echo $SENDGRID_API_KEY  # Don't expose in logs!
   ```

2. **For SendGrid**: Verify API key in SendGrid dashboard
   - Settings → API Keys → Recent

3. **For SMTP**: Test connection
   ```bash
   # ping SMTP host
   nc -zv $SMTP_HOST $SMTP_PORT
   ```

### Deep Linking Not Working

1. **Android**: Verify AndroidManifest.xml has scheme configured
   ```bash
   grep -A 5 "intent-filter" android/app/src/main/AndroidManifest.xml
   ```

2. **iOS**: Verify Info.plist has URL scheme
   ```bash
   grep -A 5 "CFBundleURLSchemes" ios/Runner/Info.plist
   ```

3. **Test locally**: Use `adb` or `xcrun` to simulate deep link
   ```bash
   # Android
   adb shell am start -a android.intent.action.VIEW -d "messenger://verify?token=XXX"
   ```

### Token Expiration Issues

1. **Verify database timezone**: Should be UTC
   ```sql
   SELECT CURRENT_TIMESTAMP;  -- Should show +00:00
   ```

2. **Check token expiration**:
   ```sql
   SELECT id, expires_at, NOW() FROM verification_tokens LIMIT 1;
   ```

### Rate Limiting Not Working

1. **Check PasswordResetAttempt records**:
   ```sql
   SELECT * FROM password_reset_attempts WHERE email = 'test@example.com';
   ```

2. **Verify rate limit query**:
   ```sql
   SELECT COUNT(*) FROM password_reset_attempts 
   WHERE email = 'test@example.com' 
   AND attempted_at > NOW() - INTERVAL '60 minutes';
   ```

