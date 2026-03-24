# Chat Invitations - QA Manual Test Plan

## Overview

This document defines manual QA test cases for the Chat Invitations feature. Tests are organized by user story with detailed steps, expected results, and pass/fail criteria.

---

## Test Scope

**Feature**: Chat Invitations (017-chat-invitations)  
**Platforms**: Android, iOS, Web (Desktop)  
**Test Environment**: Development with docker-compose  
**Devices**: Physical + Emulator  
**Browsers**: Chrome, Safari (web)

---

## Prerequisites

- [ ] Backend running: `docker-compose up -d`
- [ ] Frontend app running on device/emulator
- [ ] 2+ test user accounts created
- [ ] Device tokens configured
- [ ] Firebase configured (for push notifications)
- [ ] Test data reset (clean database)

---

## Test Environment Setup

### Create Test Users

```bash
# Login to app with test accounts:
User A: test_alice@example.com / password123
User B: test_bob@example.com / password123
User C: test_charlie@example.com / password123
```

### Reset Database (if needed)

```bash
docker-compose down -v
docker-compose up -d
# Create new test users via app
```

---

## User Story 1: Send Chat Invitation

### Test Case 1.1 - Send Invitation via Search

**Objective**: User can send invitation through search interface

**Steps**:
1. Login as User A
2. Navigate to Invitations tab
3. Tap "Send New Invite" button
4. Search for "test_bob"
5. Tap on Bob's user in results
6. Tap "Send Invite" button
7. Observe confirmation message

**Expected Result**:
- ✅ Bob appears in search results
- ✅ Can select Bob's user
- ✅ "Send Invite" button becomes enabled
- ✅ Notification show: "Invitation sent successfully!"
- ✅ SendInvitePickerScreen closes
- ✅ Back to InvitationsScreen

**Pass Criteria**: All expected results occur without errors

---

### Test Case 1.2 - Cannot Send to Self

**Objective**: User cannot send invitation to their own account

**Steps**:
1. Login as User A
2. Navigate to Invitations tab
3. Tap "Send New Invite" button
4. Search for "test_alice" (self)
5. Observe search results

**Expected Result**:
- ✅ Own user does NOT appear in search results
- OR shows with "Send Invite" button disabled

**Pass Criteria**: Self-invite is prevented

---

### Test Case 1.3 - Cannot Send to Existing Contact

**Objective**: Cannot send invitation to users already chatting with

**Steps**:
1. Create chat between User A and User C (manually in database or app)
2. Login as User A
3. Navigate to Invitations tab
4. Tap "Send New Invite" button
5. Search for "test_charlie"
6. Try to select Charlie

**Expected Result**:
- ✅ Charlie may appear in search but "Send Invite" button is disabled
- OR error dialog: "Users already have a chat"

**Pass Criteria**: Existing contacts are blocked from invites

---

### Test Case 1.4 - Cannot Send Duplicate Pending

**Objective**: Cannot send multiple pending invitations to same user

**Steps**:
1. Login as User A
2. Send invitation to User B (Test 1.1)
3. Go back to Send Invite screen
4. Search for test_bob
5. Try to send another invitation
6. Observe error message

**Expected Result**:
- ✅ Error dialog appears
- ✅ Message: "Pending invitation already exists"
- ✅ Can't send second invitation

**Pass Criteria**: Duplicate prevention works

---

### Test Case 1.5 - Send Invite Offline (Offline Queue)

**Objective**: Invitation can be queued when offline

**Steps** (requires network control):
1. Turn off WiFi/cellular
2. Login as User A (should still be logged in from cache)
3. Navigate to Invitations
4. Tap "Send New Invite"
5. Search for User D
6. Tap Send
7. Observe result

**Expected Result** (Ideal behavior):
- ✅ Error dialog OR
- ✅ "Offline - will retry when online" message OR
- ✅ Action queued in offline queue

**Acceptable Result**:
- Network error shown

**Pass Criteria**: Graceful handling of offline state

---

## User Story 2: View Pending Invitations

### Test Case 2.1 - View Pending Tab

**Objective**: Can view received pending invitations

**Steps**:
1. Login as User B
2. Navigate to Invitations tab
3. Verify you're on "Pending Invitations" tab
4. Should see invitation from User A (from Test 1.1)

**Expected Result**:
- ✅ Pending tab is active (highlighted)
- ✅ List shows invitation from User A
- ✅ Shows User A's name and avatar
- ✅ Shows timestamp "just now" or relative time
- ✅ Shows "Accept" and "Decline" buttons

**Pass Criteria**: Pending invitations display correctly

---

### Test Case 2.2 - Invitation Badge Count

**Objective**: Badge shows count of pending invitations

**Steps**:
1. Login as User C who has 2 pending invitations
2. Look at Invitations tab in navigation

**Expected Result**:
- ✅ Badge shows "2" on Invitations tab
- ✅ Badge is red and visible

**Pass Criteria**: Badge count is accurate

---

### Test Case 2.3 - Empty Pending List

**Objective**: Empty state shows when no pending invitations

**Steps**:
1. Login as new User D with no invitations
2. Navigate to Invitations tab
3. Look at Pending tab

**Expected Result**:
- ✅ Empty state message shows
- ✅ Message: "No pending invitations"
- ✅ Can still tap "Send New Invite"

**Pass Criteria**: Empty state displays correctly

---

### Test Case 2.4 - Refresh Pending List

**Objective**: Can refresh to get latest pending invitations

**Steps**:
1. Login as User B
2. View pending invitations
3. Pull down to refresh
4. Observe list update

**Expected Result**:
- ✅ Pull-to-refresh works
- ✅ Loading indicator shows briefly
- ✅ List refreshes with latest data

**Pass Criteria**: Refresh functionality works

---

## User Story 3: Accept Invitation

### Test Case 3.1 - Accept Invitation

**Objective**: User can accept received invitation

**Steps**:
1. Login as User B
2. View pending invitations
3. Find invitation from User A
4. Tap "Accept" button
5. Observe result

**Expected Result**:
- ✅ Loading indicator on button while processing
- ✅ Success message: "Invitation accepted!"
- ✅ Invitation removed from pending list
- ✅ Chat created between User A and User B

**Pass Criteria**: Invitation accepted and chat created

---

### Test Case 3.2 - Accept on Unstable Network

**Objective**: Accept works with network latency

**Steps**:
1. Simulate slow network (Charles Proxy, throttle to 50ms latency)
2. Login as User B
3. Tap Accept on invitation
4. Wait for response

**Expected Result**:
- ✅ Loading indicator shows
- ✅ Eventually succeeds or shows error
- ✅ No crash or timeout

**Pass Criteria**: Handles latency gracefully

---

### Test Case 3.3 - Accept Twice

**Objective**: Cannot accept same invitation twice

**Steps**:
1. User B accepts invitation from User A
2. Refresh page
3. Invitation no longer exists
4. Try to find and accept again

**Expected Result**:
- ✅ Invitation not in pending list
- ✅ Error if trying to accept non-existent: "Invitation not found"

**Pass Criteria**: Double-accept prevented

---

### Test Case 3.4 - Accept Error Dialog

**Objective**: Error messages are clear if accept fails

**Steps**:
1. Turn off network
2. Try to accept invitation
3. Observe error handling

**Expected Result**:
- ✅ Error dialog appears
- ✅ Clear message about what went wrong
- ✅ "Retry" button to try again
- ✅ Can dismiss and try later

**Pass Criteria**: Error UX is good

---

## User Story 4: Decline Invitation

### Test Case 4.1 - Decline Invitation

**Objective**: User can decline received invitation

**Steps**:
1. Login as User B with invitation from User A
2. Tap "Decline" button on invitation
3. Observe result

**Expected Result**:
- ✅ Loading indicator shows
- ✅ Success message: "Invitation declined"
- ✅ Invitation removed from pending list
- ✅ NO chat created

**Pass Criteria**: Invitation declined without creating chat

---

### Test Case 4.2 - Can Receive New Invitation After Decline

**Objective**: User can receive new invitation after declining

**Steps**:
1. User B declines invitation from User A (Test 4.1)
2. User A sends new invitation to User B
3. Observe User B's pending list

**Expected Result**:
- ✅ New invitation appears
- ✅ No "duplicate" error
- ✅ Can accept or decline this one

**Pass Criteria**: Re-inviting after decline works

---

### Test Case 4.3 - Decline Error Handling

**Objective**: Error handling for decline failures

**Steps**:
1. Disconnect network
2. Tap Decline
3. Observe error

**Expected Result**:
- ✅ Error dialog shows
- ✅ "Retry" button available
- ✅ Can retry when network restored

**Pass Criteria**: Error handling works

---

## User Story 5: View Sent Invitations

### Test Case 5.1 - View Sent Tab

**Objective**: Can view sent invitations tab

**Steps**:
1. Login as User A (who sent a request to User B)
2. Navigate to Invitations tab
3. Switch to "Sent Invitations" tab
4. Observe list

**Expected Result**:
- ✅ Sent tab shows invitation to User B
- ✅ Shows User B's name
- ✅ Shows status "Pending" (in yellow/orange)
- ✅ Shows when it was sent

**Pass Criteria**: Sent invitations display correctly

---

### Test Case 5.2 - Sent Invitation Status Updates

**Objective**: Sent invitation status updates when recipient acts

**Steps**:
1. User A sends invitation to User B
2. User A views Sent tab (status: "Pending")
3. User B accepts invitation
4. User A refreshes Sent tab

**Expected Result**:
- ✅ Status changes to "Accepted" (green)
- ✅ Shows update timestamp

**Pass Criteria**: Status updates are live

---

### Test Case 5.3 - Pending vs Accepted Status Styling

**Objective**: Different statuses have different visual indication

**Steps**:
1. Login as User A
2. View Sent tab with multiple invitations in different statuses
3. Observe styling

**Expected Result**:
- ✅ Pending invitation: Yellow/Orange badge
- ✅ Accepted invitation: Green badge
- ✅ Declined invitation: Gray badge
- ✅ Color coding is consistent

**Pass Criteria**: Visual status differentiation works

---

## Push Notifications

### Test Case 6.1 - Receive Notification on New Invite

**Objective**: User gets push notification when invited

**Prerequisites**: Firebase configured and push notifications enabled

**Steps**:
1. User A sends invitation to User B
2. User B's device is on lock screen or app is closed
3. Wait for notification

**Expected Result**:
- ✅ Notification appears on device
- ✅ Title: "Chat Invitation"
- ✅ Message: "New chat invitation from [User A name]"
- ✅ Badge appears on app icon

**Pass Criteria**: Notification received

---

### Test Case 6.2 - Tap Notification Routes to Invitations

**Objective**: Tapping notification opens app at invitations

**Steps**:
1. Receive notification (Test 6.1)
2. App is closed
3. Tap notification
4. Observe app behavior

**Expected Result**:
- ✅ App opens
- ✅ Navigates to Invitations screen
- ✅ Pending tab is active
- ✅ New invitation visible in list

**Pass Criteria**: Deep link routing works

---

### Test Case 6.3 - Foreground Notification Display

**Objective**: Notification shows when app is open

**Steps**:
1. Open app as User B
2. Go to home screen or non-Invitations screen
3. User A sends invitation to User B
4. Observe result

**Expected Result** (Depending on implementation):
- ✅ Snackbar appears with invitation info, OR
- ✅ System notification appears even though app is open
- ✅ Can tap to go to invitations

**Pass Criteria**: Foreground notification handling works

---

## Offline Support

### Test Case 7.1 - View Cached Invitations Offline

**Objective**: Can view cached invitations when offline

**Steps**:
1. Login as User B with pending invitations
2. Close app
3. Turn off WiFi/Cellular
4. Open app

**Expected Result**:
- ✅ App shows "Offline Mode"
- ✅ Cached pending invitations display
- ✅ Can see invitation list (may show "stale data" indicator)

**Acceptable Result**:
- Empty list if no cache
- Prompt to go online

**Pass Criteria**: Offline fallback works

---

### Test Case 7.2 - Accept Queued When Offline

**Objective**: Accept action queues and retries when online

**Steps**:
1. Turn off network
2. Try to accept invitation
3. Observe behavior

**Expected Result** (Ideally):
- ✅ Action queued, "Will retry when online"
- ✅ Turn on network
- ✅ Accept processes automatically
- ✅ Success message appears

**Acceptable Result**:
- Error shown, retry when online

**Pass Criteria**: Offline action handling works

---

## Cross-Platform Testing

### Test Case 8.1 - Android Functionality

**Platform**: Android phone/emulator

**Steps**:
1. Run through all Test Cases 1.1-7.2 on Android

**Expected Result**:
- ✅ All tests pass
- ✅ No crashes
- ✅ Proper notifications and badges

**Pass Criteria**: Android fully functional

---

### Test Case 8.2 - iOS Functionality

**Platform**: iOS phone/emulator

**Steps**:
1. Run through all Test Cases 1.1-7.2 on iOS

**Expected Result**:
- ✅ All tests pass
- ✅ No crashes
- ✅ Proper notifications and badges

**Pass Criteria**: iOS fully functional

---

### Test Case 8.3 - Web/Desktop Functionality

**Platform**: Web browser (Chrome/Safari)

**Steps**:
1. Run app in web browser
2. Run Test Cases 1.1, 2.1, 3.1, 4.1, 5.1

**Expected Result**:
- ✅ Core functionality works
- ✅ No layout issues
- ✅ Buttons responsive

**Note**: Push notifications not applicable on web

**Pass Criteria**: Web version functional

---

## Edge Cases

### Test Case 9.1 - Rapid Accept/Decline Clicks

**Objective**: Handle rapid button clicks

**Steps**:
1. User B sees pending invitations
2. Rapidly click Accept multiple times
3. Observe behavior

**Expected Result**:
- ✅ First request processes
- ✅ Subsequent clicks ignored (button disabled)
- ✅ No duplicate actions
- ✅ No errors

**Pass Criteria**: Concurrent requests prevented

---

### Test Case 9.2 - Network Interruption During Accept

**Objective**: Handle network failure mid-request

**Steps** (with network control):
1. Tap Accept
2. Immediately turn off network
3. Observe error handling

**Expected Result**:
- ✅ Error dialog appears
- ✅ Invitation still in list (not deleted prematurely)
- ✅ Can retry

**Pass Criteria**: Transaction safety maintained

---

### Test Case 9.3 - Search with Many Users

**Objective**: Search performance with large user database

**Steps**:
1. Database has 1000+ users
2. Open Send Invite screen
3. Search for "test"
4. Observe performance

**Expected Result**:
- ✅ Search completes in < 1 second
- ✅ No crashes
- ✅ Results display properly

**Pass Criteria**: Performance acceptable

---

## Performance & Load Testing

### Test Case 10.1 - Load Pending with 100 Invitations

**Objective**: Handle large pending invitations list

**Setup**:
1. Create 100 pending invitations for User B

**Steps**:
1. Login as User B
2. View pending invitations list
3. Scroll through entire list

**Expected Result**:
- ✅ List loads within 2 seconds
- ✅ Scrolling is smooth (60 FPS)
- ✅ No memory leaks

**Pass Criteria**: Performance acceptable

---

### Test Case 10.2 - Accept/Refresh Cycle

**Objective**: App remains responsive after repeated actions

**Steps**:
1. Create 10 pending invitations
2. Accept all, refreshing between each
3. Monitor performance

**Expected Result**:
- ✅ App remains responsive
- ✅ No slowdown over time
- ✅ Memory usage stable

**Pass Criteria**: No performance degradation

---

## Security Tests

### Test Case 11.1 - Cannot Access Other User's Pending Invites

**Objective**: Users can't see others' invitations via API

**Steps** (requires API testing):
1. Login as User A (get JWT token)
2. Try to call GET /api/invites/pending with User B's userId
3. Observe response

**Expected Result**:
- ✅ Gets own pending, not User B's
- ✅ No unauthorized data access

**Pass Criteria**: Authorization enforced

---

### Test Case 11.2 - Cannot Accept Other User's Invited

**Objective**: Can't accept invitation meant for someone else

**Steps**:
1. Invitation exists from User A to User B
2. Login as User C (different user)
3. Try to accept User B's invitation (via API or directly)

**Expected Result**:
- ✅ Error: "Forbidden" or access denied
- ✅ Cannot accept other user's invitations

**Pass Criteria**: Authorization enforced

---

## Bug Report Template

If issues found during testing:

```markdown
### Bug #[NUMBER]: [Title]

**Severity**: Critical | High | Medium | Low

**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Result**:


**Actual Result**:


**Screenshots/Video**: [Attach]

**Environment**:
- Platform: iOS | Android | Web
- Device: [Device model]
- OS Version: [Version]
- App Version: [Version]

**Additional Notes**:
```

---

## Test Completion Criteria

**MVP Release Ready** when:
- ✅ All Test Cases 1.1-8.3 pass on all platforms
- ✅ No critical/high severity bugs open
- ✅ Performance meets targets (< 2s load, smooth scrolling)
- ✅ Push notifications working
- ✅ Offline support tested

**Phase 6 Complete** when:
- ✅ All manual testing done
- ✅ Automated tests passing
- ✅ Performance optimization verified
- ✅ Documentation complete
- ✅ Release build created

---

## Sign-Off

| Role | Name | Date | Status |
|------|------|------|--------|
| QA Lead | ________ | ________ | ☐ Pass |
| Dev Lead | ________ | ________ | ☐ Pass |
| Product | ________ | ________ | ☐ Approved |

---

Generated: March 15, 2026  
Feature: Chat Invitations (017-chat-invitations)  
Status: Ready for Manual QA
