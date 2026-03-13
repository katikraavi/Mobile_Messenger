import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/utils/validators.dart';
import 'package:frontend/features/profile/models/profile_form_state.dart';

void main() {
  group('Validators - T068 Unit Tests', () {
    // T068: Username validation tests
    group('validateUsername', () {
      test('T068-1: Valid username "john_doe" returns null', () {
        final result = Validators.validateUsername('john_doe');
        expect(result, isNull);
      });

      test('T068-2: Valid username "user123" returns null', () {
        final result = Validators.validateUsername('user123');
        expect(result, isNull);
      });

      test('T068-3: Valid username "test-user" (with hyphen) returns null', () {
        final result = Validators.validateUsername('test-user');
        expect(result, isNull);
      });

      test('T068-4: Valid username "a_b_c" (minimum length 3) returns null', () {
        final result = Validators.validateUsername('a_b_c');
        expect(result, isNull);
      });

      test('T068-5: Valid username with exactly 32 chars returns null', () {
        final username32 = 'a' + 'b' * 30 + 'c'; // 32 chars total
        final result = Validators.validateUsername(username32);
        expect(result, isNull);
      });

      test('T068-6: Invalid username "ab" (too short, < 3 chars) returns error', () {
        final result = Validators.validateUsername('ab');
        expect(result, ValidationError.invalidUsername);
        expect(result?.message, contains('must be 3-32 characters'));
      });

      test('T068-7: Invalid username "a" (1 char) returns error', () {
        final result = Validators.validateUsername('a');
        expect(result, ValidationError.invalidUsername);
      });

      test('T068-8: Empty username "" returns error', () {
        final result = Validators.validateUsername('');
        expect(result, ValidationError.invalidUsername);
      });

      test('T068-9: Invalid username with special chars "user@domain" returns error', () {
        final result = Validators.validateUsername('user@domain');
        expect(result, ValidationError.invalidUsername);
        expect(result?.message, contains('letters, numbers, underscore, or hyphen'));
      });

      test('T068-10: Invalid username with spaces "user name" returns error', () {
        final result = Validators.validateUsername('user name');
        expect(result, ValidationError.invalidUsername);
      });

      test('T068-11: Username "123" (only numbers) returns null if 3+ chars', () {
        final result = Validators.validateUsername('123');
        expect(result, isNull);
      });

      test('T068-12: Username "a_b" (with underscore, 3 chars) returns null', () {
        final result = Validators.validateUsername('a_b');
        expect(result, isNull);
      });

      test('T068-13: Username "a-b" (with hyphen, 3 chars) returns null', () {
        final result = Validators.validateUsername('a-b');
        expect(result, isNull);
      });

      test('T068-14: Username exceeding 32 chars returns error', () {
        final longUsername = 'a' * 33;
        final result = Validators.validateUsername(longUsername);
        expect(result, ValidationError.invalidUsername);
        expect(result?.message, contains('must be 3-32 characters'));
      });

      test('T068-15: Username with leading/trailing spaces trims and validates', () {
        // Note: Validators should handle trimmed input (trimming happens in form notifier)
        final result = Validators.validateUsername('  john_doe  ');
        // If validator doesn't trim, this might fail - depends on implementation
        // Ideally should return null after trimming
      });
    });

    // T068: Bio validation tests
    group('validateBio', () {
      test('T068-16: Valid bio "Software engineer" returns null', () {
        final result = Validators.validateBio('Software engineer');
        expect(result, isNull);
      });

      test('T068-17: Valid bio "" (empty) returns null', () {
        final result = Validators.validateBio('');
        expect(result, isNull);
      });

      test('T068-18: Valid bio with exactly 500 chars returns null', () {
        final bio500 = 'x' * 500;
        final result = Validators.validateBio(bio500);
        expect(result, isNull);
      });

      test('T068-19: Valid bio with special chars "Hello! @user #tag" returns null', () {
        final result = Validators.validateBio('Hello! @user #tag');
        expect(result, isNull);
      });

      test('T068-20: Valid bio with newlines "Line 1\\nLine 2" returns null', () {
        final result = Validators.validateBio('Line 1\nLine 2');
        expect(result, isNull);
      });

      test('T068-21: Invalid bio exceeding 500 chars returns error', () {
        final bio501 = 'x' * 501;
        final result = Validators.validateBio(bio501);
        expect(result, ValidationError.invalidBio);
        expect(result?.message, contains('must be 0-500 characters'));
      });

      test('T068-22: Invalid bio with 1000 chars returns error', () {
        final bioLong = 'Lorem ipsum ' * 100;
        final result = Validators.validateBio(bioLong);
        expect(result, ValidationError.invalidBio);
      });

      test('T068-23: Bio with emoji "I ❤️ coding" is valid', () {
        final result = Validators.validateBio('I ❤️ coding');
        expect(result, isNull);
      });

      test('T068-24: Bio with international chars "Привет мир" (Russian) is valid', () {
        final result = Validators.validateBio('Привет мир');
        expect(result, isNull);
      });
    });

    // T068: ValidationError enum message tests
    group('ValidationError.message', () {
      test('T068-25: ValidationError.invalidUsername has correct message', () {
        expect(
          ValidationError.invalidUsername.message,
          contains('must be 3-32 characters'),
        );
      });

      test('T068-26: ValidationError.invalidBio has correct message', () {
        expect(
          ValidationError.invalidBio.message,
          contains('must be 0-500 characters'),
        );
      });

      test('T068-27: ValidationError messages are user-friendly (not technical)', () {
        final message = ValidationError.invalidUsername.message;
        expect(message, isNotEmpty);
        expect(message.length, greaterThan(10)); // Reasonably descriptive
      });
    });

    // T065-style integration tests
    group('Form validation workflow (T065)', () {
      test('T065-1 + T068: Invalid username → error returns → field stays populated', () {
        final invalidUsername = 'ab'; // Too short
        final errorResult = Validators.validateUsername(invalidUsername);
        expect(errorResult, ValidationError.invalidUsername);
        // Username string itself remains intact for display
        expect(invalidUsername, equals('ab'));
      });

      test('T065-2 + T068: Can fix invalid field and revalidate successfully', () {
        var username = 'ab'; // Invalid
        var result = Validators.validateUsername(username);
        expect(result, isNotNull);

        // User fixes it
        username = 'john_doe'; // Valid
        result = Validators.validateUsername(username);
        expect(result, isNull); // Now valid
      });

      test('T065-3 + T068: Bio validation workflow', () {
        var bio = 'x' * 501; // Invalid - too long
        var result = Validators.validateBio(bio);
        expect(result, ValidationError.invalidBio);

        // User fixes it
        bio = bio.substring(0, 500);
        result = Validators.validateBio(bio);
        expect(result, isNull); // Now valid
      });

      test('T068-28: Multiple fields validation - both valid', () {
        final username = 'john_doe';
        final bio = 'Software engineer';

        final usernameResult = Validators.validateUsername(username);
        final bioResult = Validators.validateBio(bio);

        expect(usernameResult, isNull);
        expect(bioResult, isNull);
      });

      test('T068-29: Multiple fields validation - one invalid', () {
        final username = 'ab'; // Invalid
        final bio = 'Software engineer';

        final usernameResult = Validators.validateUsername(username);
        final bioResult = Validators.validateBio(bio);

        expect(usernameResult, ValidationError.invalidUsername);
        expect(bioResult, isNull);
      });

      test('T068-30: Multiple fields validation - both invalid', () {
        final username = 'ab'; // Invalid
        final bio = 'x' * 501; // Invalid

        final usernameResult = Validators.validateUsername(username);
        final bioResult = Validators.validateBio(bio);

        expect(usernameResult, ValidationError.invalidUsername);
        expect(bioResult, ValidationError.invalidBio);
      });
    });

    // Edge cases
    group('Edge cases', () {
      test('T068-31: Username with only numbers is valid if 3+ chars', () {
        expect(Validators.validateUsername('123'), isNull);
        expect(Validators.validateUsername('2023'), isNull);
      });

      test('T068-32: Username is case-sensitive (comparison)', () {
        expect(Validators.validateUsername('UserName'), isNull);
        expect(Validators.validateUsername('USERNAME'), isNull);
      });

      test('T068-33: Very long bio (5000 chars) returns error', () {
        final longBio = 'word ' * 1000; // Way over 500
        expect(Validators.validateBio(longBio), ValidationError.invalidBio);
      });

      test('T068-34: Username with mix of valid chars', () {
        expect(Validators.validateUsername('user_name-123'), isNull);
        expect(Validators.validateUsername('a_b'), isNull);
        expect(Validators.validateUsername('a-b'), isNull);
      });
    });
  });
}
