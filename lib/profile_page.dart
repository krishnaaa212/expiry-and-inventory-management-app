import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'LoginPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  // Gets currently logged in user

  // Controllers for change password fields
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isChangingPassword = false; // Loading state for password change
  bool _isDeletingAccount = false;  // Loading state for account deletion

  // Changes the user's password using Firebase Auth
  Future<void> _changePassword() async {
    String currentPass = _currentPasswordController.text.trim();
    String newPass = _newPasswordController.text.trim();
    String confirmPass = _confirmPasswordController.text.trim();

    // Validate fields
    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showSnackBar("Please fill all password fields");
      return;
    }

    if (newPass != confirmPass) {
      _showSnackBar("New passwords do not match");
      return;
    }

    if (newPass.length < 6) {
      _showSnackBar("New password must be at least 6 characters");
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      // Re-authenticate user before changing password (Firebase requirement)
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPass,
      );
      await user!.reauthenticateWithCredential(credential);
      // Verifies current password is correct

      await user!.updatePassword(newPass);
      // Updates password in Firebase Auth

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSnackBar("Password changed successfully!");
      Navigator.pop(context); // Close the bottom sheet

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showSnackBar("Current password is incorrect");
      } else {
        _showSnackBar("Failed to change password. Try again.");
      }
    }

    setState(() => _isChangingPassword = false);
  }

  // Deletes the user's account and all their items from Firestore
  Future<void> _deleteAccount(String password) async {
    setState(() => _isDeletingAccount = true);

    try {
      // Re-authenticate before deleting (Firebase requirement)
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );
      await user!.reauthenticateWithCredential(credential);

      // Delete all items belonging to this user from Firestore
      final QuerySnapshot items = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: user!.uid)
          .get();

      for (var doc in items.docs) {
        await doc.reference.delete(); // Delete each item
      }

      await user!.delete();
      // Deletes the Firebase Auth account

      // Go to login page after deletion
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
        (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showSnackBar("Incorrect password");
      } else {
        _showSnackBar("Failed to delete account. Try again.");
      }
      setState(() => _isDeletingAccount = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Shows bottom sheet for changing password
  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to resize when keyboard opens
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          // Moves sheet up when keyboard appears
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Change Password",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Confirm New Password",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isChangingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 90, 76, 132),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
              child: _isChangingPassword
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }

  // Shows dialog to confirm account deletion
  void _showDeleteAccountDialog() {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This will permanently delete your account and all your items. This cannot be undone.",
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
            SizedBox(height: 15),
            Text("Enter your password to confirm:"),
            SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Your password",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount(passwordController.text.trim());
            },
            child: Text(
              "Delete Account",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Profile avatar and email
            Center(
              child: Column(
                children: [
                  SizedBox(height: 10),
                  CircleAvatar(
                    radius: 45,
                    backgroundColor:
                        const Color.fromARGB(255, 90, 76, 132),
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  SizedBox(height: 15),
                  Text(
                    user?.email ?? "No email",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 5),
                  // Shows verified badge if email is verified
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        user?.emailVerified == true
                            ? Icons.verified
                            : Icons.cancel_outlined,
                        size: 16,
                        color: user?.emailVerified == true
                            ? Colors.green
                            : Colors.red,
                      ),
                      SizedBox(width: 5),
                      Text(
                        user?.emailVerified == true
                            ? "Email Verified"
                            : "Email Not Verified",
                        style: TextStyle(
                          fontSize: 13,
                          color: user?.emailVerified == true
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),
            Divider(),
            SizedBox(height: 10),

            // Account Info Section
            Text(
              "Account Info",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),

            // Email tile
            _infoTile(
              icon: Icons.email_outlined,
              label: "Email",
              value: user?.email ?? "N/A",
            ),

            // Account created date
            _infoTile(
              icon: Icons.calendar_today_outlined,
              label: "Account Created",
              value: user?.metadata.creationTime != null
                  ? "${user!.metadata.creationTime!.day}/${user!.metadata.creationTime!.month}/${user!.metadata.creationTime!.year}"
                  : "N/A",
            ),

            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),

            // Settings Section
            Text(
              "Settings",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),

            // Change Password button
            _actionTile(
              icon: Icons.lock_outline,
              label: "Change Password",
              onTap: _showChangePasswordSheet,
            ),

            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),

            // Danger Zone Section
            Text(
              "Danger Zone",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red[400],
              ),
            ),
            SizedBox(height: 10),

            // Delete Account button
            _actionTile(
              icon: Icons.delete_forever_outlined,
              label: _isDeletingAccount
                  ? "Deleting account..."
                  : "Delete Account",
              color: Colors.red,
              onTap: _isDeletingAccount ? null : _showDeleteAccountDialog,
            ),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Reusable info display tile
  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color.fromARGB(255, 90, 76, 132), size: 22),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // Reusable tappable action tile
  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color color = const Color.fromARGB(255, 90, 76, 132),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color == Colors.red ? Colors.red[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color == Colors.red
                  ? Colors.red[200]!
                  : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}