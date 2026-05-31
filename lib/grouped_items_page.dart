import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupedItemsPage extends StatefulWidget {
  const GroupedItemsPage({super.key});

  @override
  State<GroupedItemsPage> createState() => _GroupedItemsPageState();
}

class _GroupedItemsPageState extends State<GroupedItemsPage> {
  // Tracks which folders are open — key is group name, value is open/closed
  final Map<String, bool> _openFolders = {};

  // Returns color based on how close the expiry date is
  Color _expiryColor(DateTime expiry) {
    int daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Colors.red[900]!;
    if (daysLeft <= 3) return Colors.red;
    if (daysLeft <= 7) return Colors.orange;
    return Colors.green;
  }

  // Returns expiry label
  String _expiryLabel(DateTime expiry) {
    int daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return "Expired";
    if (daysLeft == 0) return "Today!";
    if (daysLeft == 1) return "Tomorrow!";
    if (daysLeft <= 7) return "In $daysLeft days";
    return "${expiry.day}/${expiry.month}/${expiry.year}";
  }

  // Shows confirmation dialog then deletes item
  void _confirmDelete(BuildContext context, String docId, String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Item"),
        content: Text("Are you sure you want to delete \"$name\"?"),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .orderBy('expiryDate')
          .snapshots(),

      builder: (context, snapshot) {

        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color.fromARGB(255, 90, 76, 132),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading items.\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 70, color: Colors.grey[300]),
                SizedBox(height: 15),
                Text(
                  "No items added yet.",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Add items with a group to see folders here.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Group all items by their 'group' field
        final docs = snapshot.data!.docs;
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};

        for (var doc in docs) {
          final String group = doc['group'] ?? 'General';
          grouped.putIfAbsent(group, () => []);
          grouped[group]!.add(doc);
        }

        // Sort group names alphabetically
        final groupNames = grouped.keys.toList()..sort();

        // Initialize folder state for any new groups (default closed)
        for (var name in groupNames) {
          _openFolders.putIfAbsent(name, () => false);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: groupNames.length,
          itemBuilder: (context, index) {
            final String groupName = groupNames[index];
            final List<QueryDocumentSnapshot> groupItems = grouped[groupName]!;
            final bool isOpen = _openFolders[groupName] ?? false;

            // Count expired items in this group for the warning badge
            final int expiredCount = groupItems.where((item) {
              final Timestamp? ts = item['expiryDate'] as Timestamp?;
              if (ts == null) return false;
              return ts.toDate().isBefore(DateTime.now());
            }).length;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOpen
                      ? const Color.fromARGB(255, 90, 76, 132).withOpacity(0.5)
                      : Colors.grey[300]!,
                  width: isOpen ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [

                  // ✅ Folder header — tap to open/close
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _openFolders[groupName] = !isOpen;
                        // Toggles folder open/closed
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [

                          // Folder icon — changes when open/closed
                          Icon(
                            isOpen ? Icons.folder_open : Icons.folder,
                            color: const Color.fromARGB(255, 90, 76, 132),
                            size: 28,
                          ),

                          SizedBox(width: 12),

                          // Group name
                          Expanded(
                            child: Text(
                              groupName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          // Expired warning badge — only shows if any items expired
                          if (expiredCount > 0)
                            Container(
                              margin: EdgeInsets.only(right: 8),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red[300]!),
                              ),
                              child: Text(
                                "$expiredCount expired",
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // Item count badge
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 90, 76, 132)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${groupItems.length} item${groupItems.length > 1 ? 's' : ''}",
                              style: TextStyle(
                                color:
                                    const Color.fromARGB(255, 90, 76, 132),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          SizedBox(width: 8),

                          // Arrow icon — rotates when open
                          AnimatedRotation(
                            turns: isOpen ? 0.5 : 0,
                            // Rotates 180 degrees when open
                            duration: Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ Items inside folder — only visible when open
                  AnimatedCrossFade(
                    firstChild: SizedBox.shrink(),
                    // Hidden state (closed folder)

                    secondChild: Column(
                      children: [
                        Divider(height: 1, color: Colors.grey[200]),
                        // Divider between header and items

                        ...groupItems.map((item) {
                          final String name = item['name'] ?? 'Unnamed';
                          final String reminder = item['reminderDays'] ?? '0';
                          final String notifTime =
                              item['notificationTime'] ?? 'Not set';
                          final Timestamp? ts =
                              item['expiryDate'] as Timestamp?;
                          if (ts == null) return SizedBox();
                          final DateTime expiry = ts.toDate();
                          final Color statusColor = _expiryColor(expiry);

                          return Container(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    // Left color strip
                                    Container(
                                      width: 4,
                                      height: 55,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),

                                    SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Item name and expiry badge
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: statusColor
                                                          .withOpacity(0.5)),
                                                ),
                                                child: Text(
                                                  _expiryLabel(expiry),
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "Reminder: $reminder days  |  $notifTime",
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500]),
                                          ),
                                          // Delete button
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: () => _confirmDelete(
                                                  context, item.id, name),
                                              icon: Icon(Icons.delete_outline,
                                                  size: 15,
                                                  color: Colors.red[400]),
                                              label: Text(
                                                "Delete",
                                                style: TextStyle(
                                                    color: Colors.red[400],
                                                    fontSize: 12),
                                              ),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                minimumSize: Size(0, 0),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Divider between items inside folder
                                if (item != groupItems.last)
                                  Divider(
                                      height: 16, color: Colors.grey[100]),
                              ],
                            ),
                          );
                        }).toList(),

                        SizedBox(height: 8),
                      ],
                    ),

                    crossFadeState: isOpen
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    // Animates open/close smoothly

                    duration: Duration(milliseconds: 250),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}