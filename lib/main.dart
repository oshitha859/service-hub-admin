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

// Local Storage Service for Mock User Persistence
class LocalStorageService {
  static const String mockUserIdKey = 'mock_user_id';

  static Future<void> saveMockUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(mockUserIdKey, userId);
    print('[LOCAL_STORAGE] Saved mock user ID: $userId');
  }

  static Future<String?> getMockUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(mockUserIdKey);
    if (userId != null) {
      print('[LOCAL_STORAGE] Retrieved mock user ID: $userId');
    }
    return userId;
  }

  static Future<void> clearMockUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(mockUserIdKey);
    print('[LOCAL_STORAGE] Cleared mock user ID');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (replacing Firebase)
  print('[SUPABASE_INIT] Initializing Supabase...');
  await sb.Supabase.initialize(
    url: 'https://namurnyqpcqjhqwcqeoj.supabase.co',
    anonKey: 'sb_publishable_CE7XJ1ExeQccq4N-i9pSmw_TyzB5bYI',
  );
  print('[SUPABASE_INIT] Supabase initialized successfully');

  runApp(const ServiceHubApp());
}

class ServiceHubApp extends StatelessWidget {
  const ServiceHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ceylon Service Hub',
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
      home: const AuthWrapper(),
      routes: {'/super-admin': (context) => const SuperAdminScreen()},
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<sb.AuthState>(
      stream: sb.Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
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
                return const SplashScreen();
              }
              if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data!.isEmpty) {
                // If user authenticated but no doc exists, they might be in the middle of registration
                return const SplashScreen();
              }

              final userData = userSnapshot.data![0];
              final String? role = userData['role'] as String?;
              final String safeRole = role ?? 'customer';
              final bool isVerified = userData['is_verified'] as bool? ?? false;

              // Show pending approval screen for unverified users
              if (!isVerified) {
                return PendingApprovalScreen(userId: userId);
              }

              // Route based on role
              if (safeRole == 'admin') {
                return AdminDashboardScreen(userId: userId);
              }
              
              if (safeRole == 'customer') {
                return CustomerHomeScreen(userId: userId);
              }

              return DashboardScreen(role: safeRole);
            },
          );
        }

        // Check local storage for persisted mock user
        return FutureBuilder<String?>(
          future: LocalStorageService.getMockUserId(),
          builder: (context, mockUserSnapshot) {
            if (mockUserSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }
            
            if (mockUserSnapshot.hasData && mockUserSnapshot.data != null) {
              final mockUserId = mockUserSnapshot.data!;
              print('[AUTH_WRAPPER] Found persisted mock user: $mockUserId');
              
              // Fetch user status from Supabase
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: sb.Supabase.instance.client
                    .from('users')
                    .select()
                    .eq('id', mockUserId)
                    .limit(1),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }
                  
                  if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data!.isEmpty) {
                    // User not found or deleted
                    print('[AUTH_WRAPPER] Mock user not found in database');
                    LocalStorageService.clearMockUserId();
                    return const SplashScreen();
                  }

                  final userData = userSnapshot.data![0];
                  final bool isVerified = userData['is_verified'] as bool? ?? false;
                  final String? rawStatus = userData['status'] as String?;
                  final String status = rawStatus ?? 'pending';
                  final String? role = userData['role'] as String?;
                  final String safeRole = role ?? 'customer';

                  if (status == 'rejected') {
                    return RejectionScreen(userId: mockUserId);
                  }

                  if (!isVerified) {
                    return PendingApprovalScreen(userId: mockUserId);
                  }

                  // Route based on role
                  if (safeRole == 'admin') {
                    return AdminDashboardScreen(userId: mockUserId);
                  }
                  
                  if (safeRole == 'customer') {
                    return CustomerHomeScreen(userId: mockUserId);
                  }

                  return DashboardScreen(role: safeRole);
                },
              );
            }
            
            return const SplashScreen();
          },
        );
      },
    );
  }
}

class PendingApprovalScreen extends StatefulWidget {
  final String? userId;

  const PendingApprovalScreen({super.key, this.userId});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  late StreamSubscription _userSubscription;
  String? _userRole = 'provider';

  @override
  void initState() {
    super.initState();
    _listenToUserStatus();
  }

  void _listenToUserStatus() {
    final userId = widget.userId ?? 'unknown_user';
    print('[PENDING_APPROVAL] Listening to user status for: $userId');
    
    try {
      _userSubscription = sb.Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', userId)
          .listen((List<Map<String, dynamic>> data) {
            if (data.isEmpty) {
              // User deleted
              print('[PENDING_APPROVAL] User record deleted');
              _onUserDeleted();
              return;
            }

            final userData = data[0];
            final bool isVerified = userData['is_verified'] as bool? ?? false;
            final String? rawStatus = userData['status'] as String?;
            final String status = rawStatus ?? 'pending';
            final String? role = userData['role'] as String?;

            // Store role for later use
            setState(() {
              _userRole = role ?? 'provider';
            });

            print('[PENDING_APPROVAL] User status updated - verified: $isVerified, status: $status, role: $_userRole');

            if (status == 'rejected') {
              _onRejected();
              return;
            }

            if (isVerified) {
              _onApproved();
            }
          }, onError: (error) {
            print('[PENDING_APPROVAL] Stream error: $error');
          });
    } catch (e) {
      print('[PENDING_APPROVAL] Error setting up stream: $e');
    }
  }

  void _onApproved() {
    if (!mounted) return;
    print('[PENDING_APPROVAL] User approved! Navigating to DashboardScreen');
    
    // Show success notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Your account has been approved!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Navigate to dashboard after brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final role = _userRole ?? 'provider';
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => DashboardScreen(role: role)),
          (route) => false,
        );
      }
    });
  }

  void _onRejected() {
    if (!mounted) return;
    print('[PENDING_APPROVAL] User rejected! Navigating to RejectionScreen');
    
    final userId = widget.userId ?? 'unknown_user';
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => RejectionScreen(userId: userId),
      ),
      (route) => false,
    );
  }

  void _onUserDeleted() {
    if (!mounted) return;
    print('[PENDING_APPROVAL] User deleted! Clearing storage and navigating to splash');
    
    LocalStorageService.clearMockUserId();
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _userSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_empty_rounded,
                size: 100,
                color: Color(0xFF00E5FF),
              ),
              const SizedBox(height: 30),
              const Text(
                'Approval Pending',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Your provider account is currently being reviewed by our team. You will have access to the dashboard once verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'This page updates automatically when your status changes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegistrationSuccessDialog extends StatefulWidget {
  final String role;
  final VoidCallback onClose;

  const RegistrationSuccessDialog({
    super.key,
    required this.role,
    required this.onClose,
  });

  @override
  State<RegistrationSuccessDialog> createState() =>
      _RegistrationSuccessDialogState();
}

class _RegistrationSuccessDialogState extends State<RegistrationSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Auto-close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF131826),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Checkmark/Hourglass Icon
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.role == 'provider'
                        ? const Color(0xFFFFB800).withOpacity(0.1)
                        : const Color(0xFF00E5FF).withOpacity(0.1),
                    border: Border.all(
                      color: widget.role == 'provider'
                          ? const Color(0xFFFFB800)
                          : const Color(0xFF00E5FF),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    widget.role == 'provider'
                        ? Icons.hourglass_empty_rounded
                        : Icons.check_circle_rounded,
                    size: 60,
                    color: widget.role == 'provider'
                        ? const Color(0xFFFFB800)
                        : const Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(height: 25),

                // Title
                Text(
                  widget.role == 'provider'
                      ? 'Application Submitted!'
                      : 'Welcome!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),

                // Message
                if (widget.role == 'provider')
                  Text(
                    'Your application is under review. We will notify you once approved.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    'You have successfully registered! You can now browse and book services.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 25),

                // Redirect message
                Text(
                  widget.role == 'provider'
                      ? 'You will be redirected in a moment...'
                      : 'Redirecting to dashboard...',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RejectionScreen extends StatelessWidget {
  final String? userId;

  const RejectionScreen({super.key, this.userId});

  void _navigateToResubmit(BuildContext context) {
    final safeUserId = userId ?? 'unknown_user';
    print('[REJECTION] User navigating to resubmit from: $safeUserId');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ProviderRegistrationPage(existingUserId: safeUserId),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rejection Icon
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.redAccent,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 40),

              // Title
              const Text(
                'Application Rejected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Message
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Your provider application did not meet our requirements. Please review your information and resubmit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Details text
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Make sure all documents are clear and meet our quality standards.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Action Buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Resubmit Button
                  ElevatedButton(
                    onPressed: () => _navigateToResubmit(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E60CE),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Edit & Resubmit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Clear Data Button
                  OutlinedButton(
                    onPressed: () async {
                      print('[REJECTION] User clearing data');
                      await LocalStorageService.clearMockUserId();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const SplashScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Start Over',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String role;
  const DashboardScreen({super.key, required this.role});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {}

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'provider') {
      return _buildProviderScreen();
    }
    return _buildCustomerScreen();
  }

  Widget _buildProviderScreen() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Provider Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildProviderStatCard(
                'Total Earnings',
                'Rs. 45,000',
                Icons.account_balance_wallet,
                const Color(0xFFBD00FF),
              ),
              const SizedBox(height: 16),
              _buildProviderStatCard(
                'Active Jobs',
                '12',
                Icons.work,
                const Color(0xFF00E5FF),
              ),
              const SizedBox(height: 30),
              const Text(
                'Incoming Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildJobRequest('Nimal - AC Repair', 'Galle Road, Matara'),
              _buildJobRequest('Sumith - Plumber', 'Broadway, Matara'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerScreen() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(6.1245, 81.1212), // Hambantota Town Center
              zoom: 14.5,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),
          Positioned(
            bottom: 120,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0x30FFFFFF),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Where do you need help?',
                            hintStyle: TextStyle(color: Colors.white54),
                            icon: Icon(Icons.search, color: Colors.white70),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBD00FF),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.tune, color: Colors.white),
                ),
              ],
            ),
          ),
          const Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Service Hub - Lanka',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131826).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 5),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFFBD00FF),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Categories',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildProviderStatCard(
    String title,
    String val,
    IconData icon,
    Color col,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x30FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: col.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: col),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                val,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobRequest(String name, String loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x20FFFFFF),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF5E60CE),
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  loc,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBD00FF),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

class ProviderListScreen extends StatefulWidget {
  final String? initialCategory;
  final String? selectedCategory;

  const ProviderListScreen({
    super.key,
    this.initialCategory,
    this.selectedCategory,
  });

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  late TextEditingController _searchController;
  late String _searchQuery;

  @override
  void initState() {
    super.initState();
    // Use selectedCategory first, fall back to initialCategory
    final category = widget.selectedCategory ?? widget.initialCategory;
    _searchQuery = category?.toLowerCase() ?? '';
    _searchController = TextEditingController(
      text: category ?? '',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchVerifiedProviders() async {
    print('[PROVIDER_LIST] Fetching verified providers for category: $_searchQuery');
    
    try {
      // Fetch providers from providers table
      final providersList = await sb.Supabase.instance.client
          .from('providers')
          .select();
      
      List<Map<String, dynamic>> filteredProviders = [];

      for (var provider in providersList) {
        final providerId = provider['uid'] as String?;
        
        if (providerId == null) continue;

        // Fetch corresponding user to check role and is_verified
        final userList = await sb.Supabase.instance.client
            .from('users')
            .select()
            .eq('id', providerId)
            .limit(1);

        if (userList.isNotEmpty) {
          final user = userList[0];
          final role = user['role'] as String? ?? '';
          final isVerified = user['is_verified'] as bool? ?? false;

          // Filter: must be provider role and verified
          if (role == 'provider' && isVerified) {
            // Filter by category if search query exists
            final category = provider['category'] as String? ?? '';
            if (_searchQuery.isEmpty || category.toLowerCase().contains(_searchQuery)) {
              // Combine user and provider data
              final combinedProvider = {
                ...provider,
                'user_id': providerId,
                'phone': user['phone'] ?? '',
                'email': user['email'] ?? '',
              };
              filteredProviders.add(combinedProvider);
            }
          }
        }
      }

      print('[PROVIDER_LIST] Found ${filteredProviders.length} verified providers');
      return filteredProviders;
    } catch (e) {
      print('[PROVIDER_LIST] Error fetching providers: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Service Providers',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 15.0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x30FFFFFF),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search by category...',
                          hintStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.search, color: Colors.white70),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Output List Stream
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchVerifiedProviders(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF5E60CE),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    if (snapshot.hasData &&
                        snapshot.data!.isNotEmpty) {
                      List<Map<String, dynamic>> providers = snapshot.data!;

                      if (providers.isEmpty) {
                        return const Center(
                          child: Text(
                            'No providers found in this category.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: providers.length,
                        itemBuilder: (context, index) {
                          var provider = providers[index];
                          return _buildProviderCard(provider);
                        },
                      );
                    }
                    return const Center(
                      child: Text(
                        'No providers registered yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return GestureDetector(
      onTap: () {
        print('[PROVIDER_LIST] Navigating to provider profile: ${provider['uid']}');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProviderProfileScreen(providerData: provider),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0x30FFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF5E60CE).withOpacity(0.2),
                    radius: 25,
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF5E60CE),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (provider['name'] as String?) ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBD00FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFBD00FF).withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                (provider['category'] as String?) ?? 'N/A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Available',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () async {
                        final phone = provider['phone']?.toString();
                        if (phone != null && phone.isNotEmpty) {
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        }
                      },
                      icon: const Icon(Icons.phone),
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ProviderProfileScreen - Shows provider details and Book Now button
class ProviderProfileScreen extends StatelessWidget {
  final Map<String, dynamic> providerData;

  const ProviderProfileScreen({
    super.key,
    required this.providerData,
  });

  @override
  Widget build(BuildContext context) {
    // Extract provider details with safe type casting
    final String name = (providerData['name'] as String?) ?? 'Unknown Provider';
    final String category = (providerData['category'] as String?) ?? 'N/A';
    final String experience = (providerData['experience'] as String?) ?? 'Not specified';
    final String phone = (providerData['phone'] as String?) ?? 'Not provided';
    final String email = (providerData['email'] as String?) ?? 'Not provided';
    final double? latitude = providerData['location_lat'] as double?;
    final double? longitude = providerData['location_lng'] as double?;
    final String userId = (providerData['user_id'] as String?) ?? (providerData['uid'] as String?) ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E17),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Provider Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider Avatar and Basic Info
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF5E60CE).withOpacity(0.2),
                      radius: 50,
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF5E60CE),
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Category and Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0x30FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Service Category', category),
                    const SizedBox(height: 15),
                    _buildDetailRow('Experience', experience),
                    const SizedBox(height: 15),
                    _buildDetailRow('Phone', phone),
                    const SizedBox(height: 15),
                    _buildDetailRow('Email', email),
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 15),
                      _buildDetailRow(
                        'Location',
                        '$latitude, $longitude',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Book Now Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    print('[PROVIDER_PROFILE] Navigating to booking for provider: $userId');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(
                          providerData: providerData,
                          providerId: userId,
                          providerName: name,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E60CE),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// BookingScreen - Form to book a service from provider
class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> providerData;
  final String providerId;
  final String providerName;

  const BookingScreen({
    super.key,
    required this.providerData,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final TextEditingController _descriptionController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitBooking() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both date and time'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get customer ID from local storage
      final customerId = await LocalStorageService.getMockUserId();

      if (customerId == null || customerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Customer ID not found'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Create booking data
      final bookingData = {
        'customer_id': customerId,
        'provider_id': widget.providerId,
        'booking_date': _selectedDate!.toIso8601String().split('T')[0], // YYYY-MM-DD format
        'booking_time': _selectedTime!.format(context), // HH:MM format
        'description': _descriptionController.text.isEmpty
            ? 'Service booking'
            : _descriptionController.text,
        'status': 'pending',
      };

      print('[BOOKING] Submitting booking: $bookingData');

      // Insert booking into database
      await sb.Supabase.instance.client.from('bookings').insert(bookingData);

      print('[BOOKING] Booking submitted successfully');

      if (!mounted) return;

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      print('[BOOKING] Error submitting booking: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Booking Confirmed!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildDialogDetailRow('Provider', widget.providerName),
            const SizedBox(height: 10),
            _buildDialogDetailRow('Date', _selectedDate!.toString().split(' ')[0]),
            const SizedBox(height: 10),
            _buildDialogDetailRow('Time', _selectedTime!.format(context)),
            const SizedBox(height: 20),
            const Text(
              'Your booking has been submitted. The provider will contact you soon to confirm.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.of(context).pop(); // Close dialog
              if (!mounted) return;
              Navigator.of(context).pop(); // Close booking screen
              if (!mounted) return;
              Navigator.of(context).pop(); // Close provider profile
              if (!mounted) return;
              // Navigate back to CustomerHomeScreen
              Navigator.of(context).pushReplacementNamed('/customer-home');
            },
            child: const Text(
              'Continue Shopping',
              style: TextStyle(color: Color(0xFF5E60CE)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E17),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Book Service',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider Info Summary
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0x30FFFFFF),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF5E60CE).withOpacity(0.2),
                      radius: 20,
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF5E60CE),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Service Provider',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            widget.providerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Date Selection
              const Text(
                'Select Date',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    setState(() => _selectedDate = pickedDate);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0x30FFFFFF),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF5E60CE)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedDate == null
                              ? 'Select booking date'
                              : _selectedDate!.toString().split(' ')[0],
                          style: TextStyle(
                            color: _selectedDate == null
                                ? Colors.white54
                                : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white30, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time Selection
              const Text(
                'Select Time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (pickedTime != null) {
                    setState(() => _selectedTime = pickedTime);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0x30FFFFFF),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF5E60CE)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedTime == null
                              ? 'Select booking time'
                              : _selectedTime!.format(context),
                          style: TextStyle(
                            color: _selectedTime == null
                                ? Colors.white54
                                : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white30, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Description
              const Text(
                'Description (Optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x30FFFFFF),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24),
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Describe the work you need...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(15),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E60CE),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    disabledBackgroundColor: Colors.grey[700],
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm Booking',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ADMIN PANEL SCREENS - HIGH SECURITY
// ============================================================================

// Admin Dashboard - Main hub with sidebar navigation
class AdminDashboardScreen extends StatefulWidget {
  final String userId;

  const AdminDashboardScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _verifyAdminRole();
  }

  Future<void> _verifyAdminRole() async {
    // Security: Verify admin role on every dashboard load
    final userList = await sb.Supabase.instance.client
        .from('users')
        .select()
        .eq('id', widget.userId)
        .limit(1);

    if (!mounted) return;

    if (userList.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    final userRole = userList[0]['role'] as String?;
    if (userRole != 'admin') {
      print('[ADMIN] SECURITY BREACH: Non-admin user attempted to access admin panel');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unauthorized: Admin access required'),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 280,
            color: const Color(0xFF1A1F2E),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E60CE),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5E60CE).withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Service Hub Management',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildSidebarItem(
                        index: 0,
                        icon: Icons.dashboard,
                        label: 'Dashboard Overview',
                        onTap: () {
                          setState(() => _selectedIndex = 0);
                        },
                      ),
                      _buildSidebarItem(
                        index: 1,
                        icon: Icons.verified_user,
                        label: 'Verify Providers',
                        onTap: () {
                          setState(() => _selectedIndex = 1);
                        },
                      ),
                      _buildSidebarItem(
                        index: 2,
                        icon: Icons.calendar_today,
                        label: 'Bookings Overview',
                        onTap: () {
                          setState(() => _selectedIndex = 2);
                        },
                      ),
                    ],
                  ),
                ),
                // Logout Button
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        LocalStorageService.clearMockUserId();
                        Navigator.of(context).pushReplacementNamed('/');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Container(
              color: const Color(0xFF0A0E17),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF5E60CE).withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: const Color(0xFF5E60CE), width: 2)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF5E60CE) : Colors.white70,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const AdminOverviewScreen();
      case 1:
        return const ProviderVerificationScreen();
      case 2:
        return const BookingsOverviewScreen();
      default:
        return const AdminOverviewScreen();
    }
  }
}

// Admin Overview Dashboard
class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F2E),
        elevation: 0,
        title: const Text(
          'Dashboard Overview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Users',
                    future: _fetchTotalUsers(),
                    icon: Icons.people,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatCard(
                    title: 'Pending Providers',
                    future: _fetchPendingProviders(),
                    icon: Icons.hourglass_empty,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatCard(
                    title: 'Active Bookings',
                    future: _fetchActiveBookings(),
                    icon: Icons.check_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Recent Activities',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0x30FFFFFF),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'System is operational and ready for management.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required Future<int> future,
    required IconData icon,
  }) {
    return FutureBuilder<int>(
      future: future,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data ?? 0 : 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0x30FFFFFF),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF5E60CE), size: 32),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int> _fetchTotalUsers() async {
    final userRole = await _verifyAdminAccess();
    if (userRole != 'admin') return 0;

    try {
      final response = await sb.Supabase.instance.client
          .from('users')
          .select('id');
      return response.length;
    } catch (e) {
      print('[ADMIN] Error fetching total users: $e');
      return 0;
    }
  }

  Future<int> _fetchPendingProviders() async {
    final userRole = await _verifyAdminAccess();
    if (userRole != 'admin') return 0;

    try {
      final response = await sb.Supabase.instance.client
          .from('users')
          .select('id')
          .eq('role', 'provider')
          .eq('is_verified', false);
      return response.length;
    } catch (e) {
      print('[ADMIN] Error fetching pending providers: $e');
      return 0;
    }
  }

  Future<int> _fetchActiveBookings() async {
    final userRole = await _verifyAdminAccess();
    if (userRole != 'admin') return 0;

    try {
      final response = await sb.Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('status', 'pending');
      return response.length;
    } catch (e) {
      print('[ADMIN] Error fetching active bookings: $e');
      return 0;
    }
  }

  Future<String> _verifyAdminAccess() async {
    final mockUserId = await LocalStorageService.getMockUserId();
    if (mockUserId == null) return '';

    try {
      final response = await sb.Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', mockUserId)
          .limit(1);
      return response.isNotEmpty ? (response[0]['role'] as String?) ?? '' : '';
    } catch (e) {
      print('[ADMIN] Error verifying admin access: $e');
      return '';
    }
  }
}

// Provider Verification Screen
class ProviderVerificationScreen extends StatefulWidget {
  const ProviderVerificationScreen({super.key});

  @override
  State<ProviderVerificationScreen> createState() =>
      _ProviderVerificationScreenState();
}

class _ProviderVerificationScreenState extends State<ProviderVerificationScreen> {
  Future<List<Map<String, dynamic>>> _fetchUnverifiedProviders() async {
    // Security: Verify admin role before fetching
    final mockUserId = await LocalStorageService.getMockUserId();
    if (mockUserId == null) return [];

    try {
      final userList = await sb.Supabase.instance.client
          .from('users')
          .select()
          .eq('id', mockUserId)
          .limit(1);

      if (userList.isEmpty || userList[0]['role'] != 'admin') {
        print('[PROVIDER_VERIFY] SECURITY: Non-admin attempted to access verification');
        return [];
      }

      // Fetch unverified providers
      final providers = await sb.Supabase.instance.client.from('providers').select();

      List<Map<String, dynamic>> unverifiedProviders = [];
      for (var provider in providers) {
        final providerId = provider['uid'] as String?;
        if (providerId == null) continue;

        final userDataList = await sb.Supabase.instance.client
            .from('users')
            .select()
            .eq('id', providerId)
            .limit(1);

        if (userDataList.isNotEmpty) {
          final isVerified = userDataList[0]['is_verified'] as bool? ?? false;
          if (!isVerified) {
            unverifiedProviders.add({
              ...provider,
              'user_data': userDataList[0],
            });
          }
        }
      }

      return unverifiedProviders;
    } catch (e) {
      print('[PROVIDER_VERIFY] Error: $e');
      return [];
    }
  }

  Future<void> _approveProvider(String providerId, String providerName) async {
    // Security: Double-check admin role
    final mockUserId = await LocalStorageService.getMockUserId();
    if (mockUserId == null) return;

    final adminCheckList = await sb.Supabase.instance.client
        .from('users')
        .select()
        .eq('id', mockUserId)
        .limit(1);

    if (adminCheckList.isEmpty || adminCheckList[0]['role'] != 'admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unauthorized: Admin access required'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      // Update is_verified to true
      await sb.Supabase.instance.client
          .from('users')
          .update({'is_verified': true})
          .eq('id', providerId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$providerName has been approved!'),
          backgroundColor: Colors.greenAccent,
        ),
      );

      // Refresh the list
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving provider: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F2E),
        elevation: 0,
        title: const Text(
          'Provider Verification',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUnverifiedProviders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5E60CE)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final providers = snapshot.data ?? [];

          if (providers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 64,
                    color: Colors.green.withOpacity(0.5),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'All providers verified!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              final name = (provider['name'] as String?) ?? 'Unknown';
              final category = (provider['category'] as String?) ?? 'N/A';
              final experience = (provider['experience'] as String?) ?? 'Not specified';
              final nicImage = (provider['nic_image'] as String?) ?? '';
              final certImage = (provider['certificate_image'] as String?) ?? '';
              final providerId = (provider['uid'] as String?) ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0x30FFFFFF),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24),
                ),
                child: ExpansionTile(
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    category,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF5E60CE).withOpacity(0.2),
                    child: const Icon(Icons.person, color: Color(0xFF5E60CE)),
                  ),
                  collapsedBackgroundColor: Colors.transparent,
                  textColor: Colors.white,
                  collapsedTextColor: Colors.white,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Category', category),
                          const SizedBox(height: 10),
                          _buildDetailRow('Experience', experience),
                          const SizedBox(height: 20),
                          const Text(
                            'NIC Image:',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          nicImage.isNotEmpty
                              ? Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.black26,
                                  ),
                                  child: Image.network(
                                    nicImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(
                                      child: Text(
                                        'Failed to load image',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                )
                              : const Text(
                                  'No image provided',
                                  style: TextStyle(color: Colors.white70),
                                ),
                          const SizedBox(height: 20),
                          const Text(
                            'Certificate Image:',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          certImage.isNotEmpty
                              ? Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.black26,
                                  ),
                                  child: Image.network(
                                    certImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(
                                      child: Text(
                                        'Failed to load image',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                )
                              : const Text(
                                  'No image provided',
                                  style: TextStyle(color: Colors.white70),
                                ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _approveProvider(providerId, name);
                              },
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Approve Provider'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Bookings Overview Screen
class BookingsOverviewScreen extends StatefulWidget {
  const BookingsOverviewScreen({super.key});

  @override
  State<BookingsOverviewScreen> createState() => _BookingsOverviewScreenState();
}

class _BookingsOverviewScreenState extends State<BookingsOverviewScreen> {
  Future<List<Map<String, dynamic>>> _fetchAllBookings() async {
    // Security: Verify admin role
    final mockUserId = await LocalStorageService.getMockUserId();
    if (mockUserId == null) return [];

    try {
      final userList = await sb.Supabase.instance.client
          .from('users')
          .select()
          .eq('id', mockUserId)
          .limit(1);

      if (userList.isEmpty || userList[0]['role'] != 'admin') {
        print('[BOOKINGS] SECURITY: Non-admin attempted to access bookings');
        return [];
      }

      // Fetch all bookings
      final bookings = await sb.Supabase.instance.client
          .from('bookings')
          .select()
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> enrichedBookings = [];
      for (var booking in bookings) {
        final customerId = booking['customer_id'] as String?;
        final providerId = booking['provider_id'] as String?;

        String customerName = 'Unknown';
        String providerName = 'Unknown';

        // Fetch customer name
        if (customerId != null) {
          try {
            final customerList = await sb.Supabase.instance.client
                .from('users')
                .select('phone')
                .eq('id', customerId)
                .limit(1);
            if (customerList.isNotEmpty) {
              customerName = customerList[0]['phone'] as String? ?? 'Unknown';
            }
          } catch (e) {
            print('[BOOKINGS] Error fetching customer: $e');
          }
        }

        // Fetch provider name
        if (providerId != null) {
          try {
            final providerList = await sb.Supabase.instance.client
                .from('providers')
                .select('name')
                .eq('uid', providerId)
                .limit(1);
            if (providerList.isNotEmpty) {
              providerName = providerList[0]['name'] as String? ?? 'Unknown';
            }
          } catch (e) {
            print('[BOOKINGS] Error fetching provider: $e');
          }
        }

        enrichedBookings.add({
          ...booking,
          'customer_name': customerName,
          'provider_name': providerName,
        });
      }

      return enrichedBookings;
    } catch (e) {
      print('[BOOKINGS] Error fetching bookings: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F2E),
        elevation: 0,
        title: const Text(
          'Bookings Overview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5E60CE)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No bookings yet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Bookings: ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  bookings.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Responsive Table
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateColor.resolveWith(
                        (states) => const Color(0xFF5E60CE).withOpacity(0.3),
                      ),
                      dataRowColor: MaterialStateColor.resolveWith(
                        (states) => const Color(0x30FFFFFF),
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Customer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Provider',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Date',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      rows: bookings
                          .map(
                            (booking) => DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    (booking['customer_name'] as String?) ?? 'Unknown',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (booking['provider_name'] as String?) ?? 'Unknown',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (booking['booking_date'] as String?) ?? 'N/A',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: booking['status'] == 'pending'
                                          ? Colors.orange.withOpacity(0.2)
                                          : Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: booking['status'] == 'pending'
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                    ),
                                    child: Text(
                                      ((booking['status'] as String?) ?? 'pending')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: booking['status'] == 'pending'
                                            ? Colors.orange
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
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

    Future.delayed(const Duration(seconds: 3), () {
      // Route to admin login on web, customer onboarding on mobile
      final nextScreen = kIsWeb ? const LoginScreen() : const OnboardingScreen();
      
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (context, animation, secondaryAnimation) =>
              nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
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
      body: Stack(
        children: [
          Center(
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
                          color: const Color(0xFF00E5FF).withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'S',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Ceylon Service Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Premium Expert Solutions',
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
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: FadeTransition(
                opacity: _animation,
                child: const Text(
                  'Powered by Oshitha',
                  style: TextStyle(
                    color: Colors.white24,
                    letterSpacing: 4,
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": "Find Experts",
      "desc":
          "Discover the best verified professionals like electricians, plumbers, and more in seconds.",
      "icon": Icons.search_rounded,
    },
    {
      "title": "Verify Identity",
      "desc":
          "Our unique glassmorphism registration ensures safety by tracking data securely.",
      "icon": Icons.verified_user_rounded,
    },
    {
      "title": "Call Instantly",
      "desc":
          "Connect immediately with one single tap. Say goodbye to long waits.",
      "icon": Icons.phone_in_talk_rounded,
    },
  ];

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const UserTypeSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _onboardingData.length,
                  itemBuilder: (context, index) {
                    return _buildOnboardingPage(_onboardingData[index]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        _onboardingData.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 10,
                          width: _currentPage == index ? 30 : 10,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFF5E60CE)
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        if (_currentPage == _onboardingData.length - 1) {
                          _finishOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFBD00FF), Color(0xFF5E60CE)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBD00FF).withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          _currentPage == _onboardingData.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0x30FFFFFF),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(data["icon"], size: 100, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 50),
          Text(
            data["title"],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data["desc"],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF5E60CE).withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        size: 50,
                        color: Color(0xFF5E60CE),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Welcome to Ceylon Service Hub',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'What would you like to do?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Selection Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Hire Someone Button
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CustomerRegistrationScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.1),
                          border: Border.all(
                            color: const Color(0xFF00E5FF),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.shopping_bag,
                              size: 50,
                              color: Color(0xFF00E5FF),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'I want to Hire someone',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Find and book verified service professionals',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Provide Service Button
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProviderRegistrationPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBD00FF).withOpacity(0.1),
                          border: Border.all(
                            color: const Color(0xFFBD00FF),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.build,
                              size: 50,
                              color: Color(0xFFBD00FF),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'I want to Provide a Service',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Register as a provider and expand your business',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Back to Login Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState extends State<CustomerRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  void _proceedToOtp() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    print('[CUSTOMER_REG] Proceeding to OTP with phone: $phone, name: $name');

    // Navigate to OTP verification with customer flag
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phone: phone,
          providerData: {
            'name': name,
            'email': '', // Customers don't provide email in this flow
            'role': 'customer', // Mark as customer
          },
          isCustomer: true, // New flag to indicate customer flow
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Register as Customer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Customer Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.person, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFF00E5FF))
                  : ElevatedButton(
                      onPressed: _proceedToOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Verify Phone Number',
                        style: TextStyle(
                          color: Color(0xFF0A0E17),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Go Back',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class CustomerHomeScreen extends StatelessWidget {
  final String? userId;

  const CustomerHomeScreen({super.key, this.userId});

  static const List<String> serviceCategories = [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Carpentry',
    'Painting',
    'HVAC',
    'Gardening',
    'Locksmith',
    'Appliance Repair',
    'Pest Control',
  ];

  static const Map<String, IconData> categoryIcons = {
    'Plumbing': Icons.plumbing,
    'Electrical': Icons.electric_bolt,
    'Cleaning': Icons.cleaning_services,
    'Carpentry': Icons.carpenter,
    'Painting': Icons.format_paint,
    'HVAC': Icons.ac_unit,
    'Gardening': Icons.grass,
    'Locksmith': Icons.vpn_key,
    'Appliance Repair': Icons.settings,
    'Pest Control': Icons.bug_report,
  };

  void _navigateToProviders(BuildContext context, String category) {
    print('[CUSTOMER_HOME] Navigating to providers for category: $category');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderListScreen(selectedCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Find Services',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white70),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(
                    userData: {},
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search services...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // Categories Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                  ),
                  itemCount: serviceCategories.length,
                  itemBuilder: (context, index) {
                    final category = serviceCategories[index];
                    final icon = categoryIcons[category] ?? Icons.build;

                    return GestureDetector(
                      onTap: () => _navigateToProviders(context, category),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF5E60CE).withOpacity(0.2),
                              ),
                              child: Icon(
                                icon,
                                size: 40,
                                color: const Color(0xFF5E60CE),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              category,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> providerData;
  final bool isCustomer;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.providerData,
    this.isCustomer = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  int _start = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => _start = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _currentOtp;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      // 🔧 MOCK OTP VERIFICATION FOR TESTING
      // In production, this would call: sb.Supabase.instance.client.auth.verifyOTP()
      print('[OTP_DEBUG] MOCK MODE: Checking if OTP is 123456...');
      
      if (otp != '123456') {
        // Invalid OTP - show error
        print('[OTP_DEBUG] MOCK MODE: OTP verification failed - incorrect code');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid OTP. Please enter 123456 for testing.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      print('[OTP_DEBUG] MOCK MODE: OTP verified successfully (123456)');
      
      // Generate a mock user ID for testing
      final mockUserId = 'mock_user_${DateTime.now().millisecondsSinceEpoch}';
      print('[OTP_DEBUG] MOCK MODE: Created mock user ID: $mockUserId');

      // Determine user type
      final bool isProvider = widget.providerData.containsKey('category');
      final bool isCustomer = widget.isCustomer || !isProvider;
      
      print('[OTP_DEBUG] MOCK MODE: Saving user data (isProvider: $isProvider, isCustomer: $isCustomer)...');
      
      // Build users table data safely
      final Map<String, dynamic> userData = {
        'id': mockUserId,
        'phone': widget.phone,
        'role': isCustomer ? 'customer' : 'provider',
        'is_verified': isCustomer, // Customers verified immediately, providers pending
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add email only if it exists and is not empty
      final String? email = widget.providerData['email'] as String?;
      if (email != null && email.isNotEmpty) {
        userData['email'] = email;
      } else {
        userData['email'] = ''; // Default empty for customers
      }

      // Only providers get status field
      if (!isCustomer) {
        userData['status'] = 'pending';
      }

      print('[OTP_DEBUG] MOCK MODE: Users table data: $userData');
      
      // Upsert users table with clean data
      await sb.Supabase.instance.client.from('users').upsert(userData);
      print('[OTP_DEBUG] MOCK MODE: User data saved to users table');

      // Save mock user ID to local storage for persistence
      await LocalStorageService.saveMockUserId(mockUserId);
      print('[OTP_DEBUG] MOCK MODE: Mock user ID saved to local storage');

      // If provider, also save provider data to providers table
      if (isProvider) {
        print('[OTP_DEBUG] MOCK MODE: Saving provider data...');
        
        // Safely extract provider fields with null checks
        final String? providerName = widget.providerData['name'] as String?;
        final String? category = widget.providerData['category'] as String?;
        final String? experience = widget.providerData['experience'] as String?;
        final String? nicUrl = widget.providerData['nicUrl'] as String?;
        final String? certUrl = widget.providerData['certUrl'] as String?;

        final Map<String, dynamic> providerData = {
          'uid': mockUserId,
          'name': providerName ?? 'Unknown Provider',
          'category': category ?? 'General',
          'experience': experience ?? '',
          'nic_image': nicUrl ?? '',
          'certificate_image': certUrl ?? '',
          'location_lat': 0.0,
          'location_lng': 0.0,
          'created_at': DateTime.now().toIso8601String(),
        };

        await sb.Supabase.instance.client.from('providers').upsert(providerData);
        print('[OTP_DEBUG] MOCK MODE: Provider data saved successfully');
      }

      if (mounted) {
        final role = isCustomer ? 'customer' : 'provider';
        print('[OTP_DEBUG] MOCK MODE: Showing success dialog for role: $role');
        
        // Show success dialog, then navigate appropriately
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => RegistrationSuccessDialog(
            role: role,
            onClose: () {
              if (!mounted) return;
              Navigator.of(context).pop(); // Close dialog
              
              if (!mounted) return;
              if (isCustomer) {
                // Customers go directly to home screen
                print('[OTP_DEBUG] MOCK MODE: Navigating to CustomerHomeScreen');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => CustomerHomeScreen(userId: mockUserId),
                  ),
                  (route) => false,
                );
              } else {
                // Providers go to pending approval screen
                print('[OTP_DEBUG] MOCK MODE: Navigating to PendingApprovalScreen with userId: $mockUserId');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => PendingApprovalScreen(userId: mockUserId),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        );
      }
    } catch (e) {
      print('[OTP_DEBUG] MOCK MODE: Exception during mock verification: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Verify Phone',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0x30FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.security,
                          size: 60,
                          color: Color(0xFF5E60CE),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Enter OTP',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'We texted a 6-digit code to your number.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 30),

                        // 6 Digital OTP Fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 40,
                              height: 55,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.2),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFBD00FF),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    if (index < 5) {
                                      _focusNodes[index + 1].requestFocus();
                                    } else {
                                      _focusNodes[index].unfocus();
                                      if (_currentOtp.length == 6) {
                                        _verifyOtp();
                                      }
                                    }
                                  } else {
                                    if (index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  }
                                },
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 30),
                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFFBD00FF),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.0),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFBD00FF),
                                      Color(0xFF5E60CE),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFBD00FF,
                                      ).withOpacity(0.5),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _verifyOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Verify to Register',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _start == 0
                              ? () {
                                  _startTimer();
                                  // Logic to resend OTP goes here
                                }
                              : null,
                          child: Text(
                            _start == 0
                                ? 'Resend OTP'
                                : 'Resend OTP in $_start s',
                            style: TextStyle(
                              color: _start == 0
                                  ? const Color(0xFFBD00FF)
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final bool _isEmailLogin = false;

  void _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await sb.Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      String msg = e.toString();
      if (e is sb.AuthException) msg = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter 10-digit phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    String standardPhone =
        '+94${phone.startsWith('0') ? phone.substring(1) : phone}';

    // 🔧 MOCK MODE: Bypass real Supabase Auth API
    // In production, would call: sb.Supabase.instance.client.auth.signInWithOtp()
    print('[LOGIN_DEBUG] MOCK MODE: Skipping real phone authentication');
    setState(() => _isLoading = false);

    if (mounted) {
      print('[LOGIN_DEBUG] MOCK MODE: Navigating to OTP verification screen');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phone: standardPhone,
            providerData: {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0x30FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Enter Phone Number',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '07XXXXXXXX',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Color(0xFFBD00FF), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFFBD00FF),
                              )
                            : ElevatedButton(
                                onPressed: _sendOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFBD00FF),
                                  minimumSize: const Size(double.infinity, 55),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const Text(
                                  'Send OTP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 30),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ProviderRegistrationPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Want to provide services? Register Now',
                            style: TextStyle(color: Color(0xFF00E5FF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookingDetailsScreen extends StatefulWidget {
  final String serviceName;
  const BookingDetailsScreen({super.key, required this.serviceName});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  String _selectedTime = '09:00 AM';

  final List<String> _timeSlots = [
    '09:00 AM',
    '11:30 AM',
    '01:00 PM',
    '03:00 PM',
    '06:30 PM',
  ];

  Future<void> _proceedToPayment() async {
    final user = sb.Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue.')),
      );
      return;
    }

    try {
      // Create initial unpaid booking
      final response = await sb.Supabase.instance.client.from('bookings').insert({
            'service': widget.serviceName,
            'date':
                _selectedDay?.toIso8601String() ??
                DateTime.now().toIso8601String(),
            'time': _selectedTime,
            'userId': user.id,
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'unpaid',
          }).select();

      if (!mounted) return;
      final bookingId = response[0]['id'].toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            bookingId: bookingId,
            serviceName: widget.serviceName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${widget.serviceName} Booking',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose Date',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Premium Dark Table Calendar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.now(),
                          lastDay: DateTime.now().add(const Duration(days: 90)),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          calendarStyle: CalendarStyle(
                            defaultTextStyle: const TextStyle(
                              color: Colors.white70,
                            ),
                            weekendTextStyle: const TextStyle(
                              color: Colors.cyanAccent,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: Color(0xFFBD00FF),
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleTextStyle: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            leftChevronIcon: Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(color: Colors.white54),
                            weekendStyle: TextStyle(color: Colors.cyanAccent),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      const Text(
                        'Available Slots',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Grid of ChoiceChips
                      Wrap(
                        spacing: 12,
                        runSpacing: -5,
                        children: _timeSlots.map((time) {
                          return ChoiceChip(
                            label: Text(time),
                            selected: _selectedTime == time,
                            onSelected: (selected) {
                              if (selected)
                                setState(() => _selectedTime = time);
                            },
                            padding: const EdgeInsets.all(12),
                            selectedColor: const Color(
                              0xFFBD00FF,
                            ).withOpacity(0.6),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            labelStyle: TextStyle(
                              color: _selectedTime == time
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                            side: BorderSide(
                              color: _selectedTime == time
                                  ? const Color(0xFFBD00FF)
                                  : Colors.white12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // Bottom Booking Summary Card
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131826).withOpacity(0.8),
                      border: const Border(
                        top: BorderSide(color: Colors.white12),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.serviceName} Service',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_selectedDay?.day}/${_selectedDay?.month} ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ $_selectedTime',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: _proceedToPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBD00FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 15,
                                shadowColor: const Color(
                                  0xFFBD00FF,
                                ).withOpacity(0.5),
                              ),
                              child: const Text(
                                'Proceed to Payment',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = sb.Supabase.instance.client.auth.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Service History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: user == null
              ? const Center(
                  child: Text(
                    'Please login to view history',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : FutureBuilder<List<Map<String, dynamic>>>(
                  future: sb.Supabase.instance.client
                      .from('bookings')
                      .select()
                      .eq('userId', user.id)
                      .order('createdAt', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFBD00FF),
                        ),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 80,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No Bookings Yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Start your journey with us today!',
                              style: TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBD00FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Book Now',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final bookings = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        final dateStr = booking['date'] ?? '';
                        final date =
                            DateTime.tryParse(dateStr) ?? DateTime.now();
                        final status = booking['status'] ?? 'pending';

                        return _buildBookingCard(
                          context,
                          bookingId: booking['id'].toString(),
                          service: booking['service'] ?? 'Expert Service',
                          date: '${date.day}/${date.month}/${date.year}',
                          time: booking['time'] ?? 'Flexible',
                          status: status,
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context, {
    required String bookingId,
    required String service,
    required String date,
    required String time,
    required String status,
  }) {
    Color statusColor = status == 'pending'
        ? Colors.amberAccent
        : Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBD00FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.handyman_outlined,
                    color: Color(0xFFBD00FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$date ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ $time',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (status == 'completed') ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            _showRatingDialog(context, bookingId, service),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'RATE EXPERT',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRatingDialog(
    BuildContext context,
    String bookingId,
    String service,
  ) {
    double selectedRating = 5.0;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131826),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
        ),
        title: Text(
          'Rate $service',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBar.builder(
              initialRating: 5,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 40,
              unratedColor: Colors.white10,
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: Colors.cyanAccent),
              onRatingUpdate: (rating) => selectedRating = rating,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: commentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await sb.Supabase.instance.client.from('reviews').insert({
                'bookingId': bookingId,
                'expertName': service,
                'rating': selectedRating,
                'comment': commentController.text.trim(),
                'timestamp': DateTime.now().toIso8601String(),
                'userId': sb.Supabase.instance.client.auth.currentUser?.id,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Review Submitted! Thank you.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'SUBMIT',
              style: TextStyle(
                color: Color(0xFF131826),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String expertName;
  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.expertName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final user = sb.Supabase.instance.client.auth.currentUser;

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || user == null) return;

    final message = {
      'text': _messageController.text.trim(),
      'senderId': user!.id,
      'bookingId': widget.bookingId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _messageController.clear();
    await sb.Supabase.instance.client.from('messages').insert(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFBD00FF),
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                Container(
                  height: 10,
                  width: 10,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xFF0A0E17), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.expertName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Online',
                  style: TextStyle(fontSize: 11, color: Colors.greenAccent),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: sb.Supabase.instance.client
                    .from('messages')
                    .select()
                    .eq('bookingId', widget.bookingId)
                    .order('timestamp', ascending: true),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFBD00FF),
                      ),
                    );

                  final messages = snapshot.data!;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['senderId'] == user?.id;

                      return _buildMessageBubble(msg['text'], isMe);
                    },
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    Color bubbleColor = isMe
        ? const Color(0xFF00E5FF).withOpacity(0.1)
        : const Color(0xFFBD00FF).withOpacity(0.1);
    Color borderColor = isMe
        ? const Color(0xFF00E5FF).withOpacity(0.3)
        : const Color(0xFFBD00FF).withOpacity(0.3);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String serviceName;
  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.serviceName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String cardNumber = '';
  String expiryDate = '';
  String cardHolderName = '';
  String cvvCode = '';
  bool isCvvFocused = false;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  Future<void> _processPayment() async {
    if (formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF131826),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: Color(0xFF00E5FF)),
                SizedBox(height: 20),
                Text(
                  'Processing Payment...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Update status in Supabase
      await sb.Supabase.instance.client
          .from('bookings')
          .update({'status': 'Paid'})
          .eq('id', widget.bookingId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuccessScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Secure Payment'),
      ),
      backgroundColor: const Color(0xFF0A0E17),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              CreditCardWidget(
                cardNumber: cardNumber,
                expiryDate: expiryDate,
                cardHolderName: cardHolderName,
                cvvCode: cvvCode,
                showBackView: isCvvFocused,
                obscureCardNumber: true,
                obscureCardCvv: true,
                isHolderNameVisible: true,
                cardBgColor: const Color(0xFF131826),
                glassmorphismConfig: Glassmorphism.defaultConfig(),
                backgroundImage: null,
                onCreditCardWidgetChange: (CreditCardBrand brand) {},
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CreditCardForm(
                        formKey: formKey,
                        cardNumber: cardNumber,
                        expiryDate: expiryDate,
                        cardHolderName: cardHolderName,
                        cvvCode: cvvCode,
                        onCreditCardModelChange: (data) {
                          setState(() {
                            cardNumber = data.cardNumber;
                            expiryDate = data.expiryDate;
                            cardHolderName = data.cardHolderName;
                            cvvCode = data.cvvCode;
                            isCvvFocused = data.isCvvFocused;
                          });
                        },
                        obscureCvv: true,
                        obscureNumber: true,
                        isHolderNameVisible: true,
                        isCardNumberVisible: true,
                        isExpiryDateVisible: true,
                      ),
                      const SizedBox(height: 20),
                      _buildSummaryCard(),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ElevatedButton(
                          onPressed: _processPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: const Color(0xFF131826),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'Pay LKR 1,500.00',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _summaryRow('Service Fee', 'LKR 1,350'),
          const SizedBox(height: 10),
          _summaryRow('Tax (10%)', 'LKR 150'),
          const Divider(color: Colors.white10, height: 30),
          _summaryRow('Total Amount', 'LKR 1,500', isBold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? Colors.white : Colors.white70,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? const Color(0xFF00E5FF) : Colors.white,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
              size: 100,
            ),
            const SizedBox(height: 30),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your verified expert will arrive soon.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DashboardScreen(role: 'customer')),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBD00FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Go to Home',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: (widget.userData['name'] as String?) ?? '');
    _phoneController = TextEditingController(text: (widget.userData['phone'] as String?) ?? '');
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = sb.Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      await sb.Supabase.instance.client
          .from('users')
          .update({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
          })
          .eq('id', userId);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile Updated Successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Full Name', Icons.person),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Phone Number', Icons.phone),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBD00FF),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white12),
      ),
    );
  }
}

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = sb.Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Payment Methods'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: uid != null
            ? sb.Supabase.instance.client
                .from('cards')
                .select()
                .eq('uid', uid)
            : Future.value([]),
        builder: (context, snapshot) {
          List<Widget> children = [];

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            children.addAll(
              snapshot.data!.map((data) {
                return _buildCardTile(
                  '${data['brand'] ?? 'Card'} ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ ${data['last4'] ?? '****'}',
                  'Expires ${data['expiry'] ?? 'N/A'}',
                  Icons.credit_card,
                );
              }).toList(),
            );
          } else {
            // Mock data if Firestore is empty but user wants to see something
            children.addAll([
              _buildCardTile(
                'Visa ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ 4242',
                'Expires 12/24',
                Icons.credit_card,
              ),
              _buildCardTile(
                'MasterCard ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ 8888',
                'Expires 05/26',
                Icons.credit_card,
              ),
            ]);
          }

          children.add(const SizedBox(height: 30));
          children.add(
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add New Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBD00FF),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          );

          return ListView(
            padding: const EdgeInsets.all(24),
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildCardTile(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 30),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.more_vert, color: Colors.white24),
        tileColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: const Text(
              'Push Notifications',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Receive booking updates',
              style: TextStyle(color: Colors.white54),
            ),
            value: _notifications,
            onChanged: (val) => setState(() => _notifications = val),
            activeThumbColor: const Color(0xFFBD00FF),
          ),
          SwitchListTile(
            title: const Text(
              'Dark Mode',
              style: TextStyle(color: Colors.white),
            ),
            value: _darkMode,
            onChanged: (val) => setState(() => _darkMode = val),
            activeThumbColor: const Color(0xFFBD00FF),
          ),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            tileColor: Colors.redAccent.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            onTap: () {
              sb.Supabase.instance.client.auth.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class GeneralSignUpPage extends StatefulWidget {
  const GeneralSignUpPage({super.key});

  @override
  State<GeneralSignUpPage> createState() => _GeneralSignUpPageState();
}

class _GeneralSignUpPageState extends State<GeneralSignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isProvider = false;
  bool _isLoading = false;

  void _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    if (_isProvider) {
      // If provider, we take them to the stepped registration first, or after initial auth
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProviderRegistrationPage()),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await sb.Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      
      final userId = response.user!.id;
      
      await sb.Supabase.instance.client
          .from('users')
          .insert({
            'id': userId,
            'email': email,
            'role': 'customer',
            'is_verified': false, // All users pending verification until admin approves
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          });

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => RegistrationSuccessDialog(
            role: 'customer',
            onClose: () {
              Navigator.of(context).pop(); // Close dialog
              
              // Navigate to pending approval screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => PendingApprovalScreen(userId: userId),
                ),
                (route) => false,
              );
            },
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: const Color(0x30FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Join Service Hub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleTab('Find Services', !_isProvider),
                          ),
                          Expanded(
                            child: _buildRoleTab(
                              'Provide Services',
                              _isProvider,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _buildTextField(_emailController, 'Email', Icons.email),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _passwordController,
                        'Password',
                        Icons.lock,
                        isObscure: true,
                      ),
                      const SizedBox(height: 30),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBD00FF),
                                minimumSize: const Size(double.infinity, 55),
                              ),
                              child: Text(
                                _isProvider
                                    ? 'Continue to Registration'
                                    : 'Register Now',
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _isProvider = label.contains('Provide')),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFFBD00FF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isObscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        prefixIcon: Icon(icon, color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class ProviderRegistrationPage extends StatefulWidget {
  final String? existingUserId;

  const ProviderRegistrationPage({super.key, this.existingUserId});

  @override
  State<ProviderRegistrationPage> createState() =>
      _ProviderRegistrationPageState();
}

class _ProviderRegistrationPageState extends State<ProviderRegistrationPage> {
  int _currentStep = 0;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController(
    text: 'Hambantota',
  );
  final TextEditingController _experienceController = TextEditingController();

  String _selectedCategory = 'Plumbing';
  XFile? _nicImage;
  XFile? _certImage;

  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'AC Repair',
    'Cleaning',
    'Carpentry',
  ];

  Future<void> _pickImage(bool isNic) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null)
      setState(() => isNic ? _nicImage = image : _certImage = image);
  }

  Future<String?> _uploadFileToSupabase(XFile file, String filename) async {
    // 🔐 IMPORTANT: Ensure Supabase bucket 'nic-images' is set to Public in the dashboard:
    // Navigate to Supabase Dashboard → Storage → nic-images → Policies
    // Set the policy to allow public access for listed images.
    
    print('[SUPABASE_UPLOAD] Starting file upload for filename: $filename');
    try {
      final supabase = sb.Supabase.instance.client;
      final bucket = supabase.storage.from('nic-images');
      
      print('[SUPABASE_UPLOAD] Reading file bytes...');
      final fileBytes = await file.readAsBytes().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[SUPABASE_ERROR] File read timeout after 30 seconds');
          throw TimeoutException('File read took too long - 30 second timeout exceeded');
        },
      );
      print('[SUPABASE_UPLOAD] File bytes read successfully (${fileBytes.length} bytes)');
      
      // Upload file to Supabase Storage with timeout
      print('[SUPABASE_UPLOAD] Uploading file to Supabase Storage: $filename');
      await bucket.uploadBinary(
        filename,
        fileBytes,
        fileOptions: const sb.FileOptions(cacheControl: '3600', upsert: false),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[SUPABASE_ERROR] Upload timeout after 30 seconds');
          throw TimeoutException('Upload took too long - 30 second timeout exceeded');
        },
      );
      print('[SUPABASE_UPLOAD] File uploaded successfully');
      
      // Construct and return the public URL
      // Format: https://[project-url]/storage/v1/object/public/[bucket]/[filename]
      final publicUrl = 'https://namurnyqpcqjhqwcqeoj.supabase.co/storage/v1/object/public/nic-images/$filename';
      print('[SUPABASE_UPLOAD] Public URL generated: $publicUrl');
      
      return publicUrl;
    } on TimeoutException catch (e) {
      print('[SUPABASE_ERROR] TimeoutException: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload timeout: ${e.message}\nCheck internet connection.'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return null;
    } on sb.AuthException catch (e) {
      print('[SUPABASE_ERROR] AuthException - Code: ${e.statusCode}, Message: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.message}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return null;
    } catch (e) {
      print('[SUPABASE_ERROR] General Exception: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return null;
    }
  }

  void _submitRegistration() async {
    if (_nicImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload NIC copy'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    print('[REGISTRATION_DEBUG] Starting provider registration process...');
    
    try {
      // Generate unique filenames using timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nicFilename = 'nic_$timestamp.jpg';
      final certFilename = 'cert_$timestamp.jpg';
      
      // Upload NIC image to Supabase Storage with timeout
      print('[REGISTRATION_DEBUG] Step 1: Uploading NIC image...');
      String? nicUrl = await _uploadFileToSupabase(
        _nicImage!,
        nicFilename,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[REGISTRATION_ERROR] NIC upload timeout');
          throw TimeoutException('NIC upload took too long - 30 second timeout exceeded');
        },
      );
      
      if (nicUrl == null) {
        print('[REGISTRATION_ERROR] NIC upload returned null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload NIC. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      print('[REGISTRATION_DEBUG] NIC uploaded successfully: $nicUrl');
      
      // Upload certificate if provided
      print('[REGISTRATION_DEBUG] Step 2: Uploading certificate (if provided)...');
      String? certUrl;
      if (_certImage != null) {
        certUrl = await _uploadFileToSupabase(
          _certImage!,
          certFilename,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('[REGISTRATION_ERROR] Certificate upload timeout');
            throw TimeoutException('Certificate upload took too long - 30 second timeout exceeded');
          },
        );
        if (certUrl != null) {
          print('[REGISTRATION_DEBUG] Certificate uploaded: $certUrl');
        }
      }

      print('[REGISTRATION_DEBUG] Step 3: Preparing provider data...');
      final Map<String, dynamic> providerData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'category': _selectedCategory,
        'experience': _experienceController.text.trim(),
        'nicUrl': nicUrl,
        'certUrl': certUrl,
        'isVerified': false,
        'role': 'provider',
      };
      print('[REGISTRATION_DEBUG] Provider data prepared: $providerData');

      String standardPhone =
          '+94${_phoneController.text.trim().startsWith('0') ? _phoneController.text.trim().substring(1) : _phoneController.text.trim()}';
      print('[REGISTRATION_DEBUG] Standardized phone: $standardPhone');

      print('[REGISTRATION_DEBUG] Step 4: MOCK MODE - Skipping real phone authentication');
      // In production, would call: sb.Supabase.instance.client.auth.signInWithOtp()
      print('[REGISTRATION_DEBUG] MOCK MODE: Bypassing Supabase Auth API for phone provider');
      
      if (mounted) {
        print('[REGISTRATION_DEBUG] Step 5: Navigating to OTP verification screen...');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phone: standardPhone,
              providerData: providerData,
            ),
          ),
        );
        print('[REGISTRATION_DEBUG] Navigation completed successfully');
      }
    } catch (e) {
      print('[REGISTRATION_ERROR] Exception during registration: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // IMPORTANT: Ensure loading state is always reset to prevent spinner stuck
      print('[REGISTRATION_DEBUG] Resetting loading state...');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('[REGISTRATION_DEBUG] Registration process ended');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E17), Color(0xFF1A1F30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildCurrentStepView(),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) => _buildStepIndicator(index)),
          ),
          const SizedBox(height: 10),
          Text(
            _currentStep == 0
                ? 'Basic Info'
                : _currentStep == 1
                ? 'Professional'
                : 'Verification',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int index) {
    bool active = _currentStep == index;
    bool completed = _currentStep > index;
    return Container(
      width: (MediaQuery.of(context).size.width - 100) / 3,
      height: 4,
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFFBD00FF)
            : active
            ? const Color(0xFF5E60CE)
            : Colors.white10,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    if (_currentStep == 0) return _buildStep1();
    if (_currentStep == 1) return _buildStep2();
    return _buildStep3();
  }

  Widget _buildStep1() {
    return Column(
      children: [
        _buildTextField(_nameController, 'Full Name', Icons.person),
        const SizedBox(height: 16),
        _buildTextField(
          _phoneController,
          'Phone Number',
          Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(_locationController, 'Working Area', Icons.location_on),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _categories.map((cat) => _buildChip(cat)).toList(),
        ),
        const SizedBox(height: 30),
        _buildTextField(
          _experienceController,
          'Years of Experience',
          Icons.history,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        _buildUploadCard(
          'NIC Copy (Required)',
          _nicImage,
          () => _pickImage(true),
        ),
        const SizedBox(height: 20),
        _buildUploadCard(
          'Certificate (Optional)',
          _certImage,
          () => _pickImage(false),
        ),
      ],
    );
  }

  Widget _buildUploadCard(String title, XFile? file, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_upload_rounded,
                    color: Color(0xFFBD00FF),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: const TextStyle(color: Colors.white54)),
                ],
              )
            : kIsWeb
            ? _buildWebImagePreview(file)
            : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(file.path), fit: BoxFit.cover),
              ),
      ),
    );
  }

  // Web image preview using XFile.readAsBytes() and Image.memory()
  Widget _buildWebImagePreview(XFile file) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFBD00FF),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading image',
              style: TextStyle(color: Colors.red[400]),
            ),
          );
        }
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
            ),
          );
        }
        return const Center(
          child: Text(
            'No image data',
            style: TextStyle(color: Colors.white54),
          ),
        );
      },
    );
  }

  Widget _buildChip(String label) {
    bool selected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFBD00FF) : Colors.white10,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : Colors.white70),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                child: const Text('Back'),
              ),
            ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep < 2
                  ? () => setState(() => _currentStep++)
                  : (_isLoading ? null : _submitRegistration),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBD00FF),
                minimumSize: const Size(0, 55),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_currentStep < 2 ? 'Next' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        prefixIcon: Icon(icon, color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}


class SuperAdminScreen extends StatelessWidget {
  const SuperAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        title: const Text('Super Admin - Verifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1F30),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: sb.Supabase.instance.client
            .from('users')
            .select()
            .eq('role', 'provider')
            .eq('is_verified', false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No pending verifications', style: TextStyle(color: Colors.white54)));
          }

          final providers = snapshot.data!;

          return ListView.builder(
            itemCount: providers.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final provider = providers[index];
              final docId = provider['uid'];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2433),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFBD00FF),
                          child: Text(provider['name']?[0] ?? 'P', style: const TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(provider['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(provider['category'] ?? 'General', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Text(provider['phone'] ?? 'N/A', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.work, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Text('Exp:  Years', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _viewDocuments(context, provider['nicImageUrl']),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Docs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveProvider(context, docId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _rejectProvider(context, docId),
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _viewDocuments(BuildContext context, String? url) {
    if (url == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveProvider(BuildContext context, String docId) async {
    await sb.Supabase.instance.client
        .from('users')
        .update({'is_verified': true})
        .eq('id', docId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider Approved Successfully')));
    }
  }

  Future<void> _rejectProvider(BuildContext context, String docId) async {
    await sb.Supabase.instance.client
        .from('users')
        .delete()
        .eq('id', docId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider Rejected')));
    }
  }
}
