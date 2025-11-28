import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:truckmate/pages/book_transport.dart';
import 'package:truckmate/pages/email_otp_login_screen.dart';
import 'package:truckmate/pages/login_screen.dart';
import 'package:truckmate/pages/homepage.dart';
// import 'package:truckmate/pages/phone_login_screen.dart';
import 'package:truckmate/providers/auth_provider.dart';
import 'package:truckmate/providers/email_otp_provider.dart';
// import 'screens/login_screen.dart';

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
      ],
      child: MyApp(),
    ),
  );
}

class AppColors {
  static const Color primary = Color(0xFFC6FF00); // Lime green
  static const Color primaryDark = Color(0xFF9ACC00);
  static const Color secondary = Color(0xFF7A8E99); // Gray-blue
  static const Color dark = Color(0xFF0A0E27); // Dark navy
  static const Color darkLight = Color(0xFF1A1F3A);
  static const Color light = Color(0xFFFAFBFB); // Light gray
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
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
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
            return BookTransportScreen();
          case AuthStatus.unauthenticated:
            return EmailOTPLoginScreen();
        }
      },
    );
  }
}
