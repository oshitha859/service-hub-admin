# Service Hub - Setup Guide

## පියවර 1: Supabase Database Setup

### Go to Supabase Dashboard → SQL Editor

Create a new query and paste the following SQL, then click **"Run"**:

```sql
-- Create Users Table
CREATE TABLE IF NOT EXISTS public.users (
    id TEXT PRIMARY KEY,
    phone TEXT,
    role TEXT,
    email TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create Providers Table
CREATE TABLE IF NOT EXISTS public.providers (
    uid TEXT PRIMARY KEY REFERENCES public.users(id),
    name TEXT,
    category TEXT,
    nic_image TEXT,
    certificate_image TEXT,
    experience TEXT,
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS (Row Level Security)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;

-- Create Policies - Allow All Access for Testing
CREATE POLICY "Allow All Access" ON public.users FOR ALL USING (true);
CREATE POLICY "Allow All Access" ON public.providers FOR ALL USING (true);
```

✅ After running this SQL, you should see:
- ✓ Tables created successfully
- ✓ RLS enabled
- ✓ Policies created

---

## පියවර 2: Test the Mock Registration Flow

### Option A: Provider Registration (Plumber Example)

1. **Open the app** → Click "Want to provide services? Register Now"
2. **Fill in the form:**
   - Name: "Test Plumber"
   - Phone: "0771234567"
   - Location: "Colombo"
   - Category: "Plumbing"
   - Experience: "5 years"
3. **Upload Images:**
   - Upload NIC copy (any image file)
   - Upload Certificate (optional)
4. **Click "Continue to Verify"**
   - Images upload to Supabase Storage
   - App navigates directly to OTP screen (no real SMS sent)
5. **On OTP Screen - Enter the magic code: `123456`**
   - Shows "Invalid OTP" for any other code
   - Shows success dialog: "Application Submitted!"
   - Automatically navigates to "Application Under Review" screen

### Option B: Customer Registration

1. **Open app** → Click phone tab → Enter phone number
2. **Click "Send OTP"**
   - No real SMS is sent
   - Navigates directly to OTP screen
3. **Enter `123456`**
   - Success! Application saved
   - Navigates to "Application Under Review" screen

---

## පියවර 3: Data Flow & Debug Output

### When user enters `123456` on OTP screen:

**Console output shows:**
```
[OTP_DEBUG] MOCK MODE: Checking if OTP is 123456...
[OTP_DEBUG] MOCK MODE: OTP verified successfully (123456)
[OTP_DEBUG] MOCK MODE: Created mock user ID: mock_user_1712502400000
[OTP_DEBUG] MOCK MODE: Saving user data (isProvider: true/false)...
[OTP_DEBUG] MOCK MODE: Provider data saved successfully
[OTP_DEBUG] MOCK MODE: Showing success dialog for role: provider/customer
[OTP_DEBUG] MOCK MODE: Navigating to PendingApprovalScreen
```

### Data saved to Supabase:

**In `users` table:**
```
id: mock_user_1712502400000
phone: +94771234567
role: provider/customer
email: null (for phone signup)
is_verified: false
created_at: 2024-04-07T...
```

**In `providers` table (for providers only):**
```
uid: mock_user_1712502400000
name: Test Plumber
category: Plumbing
nic_image: https://namurnyqpcqjhqwcqeoj.supabase.co/storage/v1/object/public/nic-images/nic_1712502400000.jpg
certificate_image: https://namurnyqpcqjhqwcqeoj.supabase.co/storage/v1/object/public/nic-images/cert_1712502400000.jpg
experience: 5 years
location_lat: 0.0
location_lng: 0.0
created_at: 2024-04-07T...
```

---

## පියවර 4: Admin Verification (Future)

Once real admin panel is implemented:

1. Admin views pending providers at `/admin/verifications`
2. Clicks **"Approve"** button for a provider
3. Updates database: `users.is_verified = true`
4. Next time that user logs in, they'll see dashboard instead of "Under Review" screen

---

## Mock OTP Test Codes

| Code | Result |
|------|--------|
| `123456` | ✅ Success - Saves data and shows success dialog |
| `000000` | ❌ Error - "Invalid OTP" message |
| `111111` | ❌ Error - "Invalid OTP" message |
| Any other 6 digits | ❌ Error - "Invalid OTP" message |

---

## Key Features Implemented

- ✅ Mock phone OTP: Use `123456` for testing
- ✅ Bypass real Supabase Auth API (no phone provider needed)
- ✅ Generate mock user IDs: `mock_user_{timestamp}`
- ✅ Save to `users` and `providers` tables with correct schema
- ✅ Success dialog after registration
- ✅ Pending approval screen for all unverified users
- ✅ Admin can approve/reject providers (queries updated)
- ✅ Column names match SQL schema exactly:
  - `id` not `uid`
  - `is_verified` not `isVerified`
  - `nic_image` not `nicImage`
  - `certificate_image` not `certificateImage`
  - `created_at` not `createdAt`

---

## Troubleshooting

### "Invalid OTP" error when entering 123456?
- Make sure you're entering exactly `123456` (6 digits)
- Check console for `[OTP_DEBUG]` messages
- Restart the app and try again

### Images not uploading?
- Check that `nic-images` bucket exists in Supabase Storage
- Bucket must be set to public access
- Try with a smaller image file

### Data not visible in Supabase?
- Go to Supabase Dashboard → Database → `users` table
- Check if row exists with your mock user ID
- Verify `is_verified` column value

### Getting "phone provider disabled" error?
- This means the code is trying to call the real Auth API
- Make sure you're running the latest version with the bypass patch
- Restart the app

---

## Next Steps (Production)

When ready for production:
1. ✅ Implement real SMS provider (Twillio, etc.)
2. ✅ Replace mock OTP check with real `verifyOTP()` API call
3. ✅ Implement real admin panel for provider verification
4. ✅ Add location capture (lat/lng) from GPS/map
5. ✅ Remove mock user ID generation, use real Supabase auth user IDs
