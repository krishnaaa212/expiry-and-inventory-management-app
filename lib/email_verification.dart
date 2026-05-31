import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth to check verification
import 'LoginPage.dart'; 

class EmailVerificationPage extends StatefulWidget {
  final String email; // Email address that was registered
  final String username; // Username for display

  const EmailVerificationPage({
    Key? key,
    required this.email,
    required this.username,
  }) : super(key: key);

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  Timer? _timer; // Timer to automatically check verification status
  bool _isResending = false; // Tracks if resend button is loading

  @override
  void initState() {
    super.initState();
    _startVerificationCheck(); // Start checking as soon as page opens
  }

  @override
  void dispose() {
    _timer?.cancel(); // Stop timer when page is closed
    super.dispose();
  }

  // Checks every 4 seconds if the user has verified their email
  void _startVerificationCheck() {
    _timer = Timer.periodic(Duration(seconds: 4), (timer) async {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.reload(); // Reloads user data from Firebase

        if (user.emailVerified) {
          // Email is verified – stop timer and go to login
          timer.cancel();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Email verified! Please log in.")),
          );

          // Sign out so user logs in fresh with verified account
          await FirebaseAuth.instance.signOut();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
            (route) => false, // Removes all previous pages from stack
          );
        }
      }
    });
  }

  // Resends the verification email if user didn't receive it
  void _resendVerificationEmail() async {
    setState(() => _isResending = true); // Shows loading

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification(); // Sends email again

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification email resent to ${widget.email}")),
        );
      }
    } on FirebaseAuthException {
      // If resend fails (e.g. too many requests)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not resend email. Please wait a moment.")),
      );
    }

    setState(() => _isResending = false); // Hides loading
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Verify Your Email"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        titleTextStyle: TextStyle(color: Colors.white),
        automaticallyImplyLeading: false, // Removes back button (user must verify first)
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Email icon
              Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: const Color.fromARGB(255, 90, 76, 132),
              ),

              SizedBox(height: 25),

              // Main heading
              Text(
                "Check Your Email",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              // Instruction text
              Text(
                "Hi ${widget.username}, we sent a verification link to:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),

              SizedBox(height: 5),

              // Shows the registered email
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 90, 76, 132),
                ),
              ),

              SizedBox(height: 10),

              Text(
                "Please open the link in the email to verify your account. This page will update automatically.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              SizedBox(height: 30),

              // Loading indicator while waiting
              CircularProgressIndicator(
                color: const Color.fromARGB(255, 90, 76, 132),
              ),

              SizedBox(height: 10),

              Text(
                "Waiting for verification...",
                style: TextStyle(color: Colors.grey),
              ),

              SizedBox(height: 30),

              // Resend Email Button
              ElevatedButton.icon(
                onPressed: _isResending ? null : _resendVerificationEmail,
                // Disabled while resending

                icon: _isResending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.refresh),

                label: Text(_isResending ? "Sending..." : "Resend Email"),

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 90, 76, 132),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50), // Full width
                ),
              ),

              SizedBox(height: 15),

              // Cancel and go back to login
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut(); // Sign out before going back
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                    (route) => false,
                  );
                },
                child: Text("Back to Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}