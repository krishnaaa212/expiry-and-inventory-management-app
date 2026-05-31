import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth for login
import 'forgot_password.dart'; // Forgot Password page
import 'create_account.dart'; // Create Account page
import 'dashboard.dart'; // Dashboard page

class LoginPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController(); // Controls email input
  final TextEditingController passwordController = TextEditingController(); // Controls password input

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // App Title
                Text(
                  "Expiry and Inventory Management App",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                  ),
                ),

                SizedBox(height: 40),

                // Email Field
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress, // Shows email keyboard
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                SizedBox(height: 15),

                // Password Field
                TextField(
                  controller: passwordController,
                  obscureText: true, // Hides password characters
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                SizedBox(height: 5),

                // Forgot Password aligned to right
                Container(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
                        );
                      },
                      child: Text("Forgot Password?"),
                    ),
                  ),
                ),

                SizedBox(height: 10),

                // Login Button
                ElevatedButton(
                  onPressed: () async {
                    String email = emailController.text.trim(); // Gets entered email
                    String pass = passwordController.text.trim(); // Gets entered password

                    if (email.isEmpty || pass.isEmpty) {
                      // Check if fields are empty
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please fill all fields")),
                      );
                      return;
                    }

                    try {
                      // Sign in using Firebase Auth
                      UserCredential userCredential = await FirebaseAuth.instance
                          .signInWithEmailAndPassword(email: email, password: pass);

                      User? user = userCredential.user;

                      if (user != null && !user.emailVerified) {
                        // If email is not verified, block login
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Email not verified. Please check your inbox."),
                          ),
                        );
                        await FirebaseAuth.instance.signOut(); // Sign out unverified user
                        return;
                      }

                      if (user != null && user.emailVerified) {
                        // Email is verified – go to dashboard
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DashboardPage(username: email),
                          ),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      // Handle Firebase login errors
                      String message = "Login failed. Please try again.";

                      if (e.code == 'user-not-found') {
                        message = "No account found with this email.";
                      } else if (e.code == 'wrong-password') {
                        message = "Incorrect password.";
                      } else if (e.code == 'invalid-email') {
                        message = "Invalid email address.";
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  },
                  child: Text("Login"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50), // Full width button
                    backgroundColor: const Color.fromARGB(255, 90, 76, 132), // Button color
                    foregroundColor: Colors.white, // Text color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                SizedBox(height: 15),

                // Create Account
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateAccountPage()),
                    );
                  },
                  child: Text("Create New Account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}