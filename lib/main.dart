import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/pages/book_transport.dart';
import 'package:truckmate/pages/email_otp_login_screen.dart';
import 'package:truckmate/pages/login.dart';
import 'package:truckmate/pages/seller_choice_screen.dart';
import 'package:truckmate/pages/seller_dashboard.dart';
import 'package:truckmate/pages/seller_registration_screen.dart';
import 'package:truckmate/pages/seller_waiting_confirmation.dart';
import 'package:truckmate/pages/profile_screen.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/email_otp_provider.dart';
import 'package:truckmate/providers/booking_provider.dart';
import 'package:truckmate/providers/seller_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: AppColors.darkLight,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => EmailOTPProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => SellerProvider()), // Add this
      ],
      child: MyApp(),
    ),
  );
}

class AppColors {
  static const Color primary = Color(0xFFC6FF00);
  static const Color primaryDark = Color(0xFF9ACC00);
  static const Color secondary = Color(0xFF7A8E99);
  static const Color dark = Color(0xFF0A0E27);
  static const Color darkLight = Color(0xFF1A1F3A);
  static const Color light = Color(0xFFFAFBFB);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textLight = Color(0xFF6C757D);
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFDC3545);
  static const Color lightgreen = Color(0xFF7ECF9A);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transport App',
      theme: ThemeData(
        primaryColor: const Color(0xFFC6FF00),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFFC6FF00),
          secondary: const Color(0xFF7A8E99),
          surface: const Color(0xFFFFFFFF),
          background: const Color(0xFFF8F9FA),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC6FF00),
            foregroundColor: const Color(0xFF0A0E27),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF0A0E27)),
          bodyMedium: TextStyle(color: Color(0xFF0A0E27)),
          titleLarge: TextStyle(
            color: Color(0xFF0A0E27),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const StartupRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({Key? key}) : super(key: key);

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  String? _startupChoice; // 'customer' | 'seller' | null
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadStartupChoice();
  }

  Future<void> _loadStartupChoice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _startupChoice = prefs.getString('startup_choice');
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_startupChoice == 'seller') {
      return const SellerChoiceScreen();
    }

    if (_startupChoice == 'customer') {
      return const AuthWrapper();
    }

    // No choice saved yet: show login choice screen
    return const ChooseLoginScreen();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        switch (authProvider.status) {
          case AuthStatus.uninitialized:
          case AuthStatus.loading:
            return Scaffold(
              backgroundColor: AppColors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          case AuthStatus.authenticated:
            final user = authProvider.user;
            if (user == null || user.needsProfileCompletion()) {
              return const ProfileCompletionScreen();
            }
            return BookTransportScreen();
          case AuthStatus.unauthenticated:
            return EmailOTPLoginScreen();
        }
      },
    );
  }
}

// Wrapper for seller flow with anonymous session
class SellerAuthWrapper extends StatefulWidget {
  const SellerAuthWrapper({Key? key}) : super(key: key);

  @override
  State<SellerAuthWrapper> createState() => _SellerAuthWrapperState();
}

class _SellerAuthWrapperState extends State<SellerAuthWrapper> {
  bool _isCreatingSession = false;
  bool _isCheckingStatus = true;
  String? _sellerStatus;

  @override
  void initState() {
    super.initState();
    // Schedule the session creation after the build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSellerStatusAndInitialize();
    });
  }

  Future<void> _checkSellerStatusAndInitialize() async {
    // Check if seller has already submitted registration or is logged in
    final prefs = await SharedPreferences.getInstance();
    final savedStatus = prefs.getString('seller_status');
    final savedUserId = prefs.getString('seller_user_id');
    final isLoggedIn = prefs.getString('seller_logged_in');

    // If seller is logged in, set status to logged_in
    if (isLoggedIn == 'true') {
      setState(() {
        _sellerStatus = 'logged_in';
        _isCheckingStatus = false;
      });
      return;
    }

    if (savedStatus == 'pending' && savedUserId != null) {
      setState(() {
        _sellerStatus = 'pending';
        _isCheckingStatus = false;
      });
      return;
    }

    // No saved status, proceed with session creation
    setState(() => _isCheckingStatus = false);
    await _createAnonymousSession();
  }

  Future<void> _createAnonymousSession() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Check if already authenticated
    if (authProvider.status == AuthStatus.authenticated) {
      return;
    }

    setState(() => _isCreatingSession = true);

    try {
      await authProvider.createAnonymousSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingSession = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If checking status, show loading
    if (_isCheckingStatus) {
      return Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Checking registration status...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    // If seller is logged in, show dashboard directly
    if (_sellerStatus == 'logged_in') {
      return const SellerDashboard();
    }

    // If seller has pending registration, show waiting screen
    if (_sellerStatus == 'pending') {
      return const SellerWaitingConfirmationScreen();
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (_isCreatingSession || authProvider.status == AuthStatus.loading) {
          return Scaffold(
            backgroundColor: AppColors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Preparing registration...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }

        if (authProvider.status == AuthStatus.authenticated) {
          return const SellerRegistrationScreen();
        }

        // Fallback case - retry
        return Scaffold(
          backgroundColor: AppColors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Failed to start session',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _createAnonymousSession,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
