specify: Implement Email Verification and Password Recovery

Goal
Secure account access.

Features
- email verification link after registration
- user must verify email
- password reset via email link

Flow
register → email verification
forgot password → email link → reset password

Acceptance Criteria
- verification email sent
- reset email sent
- password can be updated

What to test
- Register a new account
- Verify verification email is sent
- Click verification link and confirm account activation
- Use "Forgot password"
- Receive reset email
- Set a new password
- Confirm login works with new password
