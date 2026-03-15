# Chat Invitations Feature - Complete Testing Guide

**Last Updated**: March 15, 2026  
**Status**: Ready for Emulator Testing  
**Platform**: Android and iOS

---

## 📱 Quick Start: Running on Android Emulator

### Step 1: Start Android Emulator
```bash
# List available emulators
emulator -list-avds

# Start specific emulator (e.g., Pixel 5 API 31)
emulator -avd Pixel_5_API_31
# or open Android Studio > Device Manager > Launch device

# Wait ~1-2 minutes for emulator to fully boot
```

### Step 2: Clean and Run Flutter App
```bash
cd /home/katikraavi/mobile-messenger/frontend

# Clean build (already done, but can repeat if issues)
flutter clean

# Get dependencies
flutter pub get

# Run on emulator
flutter run
```

**Expected Output:**
```
Launching lib/main.dart on [device_name] in debug mode...
Building Linux application...
✓ Built build/linux/x64/debug/bundle/frontend
...
Flutter run key commands.
r Hot reload. 🔥🔥🔥
q Quit (terminate the application on the device).
```

### Step 3: Interact with the App
Once running, you'll see the app UI. Use:
- **r** key: Hot reload (for testing code changes)
- **q** key: Quit the app
- **d** key: Detach (leave app running)

---

## 🧪 Feature Testing Checklist

### 1. ✅ Basic Navigation
**What to test**: App loads and navigation works

**Steps**:
1. App launches successfully
2. See main chat list screen (or login screen if not authenticated)
3. Tab navigation works (if multiple tabs visible)
4. No crashes or error dialogs

**Expected Result**: ✅ App runs smoothly with proper UI

---

### 2. ✅ Invitations Screen - Send Invitation

**What to test**: Sending an invitation to another user

**Prerequisites**:
- You must be logged in
- Another user account must exist on the backend

**Steps**:
1. Navigate to **Invitations** screen (or find the invitations icon)
2. Look for **"Send New Invite"** button (+ icon in AppBar)
3. Tap the button
4. You'll see **SendInvitePickerScreen** with user list
5. Type a name in the search field (filters users)
6. Tap a user to select (checkmark appears)
7. Tap **"Send"** button
8. See success message: **"Invitation sent successfully!"**
9. Screen closes and returns to Invitations screen

**Expected Result**: ✅ User receives invitation notification

---

### 3. ✅ Invitations Screen - View Pending

**What to test**: View pending invitations received

**Prerequisites**:
- Another user has sent you an invitation
- OR manually send one to yourself (if allowed)

**Steps**:
1. Navigate to **Invitations** screen
2. Look for **"Pending"** tab
3. Should show count badge: **"Pending (X)"** where X = number of pending
4. See list of pending invitations with:
   - Sender's avatar/profile image
   - Sender's name
   - Timestamp (e.g., "2 hours ago")
   - Accept ✅ button
   - Decline ❌ button

**Expected Result**: ✅ All pending invitations visible with precise timestamps

---

### 4. ✅ Accept Invitation

**What to test**: Accepting a pending invitation creates a chat

**Prerequisites**:
- One or more pending invitations available
- Backend is running and database accessible

**Steps**:
1. Open **Pending** tab with invitations
2. Tap **Accept button (✅)** on an invitation
3. See loading indicator briefly
4. See success notification: **"Invitation accepted! Chat created."**
5. Invitation disappears from list
6. Count badge decrements
7. New chat appears in chat list

**Expected Result**: ✅ Chat created, invitation removed, user can now chat with sender

---

### 5. ✅ Decline Invitation

**What to test**: Declining an invitation removes it cleanly

**Prerequisites**:
- One or more pending invitations available

**Steps**:
1. Open **Pending** tab
2. Tap **Decline button (❌)** on an invitation
3. See loading indicator
4. See confirmation: **"Invitation declined"**
5. Invitation disappears from pending list
6. Count badge decrements

**Expected Result**: ✅ Invitation removed, count updated

---

### 6. ✅ View Sent Invitations

**What to test**: See all invitations you've sent

**Prerequisites**:
- You've sent at least one invitation

**Steps**:
1. Navigate to **Invitations** screen
2. Tap **"Sent"** tab
3. See list of sent invitations with:
   - Recipient's name/avatar
   - **Status** with color coding:
     - 📋 **Pending** (orange/gray icon)
     - ✅ **Accepted** (green checkmark)
     - ❌ **Declined** (red X)
   - Timestamp when sent

**Expected Result**: ✅ All sent invitations display with correct status

---

### 7. ✅ Error Handling - Duplicate Invitation

**What to test**: Can't send duplicate invitations

**Prerequisites**:
- Send an invitation to user A
- Then try to send another to user A

**Steps**:
1. Go to **Send New Invite** screen
2. Search and select **User A** (already invited)
3. Tap **Send**
4. See **error dialog**: 
   - Title: "Send Failed" or "Error"
   - Message: **"You've already sent an invitation to this user."**
5. Tap **OK** to close dialog
6. Remain on SendInvitePickerScreen (not closed)

**Expected Result**: ✅ Error message prevents duplicate invitations

---

### 8. ✅ Error Handling - Self Invitation

**What to test**: Can't send invitation to yourself

**Prerequisites**:
- Know your own username

**Steps**:
1. Go to **Send New Invite**
2. Find your own account in the list
3. Try to select and send
4. See **error dialog**: **"You cannot send an invitation to yourself."**

**Expected Result**: ✅ Self-invitations blocked

---

### 9. ✅ Error Handling - Already Chatting

**What to test**: Can't invite someone you're already chatting with

**Prerequisites**:
- You have an active chat with User X
- Go to send invite screen

**Steps**:
1. Go to **Send New Invite**
2. Try to select User X (already in your chat list)
3. Send
4. See **error dialog**: **"You're already chatting with this user."**

**Expected Result**: ✅ Prevents redundant invitations

---

### 10. ✅ Badge Count Updates

**What to test**: Pending invitation count updates in real-time

**Prerequisites**:
- Open Invitations screen
- Have another user ready to send you invitations

**Steps**:
1. Start with **Pending (0)** badge
2. Another user sends you invitation
3. Badge updates to **Pending (1)** after 1-2 seconds
4. Accept the invitation
5. Badge updates back to **Pending (0)**

**Expected Result**: ✅ Badge count always reflects actual pending count

---

### 11. ✅ Empty States

**What to test**: Proper display when no invitations exist

**Steps**:
1. Open **Pending** tab with no pending invitations
2. See **empty state message**: 
   - Icon (mail icon)
   - Text: **"No pending invitations"**
3. Open **Sent** tab with no sent invitations
4. See empty state for sent as well

**Expected Result**: ✅ Empty states display helpful messages

---

### 12. ✅ Loading States

**What to test**: Loading indicators during async operations

**Steps**:
1. Open **Pending** tab
2. Should briefly show **loading spinner** while fetching
3. After data loads, spinner disappears
4. During Accept/Decline, button shows loading indicator
5. After operation completes, button state resets

**Expected Result**: ✅ Loading indicators appear and clear appropriately

---

## 📴 Offline Testing

### What to Test: Offline Caching

**Prerequisites**:
- View pending invitations while connected
- Connection working and data loaded

**Steps**:
1. **Online**: View pending invitations (data loads)
2. **Offline**: Disconnect emulator from internet
   - In Android: Open Settings > Network & Internet > Airplane Mode ON
3. Push app to background and open it again
4. Navigate to Pending tab
5. Should see **cached invitations** even though offline
6. Try to Accept/Decline:
   - Buttons may show loading
   - Action queued for when back online
   - See message: **"Action queued - will retry when online"** (if implemented)
7. **Back Online**: Re-enable internet
   - App auto-syncs
   - Cached actions execute
   - UI updates once operations complete

**Expected Result**: ✅ App works offline with cache, syncs when reconnected

---

### What to Test: Offline Action Queue

**Steps**:
1. Go offline (airplane mode)
2. Try to send a new invitation:
   - User picker works offline (from cache or empty)
   - Send button clickable
   - Action queued (see message or badge)
3. Try to Accept pending invitation
   - Accept button works
   - Action queued
4. Go back online
5. See actions execute in sequence
6. UI updates with results

**Expected Result**: ✅ Operations queue offline, execute online

---

## 🔔 Push Notifications Testing

### What to Test: Push Notification Badge

**Prerequisites**:
- Firebase configured on emulator
- Another user account ready

**Steps**:
1. Open app in **Invitations > Pending** tab
2. Badge shows current count: **Pending (2)**
3. Another user sends you invitation
4. Without refreshing, badge should update automatically
5. If app is in background:
   - Notification appears in system tray
   - Tap notification
   - App opens to Invitations screen
   - Pending tab shows new invitation

**Expected Result**: ✅ Push notifications deliver and update badges

---

### What to Test: Deep Linking from Notification

**Steps**:
1. Go to home screen (app in background)
2. Another user sends you invitation
3. Push notification appears in status bar
4. Tap the notification
5. App opens and navigates to **Invitations > Pending** tab
6. New invitation visible immediately

**Expected Result**: ✅ Deep link routes to correct screen

---

## ⚙️ Performance Testing

### What to Test: Response Time (Accept/Decline)

**Steps**:
1. Open Pending invitations (with 5+ pending)
2. Tap Accept on first invitation
3. Measure time from tap to success message
4. Should be **< 2 seconds** (ideally < 1 second)
5. Repeat for other invitations

**Expected Result**: ✅ Operations complete within 2 seconds

---

### What to Test: UI Responsiveness

**Steps**:
1. Have 20+ pending invitations
2. Scroll through list smoothly
3. Tap Accept/Decline rapidly on multiple items
4. App should handle without stuttering or freezing
5. All operations complete eventually

**Expected Result**: ✅ Smooth UI even with many items

---

## 🐛 Error Recovery Testing

### What to Test: Network Error Recovery

**Prerequisites**:
- Emulator has network access
- App running

**Steps**:
1. Disconnect emulator network (Airplane Mode ON)
2. Try to Accept an invitation
3. See error: **"Network error"** or **"No connection"**
4. Error dialog shows **Retry** button
5. Re-enable network (Airplane Mode OFF)
6. Tap **Retry** in error dialog
7. Operation succeeds
8. Dialog closes

**Expected Result**: ✅ Error dialog with retry recovers gracefully

---

### What to Test: Server Error (500)

**Prerequisites**:
- Stop backend server (if possible)
- OR force server error scenario

**Steps**:
1. Try to Accept invitation
2. See error: **"Server error"** or **"500"**
3. Error dialog appears with details
4. Tap **Retry**
5. Same error again (backend still down)
6. Tap **OK** to close

**Expected Result**: ✅ Error handling doesn't crash

---

## 🔐 Permission Testing (Android)

### What to Test: Contacts Permission (if used)

**Steps**:
1. Open app for first time
2. If prompted for permissions (Contacts, Calendar, etc.):
   - Tap **Allow** or **Deny**
   - App should work either way
3. App continues to function

**Expected Result**: ✅ Permission dialogs don't break functionality

---

### What to Test: Push Notification Permission

**Steps**:
1. Open app for first time
2. If prompted: **"Mobile Messenger wants to send you notifications"**
3. Tap **Allow**
4. Should enable push notifications
5. Send invitation from another user
6. Notification should deliver

**Expected Result**: ✅ Notification permission granted, notifications work

---

## 📝 Test Data Scenarios

### Scenario 1: Rapid Invitations

**Steps**:
1. Send 5 invitations to different users in quick succession
2. Check **Sent** tab
3. All 5 should appear with **Pending** status
4. Verify count is accurate

---

### Scenario 2: Bulk Accept

**Steps**:
1. Have 10+ pending invitations
2. Accept them in rapid succession (tap Accept repeatedly)
3. Each should complete and remove from list
4. Count decrements each time
5. No errors or duplicates after completion

---

### Scenario 3: Mixed Operations

**Steps**:
1. Have 3 pending invitations (A, B, C)
2. Accept A
3. Decline B
4. Accept C
5. All should complete without interference
6. Pending list shows only B remaining, then none

---

## 🔄 State Management Testing

### What to Test: Tab Switching

**Steps**:
1. Open **Pending** tab (load data)
2. Switch to **Sent** tab (load different data)
3. Switch back to **Pending**
4. Data should still be there (cached)
5. Should not reload

**Expected Result**: ✅ State preserved when switching tabs

---

### What to Test: Refresh on Return

**Steps**:
1. Open Invitations screen
2. Go to home, open another app
3. Return to Invitations app (foreground)
4. Data should refresh automatically (if new invites sent)
5. Badge count updates if new data

**Expected Result**: ✅ App refreshes when coming to foreground

---

## 📋 Issues to Watch For

### ❌ Red Flags (If you see these, note them)

1. **App Crashes**
   - Note the error in logcat: `flutter logs`
   - Screenshot the error
   - Report with steps to reproduce

2. **Stuck Loading States**
   - Spinner never completes
   - Button disabled indefinitely
   - Force close and restart: `r` key (hot reload) or `q` (quit)

3. **Data Mismatches**
   - Badge shows wrong count
   - Invitation disappears but wasn't accepted
   - Sent/Pending showing same invitations

4. **Missing Notifications**
   - Send invitation, no notification
   - Check: Is push notification permission enabled?
   - Check: Is backend running?

5. **Offline Issues**
   - Can't access cached data offline
   - Actions don't queue
   - Doesn't sync when back online

---

## 🔧 Debugging Commands

### View Logs
```bash
# Terminal 2 (while app is running)
flutter logs
```

**What to look for**:
- `[InvitationsScreen]` messages
- `[OfflineActionQueue]` for offline operations
- Errors or warnings

---

### Hot Reload During Testing
```bash
# While app is running, press 'r' in terminal
r
# App rebuilds and reloads (preserves state)
```

---

### Restart App
```bash
# While app is running, press 'R' in terminal
R
# Full app restart (clears state)
```

---

### View Database (via Backend)
```bash
# Terminal (in /home/katikraavi/mobile-messenger/backend)
psql -U messenger_user -d messenger_db -h localhost

# View pending invitations
SELECT id, sender_id, recipient_id, status, created_at FROM chat_invitations 
WHERE status = 'pending' ORDER BY created_at DESC;

# View accepted chats
SELECT id, invitation_id FROM chats WHERE invitation_id IS NOT NULL;
```

---

## ✅ Test Completion Checklist

After testing, mark these off:

- [ ] App launches without crashing
- [ ] Can navigate to Invitations screen
- [ ] Can send invitation to another user
- [ ] Invitation appears in recipient's Pending tab
- [ ] Can accept invitation
- [ ] Chat is created after accept
- [ ] Can decline invitation
- [ ] Sent invitations display with correct status
- [ ] Badge count updates correctly
- [ ] Error dialogs show for invalid operations
- [ ] Offline mode caches data
- [ ] Offline queue queues actions
- [ ] Sync happens when reconnected
- [ ] Push notifications deliver
- [ ] No crashes or hangs
- [ ] UI is responsive with multiple items
- [ ] Loading states show/hide appropriately
- [ ] Empty states display when no data

---

## 📞 Troubleshooting

### Issue: App won't launch
**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

### Issue: "No connected devices"
**Solution**: Start emulator first
```bash
emulator -avd Pixel_5_API_31
# Wait 1-2 min for boot, then flutter run
```

### Issue: "Unsupported operation: DefaultFirebaseOptions have not been configured for linux"
**Solution**: This is normal on Linux. Testing requires Android/iOS:
```bash
# Don't use flutter run on Linux for Firebase features
# Use emulator or device instead
emulator -avd Pixel_5_API_31
flutter run
```

### Issue: Notification not showing
**Solution**: Check permissions
```bash
# In emulator, go to Settings > Notifications > Mobile Messenger
# Ensure notifications are enabled
```

### Issue: No pending invitations showing
**Solution**: 
- Ensure backend is running
- Ensure another user sent you an invitation
- Try refresh: hot reload (`r`) or restart (`R`)
- Check logs: `flutter logs`

---

## 📊 Expected Feature Set

All these should work on the emulator:

✅ Send invitations to other users  
✅ View pending invitations with badges  
✅ Accept/decline invitations  
✅ View sent invitations with status  
✅ Error handling for invalid operations  
✅ Real-time badge updates  
✅ Empty state displays  
✅ Loading indicators  
✅ Offline caching (if configured)  
✅ Push notifications (with Firebase)  
✅ Smooth UI with many items  

---

## 🎯 Next Steps

1. **Start Emulator**: `emulator -avd Pixel_5_API_31`
2. **Run App**: `cd frontend && flutter run`
3. **Follow Test Cases**: Use sections above
4. **Note Issues**: Write down anything that doesn't work as expected
5. **Check Logs**: `flutter logs` if you see errors
6. **Report Findings**: Include steps to reproduce any issues

---

**Happy testing! 🚀**

Questions or issues? Check the logs with `flutter logs` or review `TROUBLESHOOTING.md` in the specs directory.
