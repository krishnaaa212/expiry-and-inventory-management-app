import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_item.dart';
import 'all_items_page.dart';
import 'grouped_items_page.dart';
import 'expired_items_page.dart';
import 'notifications_page.dart';  // ✅ Notifications
import 'qr_scanner_page.dart';     // ✅ QR Scanner
import 'profile_page.dart';
import 'LoginPage.dart';
import 'bill_scanner_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  DashboardPage({required this.username});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(_appBarTitle()),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),

        leading: PopupMenuButton<String>(
          icon: Icon(Icons.person, color: Colors.white),
          onSelected: (value) async {
            if (value == "profile") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage()),
              );
            }
             else if (value == "settings") {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SettingsPage()));
            } else if (value == "logout") {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: "profile",
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20, color: Colors.grey[700]),
                  SizedBox(width: 10),
                  Text("My Profile"),
                ],
              ),
            ),
            PopupMenuItem(
              value: "settings",
              child: Row(children: [
                Icon(Icons.settings_outlined,
                    size: 20, color: Colors.grey[700]),
                SizedBox(width: 10),
                Text("Settings"),
              ]),
            ),
            PopupMenuItem(
              value: "logout",
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.red[400]),
                  SizedBox(width: 10),
                  Text("Logout", style: TextStyle(color: Colors.red[400])),
                ],
              ),
            ),
          ],
        ),

        actions: [
          // Add button only on All Items tab
          if (_selectedIndex == 0)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddItemPage()),
                );
              },
            ),
            // In AppBar actions list, add this:
IconButton(
  icon: Icon(Icons.receipt_long),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BillScannerPage()),
    );
  },
  tooltip: "Scan Bill",
),

          // ✅ QR scanner button — opens camera scanner
          IconButton(
            icon: Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QRScannerPage()),
              );
            },
            tooltip: "Scan Product Barcode",
          ),
        ],
      ),

      body: _buildPage(),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color.fromARGB(255, 90, 76, 132),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.list), label: "All Items"),
          BottomNavigationBarItem(
              icon: Icon(Icons.folder), label: "Groups"),
          BottomNavigationBarItem(
              icon: Icon(Icons.warning), label: "Expired"),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: "Notifications"),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0: return AllItemsPage();
      case 1: return GroupedItemsPage();
      case 2: return ExpiredItemsPage();
      case 3: return NotificationsPage(); // ✅ Live notifications
      default: return AllItemsPage();
    }
  }

  String _appBarTitle() {
    switch (_selectedIndex) {
      case 0: return "All Items";
      case 1: return "Groups";
      case 2: return "Expired Items";
      case 3: return "Notifications";
      default: return "Dashboard";
    }
  }
}