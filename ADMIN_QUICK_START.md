# Quick Reference: Admin Panel Deployment

## Project Structure Changed
```
BEFORE:
lib/main.dart        ← Single entry point for everything

AFTER:
lib/main.dart        ← User App (mobile + web fallback)
lib/main_admin.dart  ← Admin Panel (web-only) ← NEW
lib/admin_panel/     ← Admin module ← NEW
```

## How It Works Now

### User App (lib/main.dart)
```
When deployed to web: https://example.github.io/service-hub/
├─ Splash Screen (3 sec)
├─ Onboarding (mobile) or AdminLoginScreen (web)
└─ Customer/Provider UI
```

### Admin Panel (lib/main_admin.dart)  
```
When deployed to web: https://example.github.io/service-hub-admin/
├─ Splash Screen (3 sec)
├─ AdminLoginScreen (email/password)
└─ AdminDashboard (sidebar navigation)
```

## Deployment Configuration

### Build Target
Old: `flutter build web --release --base-href "/service-hub-admin/"`
New: `flutter build web --release --target lib/main_admin.dart --base-href "/service-hub-admin/"`

### GitHub Actions Workflow
File: `.github/workflows/deploy.yml`
- ✅ Uses `lib/main_admin.dart` as target
- ✅ Builds Admin Panel specifically
- ✅ Deploys to GitHub Pages `/service-hub-admin/`

## Files Created

1. **lib/main_admin.dart** (220 lines)
   - AdminPanelApp class
   - AdminAuthWrapper
   - AdminSplashScreen
   - AdminAccessDeniedScreen

2. **lib/admin_panel/admin_screens.dart**
   - Re-exports all admin screens

3. **lib/admin_panel/README.md**
   - Detailed documentation

4. **ADMIN_DEPLOYMENT_GUIDE.md**
   - Complete deployment guide

## Key Features

✅ Separate entry points for User App and Admin Panel
✅ Admin-only authentication (email/password)
✅ Role-based access control
✅ Automatic access denial for non-admins
✅ Admin-specific splash and error screens
✅ Clean separation in deployment configuration
✅ Same codebase, different applications

## To Deploy

```bash
# 1. Push to main
git add .
git commit -m "Reorganize project: separate admin panel"
git push origin main

# 2. GitHub Actions builds and deploys automatically
# 3. Admin panel available at https://[user].github.io/service-hub-admin/
```

## Admin Login Credentials

Admin accounts must have:
- role = 'admin' (in Supabase users table)
- is_verified = true
- Email + password in Supabase Auth

Example SQL to verify:
```sql
SELECT id, email, role, is_verified 
FROM users 
WHERE role = 'admin';
```

## Architecture

Same Supabase backend, two different UIs:
```
┌─────────────────────────────────┐
│      Supabase (Backend)         │
│  ├─ users table                 │
│  ├─ providers table             │
│  └─ bookings table              │
└─────────────────────────────────┘
          ▲                  ▲
          │                 │
    ┌─────┴──────┐   ┌─────┴──────────┐
    │ User App   │   │ Admin Panel    │
    │ (mobile)   │   │ (web-only)     │
    │            │   │                │
    │ main.dart  │   │ main_admin.dart│
    └────────────┘   └────────────────┘
```

No code duplication - same screens, different app initialization.
