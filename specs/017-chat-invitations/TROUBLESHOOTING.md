# Chat Invitations - Troubleshooting Guide

## Quick Diagnosis

Before diving into specific issues, run this checklist:

```
[ ] Backend service running (docker-compose ps)
[ ] Database accessible (psql connection works)
[ ] Frontend connected to backend (check API Client logs)
[ ] JWT token valid (check auth status)
[ ] Firebase configured (if using push notifications)
```

---

## Common Issues & Solutions

### Issue 1: App Can't Connect to Backend

**Symptoms**:
- Connection error on app startup
- "Unable to connect to backend server" message
- API calls timing out

**Diagnosis**:
1. Check backend is running:
   ```bash
   docker-compose ps
   # Should show: backend_service ... Up
   ```

2. Test backend connectivity:
   ```bash
   curl http://localhost:8080/health
   # Should return: {"status": "ok"}
   ```

3. Check API client configuration in Flutter:
   ```dart
   // frontend/lib/core/services/api_client.dart
   static const String baseUrl = 'http://localhost:8080/api';
   ```

**Solutions**:
- Start backend: `docker-compose up -d`
- Restart backend: `docker-compose restart backend_service`
- Check Docker network: `docker network ls`
- Verify port 8080 isn't blocked by firewall
- On iOS/Android emulator, use proper IP address (not localhost)

---

### Issue 2: "Pending Invitation Already Exists" Error

**Symptoms**:
- Can't send invitation to same user twice
- Error: `409 Conflict` / "Pending invitation already exists"

**Root Cause**:
- Database has unique constraint on (sender_id, recipient_id, status='pending')
- Design by intent: Prevents duplicate pending invites

**Solution**:
- User must wait for recipient to accept or decline
- After decline, can send new invitation
- After accept, chat is created and you don't need invitation

**If Testing**:
- Use different test users each time
- Or have recipient decline first
- Or manually edit database to remove pending status

---

### Issue 3: Firebase Push Notifications Not Working

**Symptoms**:
- Send invitation but no notification received
- No errors in logs
- "Send notification" code doesn't crash

**Root Cause**:
- Firebase not configured with real credentials
- Device token not sent to backend
- Notifications disabled in app/system settings

**Diagnosis**:
1. Check Firebase configuration:
   ```dart
   // frontend/lib/firebase_options.dart
   // Contains dummy credentials - needs real values
   ```

2. Check device token:
   ```dart
   final token = await FirebaseMessaging.instance.getToken();
   print('FCM Token: $token');
   ```

3. Check notification permissions:
   - Settings → Apps → Mobile Messenger → Notifications → Allow

**Solutions**:
1. **Configure Firebase** (production):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   # Follow prompts to select Firebase project
   ```

2. **Get device token** and send to backend on login

3. **Allow notifications** in system settings

4. **For development**: Use Firebase emulator
   ```bash
   firebase emulators:start
   ```

---

### Issue 4: Offline App Doesn't Work

**Symptoms**:
- App crashes when offline
- Can't view cached invitations
- No local data available

**Root Cause**:
- Offline cache not initialized
- Secure storage not configured
- No check for connection state before API calls

**Diagnosis**:
```dart
// Check cache service
final cache = InvitationsCacheService();
final cached = await cache.getCachedPendingInvites();
print('Cached data: $cached');
```

**Solutions**:
1. **Ensure cache is written** after successful API call:
   ```dart
   // InviteApiService should call cache.cachePendingInvites()
   ```

2. **Check secure storage** permissions:
   - Android: `WRITE_SECURE_SETTINGS` permission
   - iOS: Keychain access

3. **Implement connection check**:
   ```dart
   final isOnline = await checkNetworkConnection();
   if (!isOnline) {
     // Use cached data
     return await cache.getCachedPendingInvites();
   }
   ```

---

### Issue 5: Database Migration Fails

**Symptoms**:
- Migration error when starting backend
- `chat_invites` table doesn't exist
- "Table 'chat_invites' not found" errors

**Root Cause**:
- Migration file not executed
- PostgreSQL not running
- Database permissions issue

**Diagnosis**:
```bash
# Check if table exists
docker-compose exec postgres psql -U messenger_user -d messenger_db -c "\dt chat_invites"

# Check migration status
docker-compose logs backend | grep -i migration
```

**Solutions**:
1. **Run migrations manually**:
   ```bash
   # In backend container
   dart lib/src/migrations/001_create_enums.dart
   dart lib/src/migrations/006_create_invites_table.dart
   ```

2. **Reset database**:
   ```bash
   docker-compose down -v  # Remove volumes too
   docker-compose up -d
   # Migrations run on startup
   ```

3. **Check PostgreSQL**:
   ```bash
   docker-compose ps postgres
   docker-compose logs postgres
   ```

---

### Issue 6: JWT Token Errors

**Symptoms**:
- `401 Unauthorized` on all API calls
- "Authentication required" errors
- Token appears invalid

**Root Cause**:
- Token expired
- Token not sent in header
- Token doesn't match backend secret

**Diagnosis**:
```bash
# Decode token (online JWT decoder)
# Check 'exp' claim for expiration time

# In app logs, check if token is sent:
print(ApiClient.getAuthHeaders());
# Should include: Authorization: Bearer <token>
```

**Solutions**:
1. **Refresh token** on login:
   ```dart
   // AuthProvider should refresh token on init
   await authProvider.login(email, password);
   ```

2. **Check token expiration**:
   ```dart
   final isExpired = token.exp.isBefore(DateTime.now());
   if (isExpired) {
     // Re-login to get new token
   }
   ```

3. **Verify header format**:
   - Must be: `Authorization: Bearer YOUR_TOKEN_HERE`
   - Not: `Authorization: YOUR_TOKEN_HERE`

---

### Issue 7: UI Not Updating After Accept/Decline

**Symptoms**:
- Accept button tapped but invitation still shows
- Badge count doesn't decrease
- Sent tab shows old status

**Root Cause**:
- Riverpod provider not invalidated
- Cache not cleared
- UI not listening to state changes

**Diagnosis**:
```dart
// Check if Riverpod listener is active
// Each button should call:
ref.refresh(pendingInvitesProvider);
ref.refresh(pendingInviteCountProvider);
```

**Solutions**:
1. **Invalidate provider** after mutation:
   ```dart
   ref.invalidate(pendingInvitesProvider);
   ref.refresh(pendingInviteCountProvider);
   ```

2. **Clear cache** on success:
   ```dart
   final cache = InvitationsCacheService();
   await cache.clearAllCaches();
   ```

3. **Rebuild widget** manually if needed:
   ```dart
   setState(() { });
   ```

---

### Issue 8: Performance Issues - Slow Invite List

**Symptoms**:
- InvitationsScreen takes >2 seconds to load
- FPS drops when scrolling large lists
- Memory usage grows over time

**Root Cause**:
- Loading all invites without pagination
- No index on database queries
- UI rebuilding entire list on each update

**Diagnosis**:
```bash
# Check database query time
EXPLAIN ANALYZE SELECT * FROM chat_invites WHERE recipient_id = 'xxx' AND status = 'pending';

# Should show: < 1ms with index

# Check app memory:
# Android: Device Profiler → Memory
# iOS: Xcode → Debug Navigator → Memory
```

**Solutions**:
1. **Add pagination**:
   - Load 20 items initially
   - Implement lazy loading for more
   - Use `PaginationState` class

2. **Ensure database indexes exist**:
   ```sql
   CREATE INDEX IF NOT EXISTS idx_chat_invites_recipient_status 
   ON chat_invites(recipient_id, status);
   ```

3. **Optimize UI**: 
   - Use `ListTile` instead of rebuilding entire list
   - Implement `itemExtent` for fixed-size items
   - Use `addAutomaticKeepAlives: false` if items aren't persistent

---

### Issue 9: Self-Invite Error

**Symptoms**:
- Can't send invitation to own account (expected)
- But error is unclear or happens unexpectedly

**Root Cause**:
- Design intent: Users can't invite themselves
- Validation happens client-side and server-side

**Expected Behavior** (working as intended):
- Trying to send to own ID: `400 Bad Request` "Cannot invite yourself"
- This is correct behavior, not a bug

**If Unexpected**:
- Check that current user ID is correct:
  ```dart
  print('Current user: ${authProvider.currentUserId}');
  print('Trying to invite: ${selectedUserId}');
  ```

---

### Issue 10: Deep Link Not Working on Notification Tap

**Symptoms**:
- Notification received successfully
- Tapping notification opens app
- But doesn't navigate to Invitations screen
- Goes to home screen instead

**Root Cause**:
- Deep link handler not configured
- Navigation key not set
- Deep link format not recognized

**Diagnosis**:
```dart
// Check if navigatorKey is set in app.dart
MaterialApp(
  navigatorKey: _navigatorKey,  // Must be set
  // ...
)

// Check deep link format
const deepLink = 'messenger://invitations?tab=pending';
// Must match parser in push_notification_handler.dart
```

**Solutions**:
1. **Verify navigatorKey is configured**:
   ```dart
   final GlobalKey<NavigatorState> _navigatorKey = 
     GlobalKey<NavigatorState>();
   ```

2. **Check deep link route exists**:
   ```dart
   routes: {
     '/invitations': (context) => const InvitationsScreen(),
   }
   ```

3. **Debug deep link parsing**:
   ```dart
   final uri = Uri.parse('messenger://invitations?tab=pending');
   print('Host: ${uri.host}'); // Should be 'invitations'
   print('Tab: ${uri.queryParameters['tab']}'); // Should be 'pending'
   ```

---

## Debugging Tools

### Backend Debugging

**View logs**:
```bash
docker-compose logs -f backend
```

**Database inspection**:
```bash
docker-compose exec postgres psql -U messenger_user -d messenger_db

# List tables
\dt

# View invites
SELECT * FROM chat_invites;

# Count pending
SELECT COUNT(*) FROM chat_invites WHERE status='pending';
```

### Frontend Debugging

**Flutter logs**:
```bash
flutter logs -f
```

**Break on error**:
```dart
// In main.dart
FlutterError.onError = (details) {
  print('Flutter Error: ${details.exception}');
};
```

**Network logging**:
```dart
// In http_client.dart
final response = await client.get(...);
print('Status: ${response.statusCode}');
print('Body: ${response.body}');
```

### Firebase Debugging

**Check token**:
```dart
final token = await FirebaseMessaging.instance.getToken();
print('Token: $token');
```

**Simulate notification** (emulator):
```bash
firebase emulators:start
# Use Firebase Console to send test message
```

---

## Performance Optimization Checklist

- [ ] Database indexes created and verified
- [ ] Pagination implemented (limit 20 per page)
- [ ] Offline cache working
- [ ] Push notifications configured
- [ ] UI doesn't rebuild entire list
- [ ] Memory usage stable over time
- [ ] API response time < 100ms
- [ ] App startup time < 3 seconds

---

## Emergency Recovery

**If everything breaks**:

```bash
# Stop everything
docker-compose down

# Remove all data
docker-compose down -v

# Restart fresh
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

---

## Getting Help

**Logs to gather**:
1. Backend logs: `docker-compose logs backend`
2. Frontend logs: `flutter logs`
3. Database inspection: `\dt` output
4. Network inspection: iOS - Charles Proxy, Android - Android Studio

**Escalation**:
1. Check this guide first
2. Review API documentation
3. Check git commit history for recent changes
4. Review test failure output
5. Create minimal reproduction case

---

Generated: March 15, 2026  
Feature: Chat Invitations (017-chat-invitations)  
Status: Production Ready
