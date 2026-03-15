# Quick Reference - Emulator Setup & Testing

## 🚀 3-Minute Setup

### Terminal 1: Start Emulator
```bash
emulator -avd Pixel_5_API_31
# Wait for boot (see Android home screen, ~1-2 min)
```

### Terminal 2: Launch App
```bash
cd /home/katikraavi/mobile-messenger/frontend

flutter clean
flutter pub get
flutter run
```

### Expected Result
```
✓ Built build/linux/x64/debug/bundle/frontend
✓ App launches on emulator
```

---

## 🧪 Core Test Cases (Quick)

### Test 1: Send Invitation (2 min)
1. **Tap** send button (+ icon)
2. **Search** for a user
3. **Select** user and tap Send
4. ✅ See "Invitation sent successfully!"

### Test 2: Accept Invitation (2 min)
1. **Pending tab** shows invitation
2. **Tap Accept** (checkmark button)
3. ✅ See "Invitation accepted! Chat created."
4. ✅ Invitation disappears
5. ✅ Badge count decreases

### Test 3: Decline Invitation (2 min)
1. **Pending tab** shows invitation
2. **Tap Decline** (X button)
3. ✅ See "Invitation declined"
4. ✅ Invitation removed

### Test 4: View Sent (1 min)
1. **Tap Sent tab**
2. ✅ See invitations you sent
3. ✅ Status shows: pending/accepted/declined

**Total: ~7 minutes for all basic tests**

---

## 🔑 Keyboard Shortcuts (While App Running)

| Key | Action |
|-----|--------|
| **r** | Hot reload (reload code) |
| **R** | Hot restart (full restart) |
| **q** | Quit app |
| **d** | Detach (leave running) |

---

## 🔧 If Something Goes Wrong

### App Won't Start
```bash
# Step 1: Clean
flutter clean

# Step 2: Get deps
flutter pub get

# Step 3: Run
flutter run
```

### No Device Found
```bash
# Restart emulator
emulator -avd Pixel_5_API_31

# Or use Android Studio:
# Open Device Manager > Launch a device
```

### App Crashes on Launch
```bash
# Check logs
flutter logs

# Look for ERROR lines and note them
```

### Notification Not Working
```bash
# Check in emulator:
# Settings > Notifications > Mobile Messenger
# Ensure "Allow" is toggled ON
```

---

## 📊 Expected Behavior by Feature

### ✅ Sending Invitations
- Opens user picker
- Shows loading while sending
- Displays success message
- Returns to Invitations screen

### ✅ Viewing Pending
- Shows inviter's name and avatar
- Shows timestamp ("2 hours ago")
- Badge shows count (e.g., "Pending (3)")
- Accept/Decline buttons visible

### ✅ Accepting
- Button shows loading indicator
- Succeeds within 1-2 seconds
- Shows success snackbar
- Invitation removed from list
- Chat created

### ✅ Declining
- Button shows loading
- Shows confirmation message
- Invitation removed
- Count badge updates

### ✅ Sent Tab
- Lists all invitations you sent
- Shows status (pending, accepted, declined)
- Status has color coding (orange, green, red)

### ✅ Error Handling
- Duplicate attempts show error (red dialog)
- Self-invite blocked
- Already chatting warning
- "Retry" button in error dialogs

### ✅ Badge Updates
- Shows in tab: "Pending (X)"
- Updates immediately when new invite arrives
- Decrements when you accept/decline
- Accurate at all times

---

## 📝 Test Log Template

Use this to track your testing:

```
TEST SESSION: [Date]
Device: [Android/iOS version]

Sent Invitation:
  [ ] User picker opens
  [ ] Can search for users
  [ ] Can select user
  [ ] Send button works
  [ ] Success message shows
  Status: PASS / FAIL
  Notes: _______________

Pending Invitations:
  [ ] Invitation appears in list
  [ ] Shows sender name
  [ ] Shows timestamp
  [ ] Badge count is correct
  Status: PASS / FAIL
  Notes: _______________

Accept Invitation:
  [ ] Accept button works
  [ ] Shows loading
  [ ] Success message displays
  [ ] Invitation removed
  [ ] Badge decrements
  [ ] Chat created
  Status: PASS / FAIL
  Notes: _______________

Decline Invitation:
  [ ] Decline button works
  [ ] Shows confirmation
  [ ] Invitation removed
  [ ] Badge decrements
  Status: PASS / FAIL
  Notes: _______________

Sent Tab:
  [ ] Shows sent invitations
  [ ] Shows status correctly
  [ ] Status colors correct
  Status: PASS / FAIL
  Notes: _______________

Error Handling:
  [ ] Duplicate error works
  [ ] Self-invite blocked
  [ ] Retry button works
  Status: PASS / FAIL
  Notes: _______________

Overall Status: ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
Issues Found: _______________
```

---

## 🎯 Success Criteria

✅ **PASS** if:
- App launches without crashes
- All 4 core tests pass (send, accept, decline, view sent)
- Error handling shows proper messages
- Badge updates correctly
- No freezing or stuttering

⚠️ **PARTIAL** if:
- Most tests pass
- One or two issues found
- Can work around them

❌ **FAIL** if:
- App crashes on launch
- Core features don't work
- Cannot accept/decline

---

## 📞 Quick Debugging

### See Logs
```bash
# In new terminal while app is running
flutter logs
```
Look for lines starting with `[Invitations]` to see feature-specific logs.

### Reload Hot
```
# Press 'r' while app is running
r
```
Code reloads instantly (state preserved).

### Full Restart
```
# Press 'R' while app is running
R
```
App fully restarts (state cleared).

### Database Check (Optional)
```bash
cd /home/katikraavi/mobile-messenger/backend

# Connect to database
psql -U messenger_user -d messenger_db -h localhost

# See pending invitations
SELECT id, sender_id, recipient_id, status, created_at 
FROM chat_invitations 
WHERE status = 'pending' 
ORDER BY created_at DESC;

# Exit
\q
```

---

## 🚨 Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| **"No devices found"** | Start emulator first: `emulator -avd Pixel_5_API_31` |
| **"Build failed"** | Run `flutter clean` and retry |
| **"App won't respond"** | Press `R` for restart or `q` to quit |
| **"No notification"** | Check emulator Settings > Notifications > toggle ON |
| **"Stuck on loading"** | Hot reload (`r`) or restart (`R`) |
| **"Invite not appearing"** | Check backend is running, then hot reload (`r`) |
| **"Wrong data showing"** | Restart app: `R` key |

---

## 💡 Pro Tips

1. **Keep Terminal Open**: Shows logs in real-time as you test
2. **Use Hot Reload**: Press `r` to test changes instantly
3. **Check Logs First**: `flutter logs` before reporting issues
4. **Try Restart**: Many issues fixed by `R` (full restart)
5. **Check Backend**: Invitations require backend API running
6. **Emulator Speed**: First run takes ~2 min, after that ~30 sec

---

## 🔗 Reference Documents

After emulator testing, read:
- [EMULATOR_TESTING_GUIDE.md](./EMULATOR_TESTING_GUIDE.md) - Full detailed guide
- [specs/017-chat-invitations/QA_TEST_PLAN.md](./specs/017-chat-invitations/QA_TEST_PLAN.md) - Comprehensive test cases
- [specs/017-chat-invitations/USER_GUIDE.md](./specs/017-chat-invitations/USER_GUIDE.md) - Feature guide for users

---

**Start Testing Now:**
```bash
emulator -avd Pixel_5_API_31 &
cd /home/katikraavi/mobile-messenger/frontend && flutter run
```

**Happy testing! 🚀**
