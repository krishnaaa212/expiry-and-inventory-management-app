import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth for creating accounts
import 'email_verification.dart'; // Email Verification page
 
class CreateAccountPage extends StatelessWidget {
  // NOTE: The local accounts map is kept for security question / forgot password support
  static Map<String, Map<String, String>> accounts = {};
  // Stores username → { password, security, email } for forgot password use
 
  final TextEditingController emailController = TextEditingController(); // Email input
  final TextEditingController usernameController = TextEditingController(); // Username input
  final TextEditingController passwordController = TextEditingController(); // Password input
  final TextEditingController securityAnswer = TextEditingController(); // Security answer input
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Account"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        titleTextStyle: TextStyle(color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
 
              Text(
                "Enter details to create your account.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
 
              SizedBox(height: 20),
 
              // Email Field
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress, // Shows email keyboard
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
 
              SizedBox(height: 15),
 
              // Username Field
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                ),
              ),
 
              SizedBox(height: 15),
 
              // Password Field
              TextField(
                controller: passwordController,
                obscureText: true, // Hides password
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
 
              SizedBox(height: 20),
 
              // Security Question Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Security Question",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
 
              SizedBox(height: 5),
 
              Align(
                alignment: Alignment.centerLeft,
                child: Text("In which city were you born?"),
              ),
 
              SizedBox(height: 5),
 
              TextField(
                controller: securityAnswer,
                decoration: InputDecoration(border: OutlineInputBorder()),
              ),
 
              SizedBox(height: 25),
 
              // Create Account Button
              ElevatedButton(
                onPressed: () async {
                  String email = emailController.text.trim();
                  String username = usernameController.text.trim();
                  String password = passwordController.text.trim();
                  String answer = securityAnswer.text.trim();
 
                  // Check all fields are filled
                  if (email.isEmpty || username.isEmpty || password.isEmpty || answer.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Please fill all fields")),
                    );
                    return;
                  }
 
                  try {
                    // Create user with Firebase Auth
                    UserCredential userCredential = await FirebaseAuth.instance
                        .createUserWithEmailAndPassword(email: email, password: password);
 
                    User? user = userCredential.user;
 
                    if (user != null) {
                      // Send verification email
                      await user.sendEmailVerification();
 
                      // Save to local accounts map for security question support
                      CreateAccountPage.accounts[username] = {
                        "password": password,
                        "security": answer,
                        "email": email,
                      };
 
                      // Go to email verification waiting page
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmailVerificationPage(
                            email: email,
                            username: username,
                          ),
                        ),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    // Handle Firebase account creation errors
                    String message = "Account creation failed.";
 
                    if (e.code == 'weak-password') {
                      message = "Password is too weak. Use at least 6 characters.";
                    } else if (e.code == 'email-already-in-use') {
                      message = "An account already exists with this email.";
                    } else if (e.code == 'invalid-email') {
                      message = "Invalid email address.";
                    }
 
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                },
                child: Text("Create Account"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 90, 76, 132),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50), // Full width button
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 