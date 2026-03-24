# API Contracts: User Profile System

**Version**: 1.0  
**Status**: Approved  
**Date**: March 13, 2026

---

## Base Configuration

```
Base URL: http://localhost:8080 (dev) | https://api.app.com (prod)
Authentication: Bearer {JWT token} in Authorization header
Content-Type: application/json (except uploads: multipart/form-data)
Timeout: 30 seconds for text, 60 seconds for uploads
Retry: Automatic on network failure (exponential backoff)
```

---

## Endpoint 1: Get User Profile

### Request
```
GET /api/profile/:userId
Authorization: Bearer {token}
```

### Success Response (200 OK)
```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "username": "alice_wonder",
  "email": "alice@example.com",
  "profilePictureUrl": "https://cdn.app.com/profile-550e8400-1234.jpg",
  "aboutMe": "Coffee ☕ and books 📚",
  "isPrivateProfile": false,
  "updatedAt": "2026-03-13T09:15:00Z"
}
```

### Error Responses

**404 Not Found** - User does not exist
```json
{
  "error": "User not found",
  "code": "USER_NOT_FOUND"
}
```

**403 Forbidden** - Profile is private (future feature)
```json
{
  "error": "Profile is private",
  "code": "PROFILE_PRIVATE"
}
```

**401 Unauthorized** - Invalid token
```json
{
  "error": "Invalid credentials",
  "code": "UNAUTHORIZED"
}
```

### Notes
- Call this endpoint when navigating to profile screen to refresh data
- Response should be cached for 5 minutes to reduce server load
- Implement pull-to-refresh to bypass cache

---

## Endpoint 2: Update User Profile

### Request
```
PUT /api/profile
Authorization: Bearer {token}
Content-Type: application/json

{
  "username": "alice_wonderland",
  "aboutMe": "Coffee and adventure seekers unite!",
  "isPrivateProfile": false
}
```

### Request Validation
- All fields optional (send only fields that changed)
- username: 3-32 characters, alphanumeric + underscore + hyphen only
- aboutMe: 0-500 characters
- isPrivateProfile: true or false

### Success Response (200 OK)
```json
{
  "success": true,
  "profile": {
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "username": "alice_wonderland",
    "email": "alice@example.com",
    "profilePictureUrl": "https://cdn.app.com/profile-550e8400-1234.jpg",
    "aboutMe": "Coffee and adventure seekers unite!",
    "isPrivateProfile": false,
    "updatedAt": "2026-03-13T10:45:00Z"
  }
}
```

### Error Responses

**400 Bad Request** - Validation failed
```json
{
  "error": "Username must be 3-32 characters",
  "code": "INVALID_USERNAME",
  "field": "username"
}
```

```json
{
  "error": "Bio cannot exceed 500 characters",
  "code": "INVALID_BIO",
  "field": "aboutMe"
}
```

**401 Unauthorized** - Invalid token
```json
{
  "error": "Invalid credentials",
  "code": "UNAUTHORIZED"
}
```

**403 Forbidden** - Cannot edit another user's profile
```json
{
  "error": "You cannot edit this profile",
  "code": "FORBIDDEN"
}
```

### Notes
- Only authenticated user can update their own profile
- Server-side validation always enforces constraints regardless of client validation
- Response includes updated profile for immediate UI display

---

## Endpoint 3: Upload Profile Picture

### Request
```
POST /api/profile/picture
Authorization: Bearer {token}
Content-Type: multipart/form-data

Form Data:
  - image: <binary file> (JPEG or PNG, ≤5MB)
  - filename: profile.jpg (optional, for reference)
```

### Successful Response (200 OK)
```json
{
  "success": true,
  "imageUrl": "https://cdn.app.com/profile-550e8400-20260313-163847.jpg",
  "fileSize": 45670,
  "format": "JPEG"
}
```

### Error Responses

**400 Bad Request** - Invalid format
```json
{
  "error": "Only JPEG and PNG formats are supported",
  "code": "INVALID_IMAGE_FORMAT"
}
```

**400 Bad Request** - Invalid dimensions
```json
{
  "error": "Image must be between 100x100 and 5000x5000 pixels",
  "code": "INVALID_IMAGE_DIMENSIONS"
}
```

**413 Payload Too Large** - File too large
```json
{
  "error": "File must be smaller than 5MB",
  "code": "FILE_TOO_LARGE"
}
```

**401 Unauthorized** - Invalid token
```json
{
  "error": "Invalid credentials",
  "code": "UNAUTHORIZED"
}
```

**500 Internal Server Error** - Processing failed
```json
{
  "error": "Image processing failed, please try again",
  "code": "PROCESSING_ERROR"
}
```

### Server-Side Processing
- Image validated (format, size, dimensions)
- Resized/compressed to 500x500px square
- Stored securely with timestamp
- URL generated and returned immediately
- User.profilePictureUrl updated
- User.isDefaultProfilePicture set to false

### Notes
- Client should validate image before upload (format, size, dimensions) for better UX
- Server re-validates for security
- Response contains final image URL immediately (optimistic update ready)
- Multipart form makes this compatible with standard HTTP clients

---

## Endpoint 4: Delete Profile Picture

### Request
```
DELETE /api/profile/picture
Authorization: Bearer {token}
```

### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Profile picture removed"
}
```

### Error Responses

**404 Not Found** - No custom picture to delete
```json
{
  "error": "No custom profile picture found",
  "code": "NO_CUSTOM_PICTURE"
}
```

**401 Unauthorized** - Invalid token
```json
{
  "error": "Invalid credentials",
  "code": "UNAUTHORIZED"
}
```

### Server-Side Processing
- Locate user's active ProfileImage record
- Mark deleted_at with current timestamp (soft delete)
- Clear User.profilePictureUrl
- Set User.isDefaultProfilePicture to true
- Default avatar will display in UI

### Notes
- No hard deletion—soft delete preserves record for audit trail
- Only one active ProfileImage per user (new upload replaces old)

---

## Error Code Reference

| Code | HTTP | Meaning | User Action |
|------|------|---------|-------------|
| USER_NOT_FOUND | 404 | Profile doesn't exist | Show error, dismiss |
| PROFILE_PRIVATE | 403 | Can't see private profile | Show "Profile is private" |
| UNAUTHORIZED | 401 | Token invalid/expired | Re-authenticate |
| FORBIDDEN | 403 | Not allowed to edit | Show error |
| INVALID_USERNAME | 400 | Username validation failed | Fix and retry |
| INVALID_BIO | 400 | Bio validation failed | Fix and retry |
| INVALID_IMAGE_FORMAT | 400 | Wrong image format | Select JPEG/PNG and retry |
| INVALID_IMAGE_DIMENSIONS | 400 | Wrong image size (pixels) | Select valid image and retry |
| FILE_TOO_LARGE | 413 | Image file >5MB | Select smaller image and retry |
| PROCESSING_ERROR | 500 | Server failed | Show retry button |

---

## Request/Response Examples (cURL)

### Get Profile
```bash
curl -H "Authorization: Bearer {token}" \
  http://localhost:8080/api/profile/550e8400-e29b-41d4-a716-446655440000
```

### Update Profile
```bash
curl -X PUT -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "new_name",
    "aboutMe": "Hello world"
  }' \
  http://localhost:8080/api/profile
```

### Upload Image
```bash
curl -X POST -H "Authorization: Bearer {token}" \
  -F "image=@./profile.jpg" \
  http://localhost:8080/api/profile/picture
```

### Delete Image
```bash
curl -X DELETE -H "Authorization: Bearer {token}" \
  http://localhost:8080/api/profile/picture
```

---

## Rate Limiting

- GET /api/profile: 60 requests per minute per user
- PUT /api/profile: 10 requests per minute per user
- POST /api/profile/picture: 5 requests per minute per user
- DELETE /api/profile/picture: 10 requests per minute per user

Response includes rate limit headers:
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 59
X-RateLimit-Reset: 1234567890
```

---

*API Contract Complete - Ready for backend implementation*
