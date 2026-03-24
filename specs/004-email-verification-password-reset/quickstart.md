# Quickstart Guide: Email Verification and Password Recovery

**Feature**: 004-email-verification-password-reset | **Date**: March 11, 2026

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

### 2. Set Up Email Service

Configure SendGrid or SMTP provider via environment variables:

**`.env` (Backend)**:
```env
# Email Service Configuration
EMAIL_PROVIDER=sendgrid  # or 'smtp'
SENDGRID_API_KEY=sg_test_key_here_...
SENDGRID_FROM_EMAIL=noreply@messenger.example.com

# OR for SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_EMAIL=noreply@messenger.example.com

# Token Configuration
TOKEN_EXPIRATION_HOURS=24
PASSWORD_RESET_MAX_ATTEMPTS_PER_HOUR=5
PASSWORD_RESET_ATTEMPT_WINDOW_MINUTES=60

# Backend URL (for token links in emails)
BACKEND_URL=http://localhost:8081
FRONTEND_URL=http://localhost:8080
```

### 3. Implement Backend Services

Create the following service files:

**`backend/lib/src/services/token_service.dart`**:
```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TokenService {
  /// Generate a cryptographically secure random token (32 bytes)
  String generateToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', ''); // Remove padding
  }

  /// Hash token using SHA256
  String hashToken(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }

  /// Timing-safe token comparison
  bool verifyTokenHash(String token, String storedHash) {
    final hash = hashToken(token);
    
    // Timing-safe comparison
    int result = 0;
    for (int i = 0; i < hash.length && i < storedHash.length; i++) {
      result |= hash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    result |= hash.length ^ storedHash.length;
    
    return result == 0;
  }
}
```

**`backend/lib/src/services/email_service.dart`**:
```dart
class EmailService {
  final String? sendgridApiKey;
  final String provider;
  final String fromEmail;

  EmailService({
    required this.provider,
    required this.fromEmail,
    this.sendgridApiKey,
  });

  /// Send verification email
  Future<bool> sendVerificationEmail(
    String email,
    String username,
    String token,
  ) async {
    try {
      final verificationLink = '${frontendUrl}/verify-email?token=$token';
      
      if (provider == 'sendgrid') {
        return await _sendViaSendGrid(
          to: email,
          subject: 'Verify Your Mobile Messenger Account',
          body: _buildVerificationEmailBody(username, verificationLink),
        );
      } else if (provider == 'smtp') {
        return await _sendViaSMTP(
          to: email,
          subject: 'Verify Your Mobile Messenger Account',
          body: _buildVerificationEmailBody(username, verificationLink),
        );
      }
      return false;
    } catch (e) {
      logger.error('Failed to send verification email: $e');
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(
    String email,
    String username,
    String token,
  ) async {
    try {
      final resetLink = '${frontendUrl}/reset-password?token=$token';
      
      if (provider == 'sendgrid') {
        return await _sendViaSendGrid(
          to: email,
          subject: 'Reset Your Mobile Messenger Password',
          body: _buildPasswordResetEmailBody(username, resetLink),
        );
      } else if (provider == 'smtp') {
        return await _sendViaSMTP(
          to: email,
          subject: 'Reset Your Mobile Messenger Password',
          body: _buildPasswordResetEmailBody(username, resetLink),
        );
      }
      return false;
    } catch (e) {
      logger.error('Failed to send password reset email: $e');
      return false;
    }
  }

  String _buildVerificationEmailBody(String username, String link) {
    return '''
Hi $username,

Thank you for registering for Mobile Messenger. 
Please verify your email address by clicking the link below:

$link

This link expires in 24 hours.

If you didn't register for Mobile Messenger, you can ignore this email.

Best regards,
The Mobile Messenger Team
    ''';
  }

  String _buildPasswordResetEmailBody(String username, String link) {
    return '''
Hi $username,

You requested to reset your password. Click the link below to set a new password:

$link

This link expires in 24 hours.

If you didn't request a password reset, you can ignore this email.
Your account is secure.

Best regards,
The Mobile Messenger Team
    ''';
  }

  Future<bool> _sendViaSendGrid({
    required String to,
    required String subject,
    required String body,
  }) async {
    // Implementation: HTTP POST to SendGrid API
    throw UnimplementedError();
  }

  Future<bool> _sendViaSMTP({
    required String to,
    required String subject,
    required String body,
  }) async {
    // Implementation: SMTP via mailer package
    throw UnimplementedError();
  }
}
```

**`backend/lib/src/services/rate_limiter_service.dart`**:
```dart
class RateLimiterService {
  final PostgresConnection db;
  final int maxAttempts = 5;
  final int windowMinutes = 60;

  /// Track a password reset attempt
  Future<void> trackResetAttempt(String email) async {
    await db.execute(
      'INSERT INTO password_reset_attempts (email, attempted_at) VALUES (@email, NOW())',
      substitutionValues: {'email': email},
    );
  }

  /// Check if email has exceeded rate limit
  Future<bool> isRateLimited(String email) async {
    final result = await db.query(
      'SELECT COUNT(*) as count FROM password_reset_attempts WHERE email = @email AND attempted_at > NOW() - INTERVAL @window',
      substitutionValues: {
        'email': email,
        'window': '$windowMinutes minutes',
      },
    );
    
    final count = result.first.toColumnMap()['count'] as int;
    return count >= maxAttempts;
  }

  /// Clean up old attempts (called by scheduled job)
  Future<void> cleanupExpiredAttempts() async {
    await db.execute(
      'DELETE FROM password_reset_attempts WHERE attempted_at < NOW() - INTERVAL \'1 day\'',
    );
  }
}
```

### 4. Implement Backend Endpoints

**`backend/lib/src/endpoints/verification_endpoints.dart`**:
```dart
class VerificationEndpoints {
  final db = PostgresConnection();
  final tokenService = TokenService();
  final emailService = EmailService();
  final rateLimiter = RateLimiterService();

  // POST /auth/send-verification-email
  Future<Response> sendVerificationEmail(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final userId = body['user_id'] as String;

      // Fetch user
      final userResult = await db.query(
        'SELECT email, username, email_verified FROM users WHERE id = @id',
        substitutionValues: {'id': userId},
      );

      if (userResult.isEmpty) {
        return Response.notFound('User not found');
      }

      final user = userResult.first;
      if (user['email_verified'] == true) {
        return Response(400, body: jsonEncode({
          'success': false,
          'error': 'Email already verified',
        }));
      }

      // Generate and store token
      final token = tokenService.generateToken();
      final tokenHash = tokenService.hashToken(token);
      
      await db.execute(
        'INSERT INTO verification_tokens (user_id, token_hash, expires_at, created_at) '
        'VALUES (@user_id, @token_hash, NOW() + INTERVAL \'24 hours\', NOW())',
        substitutionValues: {
          'user_id': userId,
          'token_hash': tokenHash,
        },
      );

      // Send email
      await emailService.sendVerificationEmail(
        user['email'],
        user['username'],
        token,
      );

      return Response.ok(jsonEncode({
        'success': true,
        'message': 'Verification email sent',
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'error': 'Internal server error',
        }),
      );
    }
  }

  // POST /auth/verify-email
  Future<Response> verifyEmail(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final token = body['token'] as String;

      // Find and validate token
      final tokenHash = tokenService.hashToken(token);
      final tokenResult = await db.query(
        'SELECT user_id, expires_at, used_at FROM verification_tokens '
        'WHERE token_hash = @hash AND expires_at > NOW()',
        substitutionValues: {'hash': tokenHash},
      );

      if (tokenResult.isEmpty) {
        return Response(400, body: jsonEncode({
          'success': false,
          'error': 'Invalid or expired verification token',
        }));
      }

      final tokenRecord = tokenResult.first;
      if (tokenRecord['used_at'] != null) {
        return Response(400, body: jsonEncode({
          'success': false,
          'error': 'Token already used',
        }));
      }

      final userId = tokenRecord['user_id'];

      // Update user and mark token as used
      await db.execute('BEGIN');
      try {
        await db.execute(
          'UPDATE users SET email_verified = true, verified_at = NOW() WHERE id = @id',
          substitutionValues: {'id': userId},
        );

        await db.execute(
          'UPDATE verification_tokens SET used_at = NOW() WHERE token_hash = @hash',
          substitutionValues: {'hash': tokenHash},
        );

        await db.execute('COMMIT');
      } catch (e) {
        await db.execute('ROLLBACK');
        rethrow;
      }

      // Fetch updated user
      final userResult = await db.query(
        'SELECT id, email, username, email_verified, verified_at FROM users WHERE id = @id',
        substitutionValues: {'id': userId},
      );

      return Response.ok(jsonEncode({
        'success': true,
        'message': 'Email verified successfully',
        'user': _userToJson(userResult.first),
      }));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  Map<String, dynamic> _userToJson(PostgresResult user) {
    return {
      'id': user['id'],
      'email': user['email'],
      'email_verified': user['email_verified'],
      'verified_at': user['verified_at']?.toString(),
    };
  }
}
```

### 5. Register Endpoints in Server

**`backend/lib/server.dart`**:
```dart
void main() {
  final verificationEndpoints = VerificationEndpoints();
  final passwordRecoveryEndpoints = PasswordRecoveryEndpoints();

  final router = Router()
    ..post('/auth/send-verification-email', verificationEndpoints.sendVerificationEmail)
    ..post('/auth/verify-email', verificationEndpoints.verifyEmail)
    ..post('/auth/send-password-reset-email', passwordRecoveryEndpoints.sendPasswordResetEmail)
    ..post('/auth/reset-password', passwordRecoveryEndpoints.resetPassword);

  // Start server
  serve(router, 'localhost', 8081);
}
```

### 6. Run Backend Tests

```bash
cd backend
dart test test/integration/test_verification_endpoints.dart
dart test test/unit/test_token_service.dart
dart test test/unit/test_rate_limiter_service.dart
```

---

## For Frontend Developers

### 1. Set Up Authentication Services

**`frontend/lib/core/auth/services/verification_service.dart`**:
```dart
import 'package:flutter/material.dart';
import 'auth_service.dart';

class VerificationService {
  final AuthService _authService;

  VerificationService(this._authService);

  /// Check if current user's email is verified
  Future<bool> isEmailVerified() async {
    final user = _authService.currentUser;
    return user?.emailVerified ?? false;
  }

  /// Request verification email to be resent
  Future<Map<String, dynamic>> resendVerificationEmail() async {
    try {
      final response = await _authService.apiClient.post(
        '/auth/send-verification-email',
        data: {
          'user_id': _authService.currentUser!.id,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  /// Verify email using token from email link
  Future<bool> verifyEmailWithToken(String token) async {
    try {
      final response = await _authService.apiClient.post(
        '/auth/verify-email',
        data: {'token': token},
      );
      
      if (response.data['success'] == true) {
        // Update local auth state
        await _authService.updateUserVerificationStatus(true);
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }
}
```

**`frontend/lib/core/auth/services/password_recovery_service.dart`**:
```dart
class PasswordRecoveryService {
  final AuthService _authService;

  PasswordRecoveryService(this._authService);

  /// Request password reset email
  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await _authService.apiClient.post(
        '/auth/send-password-reset-email',
        data: {'email': email},
      );
      return response.data['success'] == true;
    } catch (e) {
      if (e.response?.statusCode == 429) {
        throw RateLimitException('Too many password reset attempts');
      }
      rethrow;
    }
  }

  /// Reset password using token from email
  Future<bool> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _authService.apiClient.post(
        '/auth/reset-password',
        data: {
          'token': token,
          'new_password': newPassword,
          'confirm_password': newPassword,
        },
      );
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }
}
```

### 2. Create Screens

**`frontend/lib/features/auth/screens/email_verification_screen.dart`**:
```dart
class EmailVerificationScreen extends StatefulWidget {
  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late VerificationService _service;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<VerificationService>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify Email')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.email, size: 64, color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'Verify Your Email',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text(
              'We sent a verification link to your email.\nPlease click the link to verify your account.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isResending ? null : _onResendPressed,
              child: _isResending
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(),
                    )
                  : Text('Resend Verification Email'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onResendPressed() async {
    setState(() => _isResending = true);
    try {
      await _service.resendVerificationEmail();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification email resent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend email')),
      );
    } finally {
      setState(() => _isResending = false);
    }
  }
}
```

**`frontend/lib/features/auth/screens/password_recovery_screen.dart`**:
```dart
class PasswordRecoveryScreen extends StatefulWidget {
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _emailController = TextEditingController();
  late PasswordRecoveryService _service;
  bool _isSubmitting = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<PasswordRecoveryService>();
  }

  @override
  Widget build(BuildContext context) {
    if (_emailSent) {
      return Scaffold(
        appBar: AppBar(title: Text('Password Reset')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 24),
                Text(
                  'Check Your Email',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 16),
                Text(
                  'We sent a password reset link to ${_emailController.text}',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Reset Password')),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                label: Text('Email'),
                hintText: 'Enter your email address',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _onSubmit,
              child: _isSubmitting
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(),
                    )
                  : Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    setState(() => _isSubmitting = true);
    try {
      await _service.requestPasswordReset(_emailController.text);
      setState(() => _emailSent = true);
    } on RateLimitException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Too many attempts. Please try again later.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset link')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
```

### 3. Update Navigation

**`frontend/lib/app.dart`**:
```dart
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => AuthGate());
      case '/verify-email':
        return MaterialPageRoute(builder: (_) => EmailVerificationScreen());
      case '/forgot-password':
        return MaterialPageRoute(builder: (_) => PasswordRecoveryScreen());
      case '/reset-password':
        final token = (settings.arguments as Map)['token'] as String;
        return MaterialPageRoute(
          builder: (_) => PasswordResetScreen(token: token),
        );
      default:
        return MaterialPageRoute(builder: (_) => NotFoundScreen());
    }
  }
}
```

### 4. Configure Deep Linking

**`android/app/AndroidManifest.xml`**:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="app.messenger" android:pathPrefix="/verify-email" />
  <data android:scheme="https" android:host="app.messenger" android:pathPrefix="/reset-password" />
</intent-filter>
```

**`ios/Runner/Info.plist`**:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>https</string>
    </array>
    <key>CFBundleURLName</key>
    <string>EmailVerification</string>
  </dict>
</array>
```

### 5. Run Tests

```bash
cd frontend
flutter test test/widget/test_email_verification_screen.dart
flutter test test/widget/test_password_recovery_screen.dart
flutter test test/integration/test_verification_flow.dart
```

---

## Testing the Features End-to-End

### 1. Start Backend

```bash
cd backend
docker compose up
# Or: dart pub get && dart run bin/server.dart
```

### 2. Start Frontend

```bash
cd frontend
flutter pub get
flutter run
```

### 3. Test Email Verification

```
1. Click "Register"
2. Fill in email, username, password
3. Click "Register"
4. Check console for verification email (in dev, printed to terminal)
5. Copy verification token from email
6. Click "Verify Email" button
7. Paste token and confirm
8. Verify account is now active
```

### 4. Test Password Recovery

```
1. Go to Login screen
2. Click "Forgot Password?"
3. Enter email address
4. Confirm "Check your email" message
5. Copy password reset token from email
6. Open reset link (deep link)
7. Enter new password
8. Click "Reset Password"
9. Go back to login
10. Login with new password
```

---

## Troubleshooting

### Email Not Sending

**Issue**: Verification/reset emails not received

**Solutions**:
- Check `SENDGRID_API_KEY` is set correctly in `.env`
- Verify SendGrid account has remaining email quota
- Check spam folder
- Review backend logs for email service errors

### Token Validation Fails

**Issue**: Token shows as invalid

**Solutions**:
- Ensure token hasn't expired (24 hour window)
- Check token is copied correctly (no extra spaces)
- Verify token hash matches in database
- Check system time is synced

### Rate Limiting Issues

**Issue**: User blocked after multiple password reset requests

**Solutions**:
- Wait 1 hour for rate limit to reset
- Check `password_reset_attempts` table for entries
- Verify rate limit window is correctly configured
- Consider admin override for support tickets

---

## Next Steps

1. **Phase 2 Implementation**: Build remaining screens and integrate with existing auth flow
2. **Testing**: Run full E2E test suite
3. **Deployment**: Deploy to production with email service credentials
4. **Monitoring**: Set up alerts for email delivery failures and unusual rate limiting
