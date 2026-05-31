import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final DateTime now = DateTime.now();

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
              "Error loading notifications.\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Split items into categories for notifications
        final List<QueryDocumentSnapshot> expiredItems = [];
        final List<QueryDocumentSnapshot> expiresToday = [];
        final List<QueryDocumentSnapshot> expiresSoon = []; // within 7 days

        for (var doc in docs) {
  final Timestamp? ts = doc['expiryDate'] as Timestamp?;
  if (ts == null) continue;
  final DateTime expiry = ts.toDate();
  
  // Use exact datetime comparison, not just date
  final Duration difference = expiry.difference(now);
  final int daysLeft = difference.inDays;

  if (expiry.isBefore(now)) {
    expiredItems.add(doc); // Expired — exact time check
  } else if (daysLeft == 0) {
    expiresToday.add(doc); // Expires later today
  } else if (daysLeft <= 7) {
    expiresSoon.add(doc); // Expires within 7 days
  }
}
        // All notifications combined
        final bool hasNotifications = expiredItems.isNotEmpty ||
            expiresToday.isNotEmpty ||
            expiresSoon.isNotEmpty;

        // Empty state — no urgent items
        if (!hasNotifications) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none,
                    size: 70, color: Colors.grey[300]),
                SizedBox(height: 15),
                Text(
                  "No notifications!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "All your items are well within their expiry dates.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.all(16),
          children: [

            // ─── EXPIRED SECTION ───
            if (expiredItems.isNotEmpty) ...[
              _sectionHeader(
                icon: Icons.cancel,
                label: "Expired",
                count: expiredItems.length,
                color: Colors.red[700]!,
                bgColor: Colors.red[50]!,
              ),
              SizedBox(height: 8),
              ...expiredItems.map((item) => _notificationCard(
                    context: context,
                    item: item,
                    now: now,
                    icon: Icons.cancel,
                    iconColor: Colors.red[700]!,
                    bgColor: Colors.red[50]!,
                    borderColor: Colors.red[200]!,
                    message: _expiredMessage(item, now),
                  )),
              SizedBox(height: 16),
            ],

            // ─── EXPIRES TODAY SECTION ───
            if (expiresToday.isNotEmpty) ...[
              _sectionHeader(
                icon: Icons.warning_amber_rounded,
                label: "Expires Today",
                count: expiresToday.length,
                color: Colors.deepOrange[700]!,
                bgColor: Colors.deepOrange[50]!,
              ),
              SizedBox(height: 8),
              ...expiresToday.map((item) => _notificationCard(
                    context: context,
                    item: item,
                    now: now,
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.deepOrange[700]!,
                    bgColor: Colors.deepOrange[50]!,
                    borderColor: Colors.deepOrange[200]!,
                    message: "This item expires TODAY. Use or discard it.",
                  )),
              SizedBox(height: 16),
            ],

            // ─── EXPIRING SOON SECTION ───
            if (expiresSoon.isNotEmpty) ...[
              _sectionHeader(
                icon: Icons.access_time,
                label: "Expiring Soon",
                count: expiresSoon.length,
                color: Colors.orange[700]!,
                bgColor: Colors.orange[50]!,
              ),
              SizedBox(height: 8),
              ...expiresSoon.map((item) => _notificationCard(
                    context: context,
                    item: item,
                    now: now,
                    icon: Icons.access_time,
                    iconColor: Colors.orange[700]!,
                    bgColor: Colors.orange[50]!,
                    borderColor: Colors.orange[200]!,
                    message: _expiringSoonMessage(item, now),
                  )),
            ],
          ],
        );
      },
    );
  }

  // Section header widget
  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$count item${count > 1 ? 's' : ''}",
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Individual notification card widget
  Widget _notificationCard({
    required BuildContext context,
    required QueryDocumentSnapshot item,
    required DateTime now,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String message,
  }) {
    final String name = item['name'] ?? 'Unnamed Item';
    final String group = item['group'] ?? 'General';
    final DateTime expiry = (item['expiryDate'] as Timestamp).toDate();

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Icon circle
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),

          SizedBox(width: 12),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                SizedBox(height: 4),
                Text(
                  "Group: $group  •  ${expiry.day}/${expiry.month}/${expiry.year}",
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Message for expired items
  String _expiredMessage(QueryDocumentSnapshot item, DateTime now) {
    final DateTime expiry = (item['expiryDate'] as Timestamp).toDate();
    final int daysAgo = now.difference(expiry).inDays;
    if (daysAgo == 1) return "This item expired yesterday.";
    return "This item expired $daysAgo days ago.";
  }

  // Message for items expiring soon
  String _expiringSoonMessage(QueryDocumentSnapshot item, DateTime now) {
    final DateTime expiry = (item['expiryDate'] as Timestamp).toDate();
    final int daysLeft = expiry.difference(now).inDays;
    if (daysLeft == 1) return "This item expires tomorrow!";
    return "This item expires in $daysLeft days.";
  }
}