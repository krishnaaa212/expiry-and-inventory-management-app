import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth for password reset

class ForgotPasswordPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  // Controller to get entered email address

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reset Password"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        titleTextStyle: TextStyle(color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white), // Makes back arrow white
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "Enter your registered email address. We will send you a link to reset your password.",
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 20),

              // Email label
              Text(
                "Email Address",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 5),

              // Email input field
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress, // Shows email keyboard
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Enter your email",
                ),
              ),

              SizedBox(height: 30),

              // Send Reset Email Button
              SizedBox(
                width: double.infinity, // Full width
                child: ElevatedButton(
                  onPressed: () async {
                    String email = emailController.text.trim();
                    // Gets entered email

                    if (email.isEmpty) {
                      // Check if email field is empty
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please enter your email address")),
                      );
                      return;
                    }

                    try {
                      // Firebase sends a password reset link to the email
                      await FirebaseAuth.instance
                          .sendPasswordResetEmail(email: email);

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Password reset email sent to $email. Please check your inbox.",
                          ),
                        ),
                      );

                      Navigator.pop(context);
                      // Goes back to Login page after sending email

                    } on FirebaseAuthException catch (e) {
                      // Handle Firebase errors
                      String message = "Something went wrong. Please try again.";

                      if (e.code == 'user-not-found') {
                        message = "No account found with this email address.";
                      } else if (e.code == 'invalid-email') {
                        message = "Invalid email address.";
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 90, 76, 132),
                    // Button background color

                    foregroundColor: Colors.white,
                    // Button text color

                    minimumSize: Size(double.infinity, 50),
                    // Full width, height 50
                  ),
                  child: Text("Send Reset Email"), // Button text
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}