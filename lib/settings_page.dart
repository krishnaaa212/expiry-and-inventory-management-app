import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'LoginPage.dart';
 
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
 
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
 
class _SettingsPageState extends State<SettingsPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
 
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
 
  // ── Change Email ──────────────────────────────────────────────────
  void _showChangeEmailSheet() {
    final TextEditingController newEmailController =
        TextEditingController();
    final TextEditingController passwordController =
        TextEditingController();
 
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Change Email",
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text("Current: ${user?.email ?? ''}",
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            SizedBox(height: 18),
            TextField(
              controller: newEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                  labelText: "New Email Address",
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: "Current Password (to confirm)",
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newEmail = newEmailController.text.trim();
                final password = passwordController.text.trim();
 
                if (newEmail.isEmpty || password.isEmpty) {
                  _showSnackBar("Please fill all fields");
                  return;
                }
 
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
 
                try {
                  // Re-authenticate first
                  final cred = EmailAuthProvider.credential(
                      email: user!.email!, password: password);
                  await user!.reauthenticateWithCredential(cred);
 
                  // Send verification to new email
                  await user!.verifyBeforeUpdateEmail(newEmail);
 
                  _showSnackBar(
                      "Verification sent to $newEmail. Please verify to complete the change.");
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'wrong-password') {
                    _showSnackBar("Incorrect password.");
                  } else if (e.code == 'email-already-in-use') {
                    _showSnackBar("This email is already in use.");
                  } else {
                    _showSnackBar("Failed to update email. Try again.");
                  }
                }
 
                setState(() => _isLoading = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 90, 76, 132),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Send Verification to New Email"),
            ),
          ],
        ),
      ),
    );
  }
 
  // ── Change Password ───────────────────────────────────────────────
  void _showChangePasswordSheet() {
    final TextEditingController currentPassController =
        TextEditingController();
    final TextEditingController newPassController =
        TextEditingController();
    final TextEditingController confirmPassController =
        TextEditingController();
 
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Change Password",
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 18),
            TextField(
              controller: currentPassController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: "Current Password",
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final current = currentPassController.text.trim();
                final newPass = newPassController.text.trim();
                final confirm = confirmPassController.text.trim();
 
                if (current.isEmpty ||
                    newPass.isEmpty ||
                    confirm.isEmpty) {
                  _showSnackBar("Please fill all fields");
                  return;
                }
                if (newPass != confirm) {
                  _showSnackBar("New passwords do not match");
                  return;
                }
                if (newPass.length < 6) {
                  _showSnackBar(
                      "Password must be at least 6 characters");
                  return;
                }
 
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
 
                try {
                  final cred = EmailAuthProvider.credential(
                      email: user!.email!, password: current);
                  await user!.reauthenticateWithCredential(cred);
                  await user!.updatePassword(newPass);
                  _showSnackBar("Password changed successfully!");
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'wrong-password') {
                    _showSnackBar("Current password is incorrect.");
                  } else {
                    _showSnackBar(
                        "Failed to change password. Try again.");
                  }
                }
 
                setState(() => _isLoading = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 90, 76, 132),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }
 
  // ── Send Password Reset Email ─────────────────────────────────────
  void _sendPasswordResetEmail() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: user!.email!);
      _showSnackBar("Password reset email sent to ${user!.email}");
    } catch (e) {
      _showSnackBar("Failed to send reset email.");
    }
    setState(() => _isLoading = false);
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: const Color.fromARGB(255, 90, 76, 132)))
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
 
                // ── Account Section ──
                _sectionLabel("Account"),
 
                _settingsTile(
                  icon: Icons.email_outlined,
                  label: "Change Email",
                  subtitle: user?.email ?? '',
                  onTap: _showChangeEmailSheet,
                ),
 
                _settingsTile(
                  icon: Icons.lock_outline,
                  label: "Change Password",
                  subtitle: "Update your current password",
                  onTap: _showChangePasswordSheet,
                ),
 
                _settingsTile(
                  icon: Icons.lock_reset,
                  label: "Send Password Reset Email",
                  subtitle: "Receive a reset link at your email",
                  onTap: _sendPasswordResetEmail,
                ),
 
                SizedBox(height: 20),
 
                // ── App Section ──
                _sectionLabel("App"),
 
                _settingsTile(
                  icon: Icons.info_outline,
                  label: "App Version",
                  subtitle: "1.0.0",
                  onTap: null, // Not tappable
                ),
 
                SizedBox(height: 20),
 
                // ── Logout ──
                _sectionLabel("Session"),
 
                _settingsTile(
                  icon: Icons.logout,
                  label: "Logout",
                  subtitle: "Sign out of your account",
                  color: Colors.red,
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => LoginPage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
    );
  }
 
  // Section label
  Widget _sectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
 
  // Reusable settings tile
  Widget _settingsTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    Color color = const Color.fromARGB(255, 90, 76, 132),
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label,
            style:
                TextStyle(fontWeight: FontWeight.w500, color: color)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: onTap != null
            ? Icon(Icons.chevron_right, color: Colors.grey[400])
            : null,
        onTap: onTap,
      ),
    );
  }
}