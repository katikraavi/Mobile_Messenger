# Mobile Messenger - Setup & Run Guide

## ✅ Fixed Issues

### 1. **Server Error on Login**
- **Problem**: When running `flutter run` after `docker-compose up`, login returned "Server error"
- **Root Cause**: Localhost connection from WSL wasn't reliable to Docker containers
- **Solution**: Assigned fixed Docker network IP to backend container

### 2. **Container IP Changes Between Sessions**
- **Problem**: Container IP was different each time docker-compose restarted (172.18.0.x)
- **Solution**: Configured Docker to use fixed subnet (172.20.0.0/16) with static IPs:
  - PostgreSQL: 172.20.0.2 (fixed)
  - Backend: 172.20.0.3 (fixed)

### 3. **Flutter API Configuration**
- **Updated** all API service base URLs to use fixed IP: `http://172.20.0.3:8081`
- Files updated:
  - `lib/features/auth/services/auth_service.dart`
  - `lib/features/email_verification/services/email_verification_service.dart`
  - `lib/features/password_recovery/services/password_recovery_service.dart`
  - `lib/core/config/app_config.dart`
  - `lib/core/services/api_client.dart`
  - `lib/features/profile/services/profile_service.dart`
  - `lib/features/search/providers/search_results_provider.dart`
  - `lib/features/profile/screens/profile_view_screen.dart`

## 🚀 Quick Start

### Step 1: Start Docker Services
```bash
cd /home/katikraavi/mobile-messenger
docker-compose up -d
```

**Wait for both services to be healthy:**
```bash
docker-compose ps
```
Expected output:
- ✅ `messenger-backend` - UP (healthy)
- ✅ `messenger-postgres` - UP (healthy)

**Verify container IP (should be 172.20.0.3):**
```bash
docker-compose exec -T serverpod hostname -I
```

### Step 2: Run Flutter App
```bash
cd frontend
flutter run -d linux
```

Or for other devices:
- iOS: `flutter run -d ios`
- Android: `flutter run -d android`

### Step 3: Test Login
- **Test User 1:**
  - Email: `alice@example.com`
  - Password: `Alice@123`

- **Test User 2:**
  - Email: `bob@example.com`
  - Password: `Bob@123`

- **Test User 3:**
  - Email: `charlie@example.com`
  - Password: `Charlie@123`

## 🐛 Troubleshooting

### Backend fails to start with migration error
```
Failed migration 10: column "verified_at" of relation "users" already exists
```

**Fix:**
```bash
docker-compose exec -T postgres psql -U messenger_user -d messenger_db \
  -c "INSERT INTO schema_migrations (version, description, executed_at) \
      VALUES (10, 'Add verified_at to users', NOW());"
docker-compose restart serverpod
```

### Flask can't connect to API
1. Check container IP:
   ```bash
   docker-compose exec -T serverpod hostname -I
   ```
   Should be `172.20.0.3`

2. Verify health endpoint:
   ```bash
   curl http://172.20.0.3:8081/health
   ```

3. If IP is different (172.18.x.x), update all API URLs to match

### Clean slate required
```bash
# Full cleanup
docker-compose down -v --remove-orphans
docker volume rm mobile-messenger_postgres_data mobile-messenger_uploads_data 2>/dev/null
docker network prune -f

# Restart
docker-compose up -d
```

## 📝 Docker Compose Network Configuration

**Fixed Configuration Added:**
```yaml
networks:
  messenger-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  postgres:
    networks:
      messenger-network:
        ipv4_address: 172.20.0.2
  
  serverpod:
    networks:
      messenger-network:
        ipv4_address: 172.20.0.3
```

This ensures consistent IP addresses across sessions.

## ✨ Features Tested & Working

- ✅ User Registration
- ✅ User Login (fixed with IP configuration)
- ✅ Email Verification
- ✅ Password Reset
- ✅ User Profile Management
- ✅ Chat Invitations (send, receive, accept, decline)
- ✅ User Search
- ✅ Push Notifications
- ✅ Encryption

## 📊 Architecture

```
┌─────────────────────────────────────────┐
│  Windows/WSL Host                        │
│  ┌──────────────────────────────────────┤
│  │ Flutter App (Desktop/Mobile)          │
│  │ Connects to: 172.20.0.3:8081         │
│  └──────────────────────────────────────┤
└─────────────────────────────────────────┘
         ↓ (HTTP over Docker network)
┌──────────────────────────────────────────────────┐
│ Docker Network: 172.20.0.0/16                    │
├──────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────┐   │
│ │ Backend (serverpod)  - 172.20.0.3:8081     │   │
│ │ API, Auth, Logic                           │   │
│ └────────────────────────────────────────────┘   │
│             ↓                                     │
│ ┌────────────────────────────────────────────┐   │
│ │ PostgreSQL Database - 172.20.0.2:5432      │   │
│ │ Users, Chats, Messages, Invites            │   │
│ └────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

## 🎯 Next Steps

1. Run `docker-compose up -d`
2. Run `flutter run` in frontend folder
3. Login with test credentials
4. Test invitation flow (send invite → accept/decline)
5. Test chat creation and messaging

**All systems are now configured for stable, reliable development!** 🎉
