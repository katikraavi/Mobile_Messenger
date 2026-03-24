specify: Implement Error Handling System

Goal
Graceful error recovery.

Errors
- network failures
- message send failure
- server errors

Features
- visual error feedback
- retry actions
- return to last stable state

Acceptance Criteria
- errors handled without crashing

What to test
- Turn off internet during message send
- Verify error message appears
- Retry message send
- Trigger server error
- Confirm app recovers without crash
