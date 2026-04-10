# Admin Panel Deployment Guide

## Project Reorganization Summary

Your project has been successfully reorganized to separate the User App and Admin Panel into distinct applications with separate entry points.

## New Project Structure

```
lib/
├── main.dart                      # User App entry point (mobile + web fallback)
├── main_admin.dart               # Admin Panel entry point (web-only)
├── admin_panel/
│   ├── admin_screens.dart        # Admin screens module exports
│   └── README.md                 # Admin panel documentation
├── main_part2.dart               # Additional screens
└── ... (all other screens)
```

## Two Separate Applications

### 1. User App (lib/main.dart)
- **Builds from**: `lib/main.dart`
- **Target platforms**: Mobile (Android, iOS, macOS, Windows, Linux) + Web fallback
- **Default flow**: Splash → Onboarding → UserTypeSelection → Login/Register
- **Entry screen**: OnboardingScreen (mobile) or AdminLoginScreen (web fallback)

### 2. Admin Panel (lib/main_admin.dart)  
- **Builds from**: `lib/main_admin.dart`
- **Target platforms**: Web only
- **Default flow**: Splash → AdminLoginScreen → AdminDashboardScreen
- **Entry screen**: AdminLoginScreen (admin email/password)

## Deployment Configuration

### GitHub Pages Deployment (Web Admin Panel)

The workflow file `.github/workflows/deploy.yml` is configured to:

```yaml
Build Web: flutter build web --release --target lib/main_admin.dart --base-href "/service-hub-admin/"
```

This means:
- ✅ Builds **Admin Panel** specifically (not User App)
- ✅ Uses `lib/main_admin.dart` as entry point
- ✅ Deploys to `/service-hub-admin/` directory
- ✅ Sets base href for client-side routing

### Deployment URL
```
https://[username].github.io/service-hub-admin/
= https://[username].github.io/service-hub-admin/
```

## Build Commands

### Build Admin Panel for Web
```bash
flutter build web --release --target lib/main_admin.dart --base-href "/service-hub-admin/"
```

### Build User App for Web
```bash
flutter build web --release --base-href "/service-hub/"
```

### Build Admin Panel APK (Mobile)
```bash
flutter build apk --target lib/main_admin.dart
```

## Admin Panel Features

### Authentication
- Email/Password login (via Supabase)
- No phone OTP option (admin-only)
- Role verification on every login

### Security
- Admin role verification before dashboard access
- Access denied screen for non-admin users
- Automatic logout for unauthorized sessions
- Security logging for breach attempts

### Admin Screens
1. **AdminLoginScreen** - Email/password authentication
2. **AdminDashboardScreen** - Main dashboard with sidebar
3. **AdminOverviewScreen** - Statistics & metrics
4. **ProviderVerificationScreen** - Approve/reject providers
5. **BookingsOverviewScreen** - View all bookings
6. **SuperAdminScreen** - Super admin functions

## File Changes Made

### Created Files
✅ `lib/admin_panel/admin_screens.dart` - Admin screens module  
✅ `lib/admin_panel/README.md` - Admin panel documentation  
✅ `lib/main_admin.dart` - Admin Panel entry point (220+ lines)

### Updated Files
✅ `.github/workflows/deploy.yml` - Updated build target

### Unchanged
- `lib/main.dart` - User App still works normally
- `web/index.html` - Already configured for admin
- `pubspec.yaml` - No changes needed
- All screen files - Admin screens in both builds

## Verification Checklist

- ✅ lib/main_admin.dart created with no compilation errors
- ✅ lib/admin_panel module created with exports
- ✅ .github/workflows/deploy.yml updated correctly
- ✅ AdminAuthWrapper routes to admin login
- ✅ AdminAccessDeniedScreen blocks non-admins
- ✅ AdminSplashScreen shows during loading
- ✅ Deployment configuration ready

## Testing the Deployment

1. **Push to main branch**
   ```bash
   git add .
   git commit -m "Reorganize project with separate admin entry point"
   git push origin main
   ```

2. **GitHub Actions runs automatically**
   - Installs Flutter
   - Runs `flutter pub get`
   - Builds with `flutter build web --release --target lib/main_admin.dart`
   - Deploys to GitHub Pages

3. **Visit your admin panel**
   - URL: `https://[username].github.io/service-hub-admin/`
   - You should see the AdminLoginScreen
   - Enter admin email/password to access the dashboard

## Troubleshooting

**"Cannot find main_admin.dart"**
- Ensure the file is in the correct location: `lib/main_admin.dart`
- Run `flutter pub get` to refresh

**"Admin Panel shows User App interface"**
- Check that `.github/workflows/deploy.yml` has `--target lib/main_admin.dart`
- Rebuild with the correct command

**"Access Denied when logging in"**
- Verify the user account has `role = 'admin'` in the database
- Check that `is_verified = true` for the admin account

**"Splash screen loops"**
- Check Supabase initialization completed successfully
- Clear browser cache and try again

## Next Steps

1. Push the changes to your main branch
2. Monitor the GitHub Actions workflow
3. Test the deployment at `/service-hub-admin/`
4. Create admin test accounts in Supabase with proper roles
5. Verify admin functions work correctly

## Support

For more details, see:
- `lib/admin_panel/README.md` - Admin module documentation
- `.github/workflows/deploy.yml` - Deployment configuration
- Documentation files: `ADMIN_SETUP.md`, `ADMIN_IMPLEMENTATION.md`
