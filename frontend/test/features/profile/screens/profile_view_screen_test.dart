import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/models/user_profile.dart';
import 'package:frontend/features/profile/providers/user_profile_provider.dart';
import 'package:frontend/features/profile/screens/profile_view_screen.dart';

void main() {
  const testUserId = 'test-user';

  UserProfile buildProfile({
    String userId = testUserId,
    String username = 'alice',
    String aboutMe = 'Hello from test profile',
    bool isPrivate = false,
  }) {
    return UserProfile(
      userId: userId,
      username: username,
      aboutMe: aboutMe,
      isPrivateProfile: isPrivate,
      isDefaultProfilePicture: true,
    );
  }

  Widget buildScreen({
    required String userId,
    required bool isOwnProfile,
    required Future<UserProfile> Function(String userId) resolver,
  }) {
    return MaterialApp(
      home: ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref, id) => resolver(id)),
          userProfileWithTokenProvider.overrideWith((ref, params) => resolver(params.$1)),
        ],
        child: ProfileViewScreen(
          userId: userId,
          isOwnProfile: isOwnProfile,
        ),
      ),
    );
  }

  group('ProfileViewScreen Widget Tests', () {
    testWidgets('displays loading indicator initially', (WidgetTester tester) async {
      final completer = Completer<UserProfile>();

      await tester.pumpWidget(
        buildScreen(
          userId: testUserId,
          isOwnProfile: false,
          resolver: (_) => completer.future,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(buildProfile());
      await tester.pumpAndSettle();
    });

    testWidgets('displays profile data when loaded', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildScreen(
          userId: testUserId,
          isOwnProfile: false,
          resolver: (id) async => buildProfile(userId: id, username: 'alice'),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('alice'), findsOneWidget);
    });

    testWidgets('shows Edit button for own profile', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildScreen(
          userId: testUserId,
          isOwnProfile: true,
          resolver: (id) async => buildProfile(userId: id),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('hides Edit button for other profiles', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildScreen(
          userId: 'other-user',
          isOwnProfile: false,
          resolver: (id) async => buildProfile(userId: id, username: 'other-user'),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('displays private profile indicator when isPrivateProfile is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildScreen(
          userId: testUserId,
          isOwnProfile: false,
          resolver: (id) async => buildProfile(userId: id, isPrivate: true),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Private Profile'), findsOneWidget);
    });

    testWidgets('displays about me in card', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildScreen(
          userId: testUserId,
          isOwnProfile: false,
          resolver: (id) async => buildProfile(
            userId: id,
            aboutMe: 'Testing about me section',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Testing about me section'), findsOneWidget);
    });

    testWidgets('retry button appears on error', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildScreen(
          userId: testUserId,
          isOwnProfile: false,
          resolver: (id) => Future<UserProfile>.error(Exception('forced test error')),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
