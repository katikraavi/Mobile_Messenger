# Feature Behavior Reference - What You'll See

Use this to verify the app is working correctly as you test.

---

## 📱 The Invitations Screen

### ✅ Pending Tab (Receiving Invitations)

**What You'll See:**
```
┌─────────────────────────────────────┐
│  Invitations                 [+ Add] │
├─────────────────────────────────────┤
│ [Pending (3)] │ Sent               │
├─────────────────────────────────────┤
│                                     │
│  [👤 Alice] Alice Smith             │
│  2 hours ago                        │
│  [✅ Accept]  [❌ Decline]          │
│                                     │
│  [👤 Bob] Bob Johnson               │
│  5 hours ago                        │
│  [✅ Accept]  [❌ Decline]          │
│                                     │
│  [👤 Charlie] Charlie Brown         │
│  1 day ago                          │
│  [✅ Accept]  [❌ Decline]          │
│                                     │
└─────────────────────────────────────┘
```

**Key Details**:
- **Badge**: Shows "Pending (3)" - update immediately when new invite arrives
- **Avatar**: User's profile picture
- **Name**: Full name of person who sent invite
- **Time**: "2 hours ago", "5 hours ago", "1 day ago"
- **Buttons**: Green checkmark (accept), Red X (decline)

**Interactions**:
- Tap a name: May show user profile
- Tap Accept: Button shows loading spinner → "Invitation accepted! Chat created." → Invite disappears
- Tap Decline: Button shows loading → "Invitation declined" → Invite disappears

---

### ❌ Pending Tab (Empty)

**What You'll See:**
```
┌─────────────────────────────────────┐
│  Invitations                 [+ Add] │
├─────────────────────────────────────┤
│ [Pending] │ Sent                    │
├─────────────────────────────────────┤
│                                     │
│         📬 (empty icon)             │
│                                     │
│   "No Pending Invitations"          │
│                                     │
│   You don't have any pending        │
│   invitations. When someone         │
│   sends you an invite, it will      │
│   appear here.                      │
│                                     │
└─────────────────────────────────────┘
```

**Key Details**:
- **No badge** on Pending tab (or shows "(0)")
- Empty state message is helpful
- Mail icon indicates invitations

---

### 💌 Sent Tab (Your Sent Invitations)

**What You'll See:**
```
┌─────────────────────────────────────┐
│  Invitations                 [+ Add] │
├─────────────────────────────────────┤
│ Pending │ [Sent]                    │
├─────────────────────────────────────┤
│                                     │
│  [👤 Alice] Alice Smith             │
│  Mar 15, 2:30 PM    ✅ ACCEPTED    │
│                                     │
│  [👤 Bob] Bob Johnson               │
│  Mar 15, 1:00 PM    ⏳ PENDING     │
│                                     │
│  [👤 Eve] Eve Davis                 │
│  Mar 14, 5:00 PM    ❌ DECLINED    │
│                                     │
└─────────────────────────────────────┘
```

**Key Details - Status Colors**:
- **Accepted**: ✅ Green checkmark (Alice accepted your invite)
- **Pending**: ⏳ Orange/gray pending icon (Bob hasn't responded)
- **Declined**: ❌ Red X (Eve declined your invite)

**Timestamps**:
- Full date and time: "Mar 15, 2:30 PM"
- Shows when you sent the invite

---

## 🎯 Send New Invite Flow

### Step 1: Tap the "+" Button
**What You'll See:**
- Screen changes to **SendInvitePickerScreen**
- Title: "Select User to Invite"
- Search box at top: "Search users..."
- List of available users below

```
┌─────────────────────────────────────┐
│  Select User to Invite         [←]  │
├─────────────────────────────────────┤
│ 🔍 Search users...                  │
├─────────────────────────────────────┤
│                                     │
│  [👤 Alice] Alice Smith     ☐       │
│  @alice_smith                       │
│                                     │
│  [👤 Bob] Bob Johnson       ☐       │
│  @bob_johnson                       │
│                                     │
│  [👤 Charlie] Charlie Brown ☐       │
│  @charlie_b                         │
│                                     │
│                    [SEND] (grayed)  │
└─────────────────────────────────────┘
```

**Key Details**:
- Search box filters users as you type
- Checkboxes (☐) next to names
- Send button is **grayed out** (disabled) until you select someone

---

### Step 2: Search for User (Optional)
**What You'll See:**
```
Search box: "A___" (you typed "A")

Filtered results:
  [👤 Alice] Alice Smith       ☐
  @alice_smith

  [👤 Alex] Alex Johnson       ☐
  @alex_j
```

**Key Details**:
- List filters as you type
- Shows matching users only
- Can search by name or username

---

### Step 3: Select User
**What You'll See:**
```
Tap on Alice:
  [👤 Alice] Alice Smith       ☑  (checkbox filled)
  @alice_smith

Send button changes:
  [SEND] (now enabled/blue)
```

**Key Details**:
- Checkbox fills when selected (☑ vs ☐)
- Send button becomes **enabled** (blue, clickable)
- Can select multiple users (one at a time or batch)

---

### Step 4: Tap Send
**What You'll See:**

**During sending (1-2 seconds)**:
```
[SEND] (button shows loading spinner)
Please wait...
```

**On Success**:
```
Screen shows:
✅ "Invitation Sent Successfully!"

[OK]
```

Then screen dismisses and returns to Invitations > Pending tab.

**On Failure** (e.g., you already sent her an invite):
```
Error Dialog:
Title: "Send Failed"
Message: "You've already sent an 
          invitation to this user."

[Retry]  [Cancel]
```

You stay on the picker screen, can try another user.

---

## ✅ Accept Invitation Flow

### Before Tapping Accept
```
[👤 Alice] Alice Smith
2 hours ago
[✅ Accept]  [❌ Decline]
```

### While Accepting (Loading)
```
[👤 Alice] Alice Smith
2 hours ago
[⏳ Loading...]  [❌ Decline]
```
- Checkmark button shows spinner
- Decline button stays clickable

### After Accept (Success)
```
✅ "Invitation Accepted! Chat Created."

(Snackbar appears at bottom, auto-disappears after 2 sec)

(Invitation removed from list)
(Badge updates: Pending (2) → Pending (1))
```

---

## ❌ Decline Invitation Flow

### After Tapping Decline
```
⏳ Loading...

(brief spinner)

✅ "Invitation Declined"

(Snackbar shows and disappears)

(Invitation removed from list)
(Badge updates: Pending (3) → Pending (2))
```

---

## 🚨 Error Dialog Examples

### Error: Already Invited This User
```
┌────────────────────────────────┐
│  ⚠️  Send Failed      [×]       │
├────────────────────────────────┤
│                                │
│  You've already sent an         │
│  invitation to this user.       │
│                                │
│                                │
│       [Retry]  [Cancel]        │
└────────────────────────────────┘
```

**Actions**:
- **Retry**: Try sending again (usually same error)
- **Cancel**: Go back to picker

---

### Error: Self Invite
```
┌────────────────────────────────┐
│  ⚠️  Error              [×]     │
├────────────────────────────────┤
│                                │
│  You cannot send an invitation  │
│  to yourself.                   │
│                                │
│                                │
│            [OK]                │
└────────────────────────────────┘
```

---

### Error: Already Chatting
```
┌────────────────────────────────┐
│  ⚠️  Error              [×]     │
├────────────────────────────────┤
│                                │
│  You're already chatting with   │
│  this user.                     │
│                                │
│                                │
│            [OK]                │
└────────────────────────────────┘
```

---

### Error: Network Error
```
┌────────────────────────────────┐
│  ⚠️  Connection Error  [×]      │
├────────────────────────────────┤
│                                │
│  Sorry, we couldn't connect.    │
│  Please check your connection   │
│  and try again.                 │
│                                │
│       [Retry]  [OK]            │
└────────────────────────────────┘
```

**Actions**:
- **Retry**: Try operation again
- **OK**: Close dialog

---

## 🔄 Badge Updates

### Starting State
```
┌─────────────────────────────────────┐
│  Invitations                 [+ Add] │
├─────────────────────────────────────┤
│ [Pending (5)] │ Sent                │
└─────────────────────────────────────┘
```

### Scenario 1: New Invite Arrives (While App Open)
```
Time: 14:30:00 - You have Pending (5)
{App in background}
Time: 14:30:30 - Someone sends you invite

{You return to app}
Pending (6) ← Badge updated automatically!

Notification may also show at top
```

### Scenario 2: You Accept an Invite
```
Before: Pending (5)
You tap Accept on one
During: Button shows loading
After: Pending (4) ← Badge decremented

Invite disappears from list
```

### Scenario 3: You Decline an Invite
```
Before: Pending (5)
You tap Decline on one
After: Pending (4) ← Badge decremented

Invite disappears from list
```

---

## 🔔 Push Notifications (Firebase)

### Notification Arrives
```
(Emulator status bar at top)
┌─────────────────────────────────┐
│ 🔔 Mobile Messenger             │
│ You have a new invitation from  │
│ Alice Smith                     │
└─────────────────────────────────┘
```

### Tap Notification
```
(App opens or comes to foreground)
(Navigation happens automatically)
Lands on: Invitations > Pending tab
(See the new invite from Alice)
```

---

## 📴 Offline Mode

### Offline - View Pending (Cached)
```
(Airplane mode ON)
(Open app, navigate to Invitations)

Pending tab shows:
[👤 Alice] Alice Smith
2 hours ago
[✅ Accept]  [❌ Decline]

✅ Data displays (from cache)
```

### Offline - Try to Accept
```
(Airplane mode ON)
Tap Accept button

Button shows loading: ⏳

After 1-2 sec:
Message: "Action queued - 
          will retry when online"

(Or button completes without error)
```

### Offline - Go Back Online
```
(Airplane mode OFF)

App auto-syncs:
- Queued actions execute
- UI updates with results
- Badge refreshes

✅ "Invitation accepted! Chat created."
(Same as if online)
```

---

## ⏱️ Response Times (Expected)

| Operation | Expected Time | Acceptable |
|-----------|---------------|-----------|
| Send Invite | 1-2 seconds | < 2 sec |
| Accept | 1-2 seconds | < 2 sec |
| Decline | 1-2 seconds | < 2 sec |
| Load Pending | 1-2 seconds | < 2 sec |
| Load Sent | 1-2 seconds | < 2 sec |
| Badge Update | Instant | Real-time |
| Notification | 5-10 seconds | < 30 sec |

---

## 🎨 UI Elements to Verify

### Icons
- **Pending Badge**: Count number (e.g., "5")
- **Accept Button**: ✅ Green checkmark
- **Decline Button**: ❌ Red X
- **Add Button**: ➕ Plus or ➕ Add icon
- **User Avatar**: Profile picture or default icon
- **Empty State**: 📬 Mail/envelope icon

### Colors
- **Pending Status**: 🟠 Orange
- **Accepted Status**: 🟢 Green checkmark
- **Declined Status**: 🔴 Red X
- **Success Message**: Green/positive color
- **Error Message**: Red/warning color
- **Loading**: Spinner animation

### Text
- **Tab Labels**: "Pending (3)" / "Sent"
- **Timestamps**: "2 hours ago" / "Mar 15, 2:30 PM"
- **Status**: "ACCEPTED", "PENDING", "DECLINED"
- **Buttons**: "Accept", "Decline", "Send", "OK", "Retry"

---

## 🔍 Verification Checklist

As you test, check off these items:

- [ ] **UI Renders**: All elements visible and styled
- [ ] **Text Clear**: Readable, no truncation
- [ ] **Colors Correct**: Status colors match expected
- [ ] **Icons Show**: Avatar, status icons visible
- [ ] **Buttons Work**: Tappable, show feedback
- [ ] **Loading Shows**: Spinner appears during operation
- [ ] **Messages Display**: Success/error feedback shown
- [ ] **Badge Updates**: Count accurate, updates automatically
- [ ] **Data Flows**: Information displays correctly
- [ ] **Performance**: No lag, smooth scrolling
- [ ] **No Crashes**: App doesn't freeze/crash

---

**Reference this guide while testing to know if behavior is correct!**
