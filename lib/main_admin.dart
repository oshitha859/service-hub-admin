import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
// Import the main file which contains all the screens and services
import 'main.dart';

/// Admin Panel Entry Point for Web Build
/// 
/// This is the dedicated entry point for the Admin Control Panel deployment.
/// It initializes Supabase and routes directly to the admin login/dashboard.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (same as main.dart)
  print('[SUPABASE_INIT] Initializing Supabase for Admin Panel...');
  await sb.Supabase.initialize(
    url: 'https://namurnyqpcqjhqwcqeoj.supabase.co',
    anonKey: 'sb_publishable_CE7XJ1ExeQccq4N-i9pSmw_TyzB5bYI',
  );
  print('[SUPABASE_INIT] Supabase initialized successfully');

  runApp(const AdminPanelApp());
}

/// Admin-only App - Routes directly to admin login
class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ceylon Service Hub - Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF5E60CE), // Electric Indigo
        ),
      ),
      home: const AdminAuthWrapper(),
      routes: {'/super-admin': (context) => const SuperAdminScreen()},
    );
  }
}

/// Admin-specific Auth Wrapper
/// Routes to AdminLoginScreen for unauthenticated users
/// Routes to AdminDashboardScreen for authenticated admins
class AdminAuthWrapper extends StatelessWidget {
  const AdminAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<sb.AuthState>(
      stream: sb.Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AdminSplashScreen();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Auth Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data?.session != null) {
          final userId = snapshot.data!.session!.user.id;
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: sb.Supabase.instance.client
                .from('users')
                .select()
                .eq('id', userId)
                .limit(1),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const AdminSplashScreen();
              }
              if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data!.isEmpty) {
                return const AdminSplashScreen();
              }

              final userData = userSnapshot.data![0];
              final String? role = userData['role'] as String?;

              // Only show dashboard to admins
              if (role == 'admin') {
                return AdminDashboardScreen(userId: userId);
              }

              // Non-admin users get access denied
              return const AdminAccessDeniedScreen();
            },
          );
        }

        // Unauthenticated users see admin login screen
        return const AdminLoginScreen();
      },
    );
  }
}

/// Admin Splash Screen - Shown while loading
class AdminSplashScreen extends StatefulWidget {
  const AdminSplashScreen({super.key});

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5E60CE).withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF5E60CE).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 50,
                    color: Color(0xFF5E60CE),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Admin Panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ceylon Service Hub',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Access Denied Screen - Shown to non-admin users
class AdminAccessDeniedScreen extends StatelessWidget {
  const AdminAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 50,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Access Denied',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Admin credentials are required to access this panel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () async {
                // Sign out and show login screen
                await sb.Supabase.instance.client.auth.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
