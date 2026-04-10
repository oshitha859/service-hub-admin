# Admin Panel Setup & Testing Guide

## Quick Start: Create Admin User

### Step 1: Open Supabase Dashboard
1. Go to https://app.supabase.com
2. Select your Service Hub project
3. Navigate to **Data Editor** → **users table**

### Step 2: Insert Admin User
Click **Insert row** and fill in:
```
id:           admin_user_001
phone:        +1234567890
role:         admin
email:        admin@servicehub.com
is_verified:  true (toggle ON)
```

Then click **Save**

### Step 3: Test Admin Access Locally

#### Option A: Via Mock User (Quick Testing)
1. In Flutter app, open DevTools console
2. Run:
```dart
await LocalStorageService.saveMockUserId('admin_user_001');
```
3. Restart the app
4. Should see Admin Dashboard instead of home screen

#### Option B: Create Admin Login Screen (For Production)
- Implement form to accept admin user ID
- Call `LocalStorageService.saveMockUserId(adminUserId)`
- Restart app to load admin dashboard

## Admin Dashboard Features

### 📊 Dashboard Overview Tab
Shows live statistics:
- **Total Users**: Count of all registered users
- **Pending Providers**: Providers awaiting approval (is_verified = false)
- **Active Bookings**: Bookings with status = 'pending'

### ✅ Verify Providers Tab
Manage provider verification:
1. **View Unverified Providers**: List all providers with is_verified = false
2. **Review Documents**: 
   - Expand provider card
   - View NIC image (National ID Card)
   - View Certificate image
3. **Approve Provider**: 
   - Click "Approve Provider" button
   - Sets is_verified = true in database
   - Provider receives notification (if implemented)

### 📋 Bookings Overview Tab
Monitor all bookings:
- **DataTable view** showing:
  - Customer (phone number from users.phone)
  - Provider (name from providers.name)
  - Booking Date (YYYY-MM-DD format)
  - Status (Pending/Completed badge)
- **Sorted by**: Most recent bookings first
- **Total Count**: Shows total number of bookings

## Security Architecture

### Role-Based Access Control
```
if (userRole != 'admin') {
  redirect to splash screen
  show "Unauthorized: Admin access required" error
}
```

### RLS (Row Level Security)
All sensitive operations protected:
- ✅ Admin can read users, providers, bookings
- ✅ Only admins can update is_verified status
- ✅ Bookings table read-only for admins
- ✅ All queries verify admin role before execution

### Security Logging
```
[ADMIN] SECURITY BREACH: Non-admin attempted to access admin panel
[PROVIDER_VERIFY] SECURITY: Non-admin attempted verification
[BOOKINGS] SECURITY: Non-admin attempted bookings access
```

## Testing Workflow

### Create Test Data

1. **Create Unverified Provider**:
   - Register as provider normally
   - Complete OTP verification
   - Provider saved with is_verified = false
   - Should appear in "Verify Providers" tab

2. **Create Test Booking**:
   - Register as customer
   - Browse providers
   - Create booking
   - Booking appears in "Bookings Overview"

3. **Approve Provider**:
   - Switch to admin user
   - Go to "Verify Providers" tab
   - Expand unverified provider
   - Click "Approve Provider"
   - Provider disappears from list (now verified)

## Troubleshooting

### Admin Dashboard Not Loading
**Problem**: See splash screen instead of admin dashboard
**Solution**:
1. Verify admin user exists in database with role = 'admin'
2. Check is_verified = true for admin user
3. Clear app storage: `LocalStorageService.clearMockUserId()`
4. Set mock user ID again
5. Restart app

### Statistics Not Updating
**Problem**: Stat cards show 0 or old data
**Solution**:
1. Restart app to trigger fresh FutureBuilder
2. Check RLS policies are enabled in Supabase
3. Verify database has data in corresponding tables

### Provider Images Not Loading
**Problem**: NIC/Certificate images show "Failed to load image"
**Solution**:
1. Verify image URLs are valid in database (should be Supabase URLs)
2. Check provider was registered with valid image uploads
3. Confirm Supabase storage bucket is public (or allow signed URLs)

### "Unauthorized: Admin access required" Error
**Problem**: Logged in as admin but see unauthorized error
**Solution**:
1. Verify user role = 'admin' in database
2. Clear LocalStorageService
3. Restart app
4. Check browser console for [ADMIN] SECURITY logs

## Next Steps

### Enhance Admin Panel
1. **Add Admin Statistics**:
   - Provider approval trends (chart)
   - Category breakdown
   - Booking completion rate

2. **Booking Management**:
   - Mark bookings as completed
   - Cancel bookings with reason
   - Refund management

3. **Provider Management**:
   - Reject providers with reason message
   - Suspend provider accounts
   - View provider reviews/ratings

4. **Audit System**:
   - Log all admin actions
   - Timestamp each action
   - Readonly audit trail

## Key Files Modified

- **lib/main.dart**:
  - AuthWrapper: Added admin role routing
  - AdminDashboardScreen: Main admin hub (NEW)
  - AdminOverviewScreen: Statistics dashboard (NEW)
  - ProviderVerificationScreen: Provider approval (NEW)
  - BookingsOverviewScreen: Booking monitoring (NEW)

## Database Schema

### Users Table
```
id (PK) | phone | role | email | is_verified | status | created_at
```
- role = 'admin' for admin users
- is_verified = true for approved admins

### Providers Table
```
uid (PK) | name | category | experience | nic_image | certificate_image | ...
```

### Bookings Table
```
id (PK) | customer_id (FK) | provider_id (FK) | booking_date | booking_time | status | ...
```

---

**Questions?** Check console logs for [ADMIN], [PROVIDER_VERIFY], [BOOKINGS] messages
