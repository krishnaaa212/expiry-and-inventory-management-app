import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpiredItemsPage extends StatelessWidget {
  const ExpiredItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    // Gets current user's ID to only show their items

    final DateTime now = DateTime.now();
    // Current date to compare against expiry dates

    return StreamBuilder<QuerySnapshot>(
      // Listens to Firestore in real time
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId) // Only this user's items
          .orderBy('expiryDate') // Oldest expiry first
          .snapshots(),

      builder: (context, snapshot) {

        // Show loading spinner while fetching
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color.fromARGB(255, 90, 76, 132),
            ),
          );
        }

        // Show error if Firestore fetch fails
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading items.\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        // Filter only expired items from all items
        final allDocs = snapshot.data?.docs ?? [];
        final expiredItems = allDocs.where((item) {
          final Timestamp? ts = item['expiryDate'] as Timestamp?;
          if (ts == null) return false;
          return ts.toDate().isBefore(now); // ✅ Only items where expiry < today
        }).toList();

        // Show empty state if no expired items
        if (expiredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 70, color: Colors.green[200]),
                SizedBox(height: 15),
                Text(
                  "No expired items!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "All your items are within their expiry date.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Show expired items list
        return Column(
          children: [

            // Header banner showing count of expired items
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.red[50],
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "${expiredItems.length} expired item${expiredItems.length > 1 ? 's' : ''} found",
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Expired items list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: expiredItems.length,
                itemBuilder: (context, index) {
                  final item = expiredItems[index];
                  final String name = item['name'] ?? 'Unnamed Item';
                  final String group = item['group'] ?? 'General';
                  final DateTime expiry =
                      (item['expiryDate'] as Timestamp).toDate();
                  final int daysExpired =
                      now.difference(expiry).inDays; // How many days ago it expired

                  return Card(
                    margin: EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.red.withOpacity(0.4), width: 1.2),
                    ),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 15, vertical: 8),

                      // Red indicator strip on left
                      leading: Container(
                        width: 5,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),

                      // Item name and group
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 3),
                          Text(
                            "Group: $group",
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                          Text(
                            "Expired on: ${expiry.day}/${expiry.month}/${expiry.year}",
                            style: TextStyle(
                                fontSize: 12, color: Colors.red[400]),
                          ),
                        ],
                      ),

                      // How many days ago it expired
                      trailing: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.5)),
                        ),
                        child: Text(
                          daysExpired == 0
                              ? "Today"
                              : "$daysExpired day${daysExpired > 1 ? 's' : ''} ago",
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      // Delete on long press
                      onLongPress: () =>
                          _confirmDelete(context, item.id, name),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Shows a confirmation dialog before deleting
  void _confirmDelete(
      BuildContext context, String docId, String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Item"),
        content: Text("Delete \"$name\" from expired items?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('items')
          .doc(docId)
          .delete();
      // Deletes from Firestore — list updates automatically
    }
  }
}