import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/services/profile_api_service.dart';

/// Provider to fetch user profile by user ID
final userProfileProvider =
    FutureProvider.family<UserProfile, (String userId, String token)>((ref, params) async {
  final profileService = ProfileApiService();
  return profileService.fetchProfile(params.$1, token: params.$2);
});
