specify: Implement Data Encryption

Goal
Encrypt sensitive data before database storage.

Encrypted data
- message text
- media metadata
- user profile data
- chat lists

Algorithm
AES-256

Process
encrypt → store
retrieve → decrypt

Acceptance Criteria
- database stores encrypted values
- messages display correctly

What to test
- Send message
- Inspect database entry
- Confirm text is encrypted
- Open chat
- Verify message decrypts correctly
