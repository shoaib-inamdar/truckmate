import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/pages/homepage.dart';
import 'package:truckmate/pages/email_otp_login_screen.dart';
import 'package:truckmate/pages/login.dart';
import 'package:truckmate/pages/password_reset_screen.dart';
import 'package:truckmate/pages/seller_choice_screen.dart';
import 'package:truckmate/pages/seller_dashboard.dart';
import 'package:truckmate/pages/transporter_registration_tabs.dart';
import 'package:truckmate/pages/seller_waiting_confirmation.dart';
import 'package:truckmate/pages/profile_screen.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/chat_provider.dart';
import 'package:truckmate/providers/email_otp_provider.dart';
import 'package:truckmate/providers/booking_provider.dart';
import 'package:truckmate/providers/seller_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

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
        ChangeNotifierProvider(create: (_) => SellerProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
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

// Global navigator key for deep link navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cargo Balancer',
      navigatorKey: navigatorKey,
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
  StreamSubscription? _linkSubscription;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _loadStartupChoice();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // Handle initial deep link when app is opened from a link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink.toString());
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }

    // Handle deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri.toString());
      },
      onError: (err) {
        print('Error listening to link stream: $err');
      },
    );
  }

  void _handleDeepLink(String link) {
    print('Received deep link: $link');
    final uri = Uri.parse(link);

    // Handle password reset: truckmate://reset-password?userId=xxx&secret=xxx
    if (uri.host == 'reset-password') {
      final userId = uri.queryParameters['userId'];
      final secret = uri.queryParameters['secret'];

      if (userId != null && secret != null) {
        print('Navigating to password reset with userId: $userId');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PasswordResetScreen(userId: userId, secret: secret),
          ),
          (route) => false,
        );
      } else {
        print('Missing userId or secret in deep link');
      }
    }
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
            return HomeScreen();
          case AuthStatus.unauthenticated:
            return EmailOTPLoginScreen();
        }
      },
    );
  }
}

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSellerStatusAndInitialize();
    });
  }

  Future<void> _checkSellerStatusAndInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStatus = prefs.getString('seller_status');
    final savedUserId = prefs.getString('seller_user_id');
    final isLoggedIn = prefs.getString('seller_logged_in');
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
    setState(() => _isCheckingStatus = false);
    await _createAnonymousSession();
  }

  Future<void> _createAnonymousSession() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
    if (_sellerStatus == 'logged_in') {
      return const SellerDashboard();
    }
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
          return const TransporterRegistrationTabs();
        }
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
