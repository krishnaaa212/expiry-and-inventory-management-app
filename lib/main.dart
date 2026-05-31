import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To check login state
import 'package:device_preview/device_preview.dart';
import 'firebase_options.dart';
import 'LoginPage.dart';
import 'dashboard.dart'; // To go directly to dashboard if logged in
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(LoadingApp()); // Show loading screen while initializing

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized");

    await NotificationService().initialize();
    print("✅ Notifications initialized");

    runApp(
      DevicePreview(
        enabled: false, // ✅ Set to true only when testing on desktop/emulator
        builder: (context) => MyApp(),
      ),
    );
  } catch (e) {
    print("❌ Init error: $e");
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(), // ✅ Checks login state instead of going to LoginPage directly
    );
  }
}

// ✅ Decides which page to show based on login state
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // StreamBuilder listens to Firebase auth state changes in real time
      // Fires whenever user logs in, logs out, or app restarts
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {

        // Still checking auth state — show loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 90, 76, 132),
              ),
            ),
          );
        }

        // User is logged in AND email is verified → go to Dashboard
        if (snapshot.hasData && snapshot.data != null) {
          final User user = snapshot.data!;

          if (user.emailVerified) {
            // ✅ Already logged in — skip login page entirely
            return DashboardPage(username: user.email ?? '');
          } else {
            // Logged in but email not verified — go to login
            // (edge case — user somehow bypassed verification)
            FirebaseAuth.instance.signOut();
            return LoginPage();
          }
        }

        // No user logged in → show Login page
        return LoginPage();
      },
    );
  }
}

// Loading screen shown while Firebase initializes
class LoadingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color.fromARGB(255, 90, 76, 132),
              ),
              SizedBox(height: 20),
              Text(
                "Starting app...",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Error screen shown if Firebase fails to initialize
class ErrorApp extends StatelessWidget {
  final String error;
  ErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 60),
                SizedBox(height: 20),
                Text(
                  "Initialization failed",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 15),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(fontSize: 13, color: Colors.red[900]),
                    textAlign: TextAlign.center,
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