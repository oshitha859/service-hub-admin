# Admin Panel Module Structure

## Overview
The Admin Panel is now a separate, dedicated web-only application built from `lib/main_admin.dart`.

## Directory Structure

```
lib/
├── main.dart                    # User App entry point (mobile + web fallback)
├── main_admin.dart             # Admin Panel entry point (web-only)
├── Admin_panel/
│   └── admin_screens.dart      # Re-exports all admin screens
└── ... (other screens and services)
```

## Entry Points

### User App (`lib/main.dart`)
- **Platforms**: Mobile (Android, iOS, macOS, Windows, Linux) + Web fallback
- **Default Route**: Onboarding → UserTypeSelection (mobile) or AdminLoginScreen (web)
- **Purpose**: Customer/Provider application

### Admin Panel (`lib/main_admin.dart`)
- **Platforms**: Web only
- **Default Route**: AdminLoginScreen → AdminDashboardScreen
- **Purpose**: Admin Control Panel for managing providers, bookings, and system

## Admin-Specific Features

### Configuration
- Direct routing to admin login on app start
- Admin-only authentication (email/password via Supabase)
- Automatic verification of admin role before showing dashboard
- Access denied screen for non-admin users
- Dedicated splash screen for admin panel

### Screens
All admin screens are defined in `lib/main.dart` but used in `main_admin.dart`:

1. **AdminLoginScreen** - Email/password login for admins
2. **AdminDashboardScreen** - Main admin hub with sidebar navigation
   - Dashboard Overview
   - Provider Verification
   - Bookings Management
3. **AdminOverviewScreen** - Statistics dashboard
4. **ProviderVerificationScreen** - Provider approval workflow
5. **BookingsOverviewScreen** - Booking management
6. **SuperAdminScreen** - Super admin verification interface

### Services
- **LocalStorageService** - Persistent user ID storage for mock auth
- **Supabase Auth** - Email/password authentication
- **Supabase Database** - Users, providers, bookings management

## Build Configuration

### Web Deployment
The GitHub Actions workflow deploys the Admin Panel:

```yaml
Build Web: flutter build web --release --target lib/main_admin.dart --base-href "/service-hub-admin/"
Deploy to: https://[username].github.io/service-hub-admin/
```

### Build Command
```bash
# Build Admin Panel for web
flutter build web --release --target lib/main_admin.dart --base-href "/service-hub-admin/"

# Build User App for web
flutter build web --release --base-href "/service-hub/"
```

## Security Features

1. **Role Verification** - Admin role checked on every screen load
2. **Access Control** - Non-admin users redirected with access denied message
3. **Session Management** - Automatic logout when role changes
4. **Audit Logging** - Security breaches logged for monitoring
5. **Email Authentication** - Admin accounts require verified email/password

## Integration with main.dart

The admin panel reuses components from `main.dart`:
- All screen classes (AdminDashboardScreen, etc.)
- LocalStorageService
- Supabase initialization
- Shared utilities and widgets

This approach avoids code duplication while maintaining a clean separation between user app and admin panel.

## Future Enhancements

- Move admin screens to separate files in `lib/admin_panel/screens/`
- Create admin-specific services in `lib/admin_panel/services/`
- Implement admin-specific themes and customization
- Add role-based access control (different admin levels)
- Create separate database views for admin data
