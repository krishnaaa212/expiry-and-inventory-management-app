import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'edit_item_page.dart'; // Edit item page

enum SortOption {
  expiryAsc,
  expiryDesc,
  nameAsc,
  nameDesc,
  groupAsc,
}

class AllItemsPage extends StatefulWidget {
  const AllItemsPage({super.key});

  @override
  State<AllItemsPage> createState() => _AllItemsPageState();
}

class _AllItemsPageState extends State<AllItemsPage> {
  SortOption _currentSort = SortOption.expiryAsc;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // Current search text

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _expiryColor(DateTime expiry) {
    int daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Colors.red[900]!;
    if (daysLeft <= 3) return Colors.red;
    if (daysLeft <= 7) return Colors.orange;
    return Colors.green;
  }

  String _expiryLabel(DateTime expiry) {
    int daysLeft = expiry.difference(DateTime.now()).inDays;
    if (expiry.isBefore(DateTime.now())) return "Expired";
    if (daysLeft == 0) return "Expires today!";
    if (daysLeft == 1) return "Expires tomorrow!";
    if (daysLeft <= 7) return "Expires in $daysLeft days";
    return "${expiry.day}/${expiry.month}/${expiry.year}";
  }

  // Filters items by search query (name, group, barcode)
  List<QueryDocumentSnapshot> _filterItems(
      List<QueryDocumentSnapshot> items) {
    if (_searchQuery.isEmpty) return items;
    final query = _searchQuery.toLowerCase();
    return items.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final group = (item['group'] ?? '').toString().toLowerCase();
      final Map<String, dynamic> data = item.data() as Map<String, dynamic>;
      final barcode = (data.containsKey('barcode')
              ? data['barcode'] ?? ''
              : '')
          .toString()
          .toLowerCase();
      return name.contains(query) ||
          group.contains(query) ||
          barcode.contains(query);
    }).toList();
  }

  List<QueryDocumentSnapshot> _sortItems(
      List<QueryDocumentSnapshot> items) {
    final sorted = List<QueryDocumentSnapshot>.from(items);
    switch (_currentSort) {
      case SortOption.expiryAsc:
        sorted.sort((a, b) => (a['expiryDate'] as Timestamp)
            .toDate()
            .compareTo((b['expiryDate'] as Timestamp).toDate()));
        break;
      case SortOption.expiryDesc:
        sorted.sort((a, b) => (b['expiryDate'] as Timestamp)
            .toDate()
            .compareTo((a['expiryDate'] as Timestamp).toDate()));
        break;
      case SortOption.nameAsc:
        sorted.sort((a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()));
        break;
      case SortOption.nameDesc:
        sorted.sort((a, b) => (b['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((a['name'] ?? '').toString().toLowerCase()));
        break;
      case SortOption.groupAsc:
        sorted.sort((a, b) => (a['group'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['group'] ?? '').toString().toLowerCase()));
        break;
    }
    return sorted;
  }

  String _sortLabel() {
    switch (_currentSort) {
      case SortOption.expiryAsc: return "Expiry: Soonest First";
      case SortOption.expiryDesc: return "Expiry: Latest First";
      case SortOption.nameAsc: return "Name: A to Z";
      case SortOption.nameDesc: return "Name: Z to A";
      case SortOption.groupAsc: return "Group: A to Z";
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text("Sort By",
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            _sortTile(ctx, "Expiry: Soonest First",
                Icons.arrow_upward, SortOption.expiryAsc),
            _sortTile(ctx, "Expiry: Latest First",
                Icons.arrow_downward, SortOption.expiryDesc),
            _sortTile(ctx, "Name: A to Z",
                Icons.sort_by_alpha, SortOption.nameAsc),
            _sortTile(ctx, "Name: Z to A",
                Icons.sort_by_alpha, SortOption.nameDesc),
            _sortTile(ctx, "Group: A to Z",
                Icons.folder_outlined, SortOption.groupAsc),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(BuildContext ctx, String label, IconData icon,
      SortOption option) {
    final bool isSelected = _currentSort == option;
    return ListTile(
      leading: Icon(icon,
          color: isSelected
              ? const Color.fromARGB(255, 90, 76, 132)
              : Colors.grey[500],
          size: 20),
      title: Text(label,
          style: TextStyle(
              fontSize: 15,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? const Color.fromARGB(255, 90, 76, 132)
                  : Colors.black87)),
      trailing: isSelected
          ? Icon(Icons.check,
              color: const Color.fromARGB(255, 90, 76, 132), size: 20)
          : null,
      onTap: () {
        setState(() => _currentSort = option);
        Navigator.pop(ctx);
      },
    );
  }

  void _confirmDelete(
      BuildContext context, String docId, String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Item"),
        content: Text("Are you sure you want to delete \"$name\"?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await NotificationService().cancelNotification(
          NotificationService.docIdToNotificationId(docId));
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

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: const Color.fromARGB(255, 90, 76, 132)));
        }

        if (snapshot.hasError) {
          return Center(
              child: Text("Error loading items.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 70, color: Colors.grey[300]),
                SizedBox(height: 15),
                Text("No items added yet.",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey)),
                SizedBox(height: 5),
                Text("Tap + or scan a barcode to add your first item.",
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey[400]),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        // Apply search then sort
        final filtered = _filterItems(snapshot.data!.docs);
        final items = _sortItems(filtered);

        return Column(
          children: [

            // ✅ Search bar
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (val) =>
                    setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: "Search by name, group or barcode...",
                  hintStyle:
                      TextStyle(fontSize: 14, color: Colors.grey[400]),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: const Color.fromARGB(255, 90, 76, 132)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),

            // Sort bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Icon(Icons.sort, size: 16, color: Colors.grey[500]),
                  SizedBox(width: 6),
                  Text(_sortLabel(),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600])),
                  Spacer(),
                  // Search results count
                  if (_searchQuery.isNotEmpty)
                    Text(
                      "${items.length} result${items.length != 1 ? 's' : ''}",
                      style: TextStyle(
                          fontSize: 12,
                          color: const Color.fromARGB(255, 90, 76, 132),
                          fontWeight: FontWeight.w500),
                    ),
                  if (_searchQuery.isNotEmpty) SizedBox(width: 10),
                  GestureDetector(
                    onTap: _showSortSheet,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 90, 76, 132)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color.fromARGB(255, 90, 76, 132)
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune,
                              size: 14,
                              color: const Color.fromARGB(
                                  255, 90, 76, 132)),
                          SizedBox(width: 4),
                          Text("Sort",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: const Color.fromARGB(
                                      255, 90, 76, 132),
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Empty search result
            if (items.isEmpty && _searchQuery.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 60, color: Colors.grey[300]),
                      SizedBox(height: 12),
                      Text("No results for \"$_searchQuery\"",
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              // Items list
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final String name = item['name'] ?? 'Unnamed Item';
                    final String group = item['group'] ?? 'General';
                    final String reminder =
                        item['reminderDays'] ?? '0';
                    final String notifTime =
                        item['notificationTime'] ?? 'Not set';

                    final Map<String, dynamic> itemData =
                        item.data() as Map<String, dynamic>;
                    final String barcode =
                        itemData.containsKey('barcode')
                            ? (itemData['barcode'] ?? '')
                            : '';

                    final Timestamp? expiryTimestamp =
                        item['expiryDate'] as Timestamp?;
                    if (expiryTimestamp == null) return SizedBox();
                    final DateTime expiry = expiryTimestamp.toDate();
                    final Color statusColor = _expiryColor(expiry);

                    return Card(
                      margin: EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: statusColor.withOpacity(0.4),
                            width: 1.2),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 15, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // Left color strip
                            Container(
                              width: 5,
                              height: 80,
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),

                            SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [

                                  // Name and expiry badge
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(name,
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 16)),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: statusColor
                                                  .withOpacity(0.5)),
                                        ),
                                        child: Text(_expiryLabel(expiry),
                                            style: TextStyle(
                                                color: statusColor,
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 11)),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 4),

                                  Text("Group: $group",
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600])),

                                  if (barcode.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 3),
                                      child: Row(
                                        children: [
                                          Icon(Icons.qr_code,
                                              size: 13,
                                              color: Colors.grey[400]),
                                          SizedBox(width: 4),
                                          Text(barcode,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[400],
                                                  letterSpacing: 0.5)),
                                        ],
                                      ),
                                    ),

                                  Row(
                                    children: [
                                      Icon(Icons.notifications_outlined,
                                          size: 13,
                                          color: Colors.grey[400]),
                                      SizedBox(width: 4),
                                      Text(
                                          "$reminder days before  •  $notifTime",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500])),
                                    ],
                                  ),

                                  SizedBox(height: 6),

                                  // ✅ Edit and Delete buttons side by side
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [

                                      // ✅ Edit button with pen icon
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditItemPage(
                                                docId: item.id,
                                                itemData: itemData,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: Icon(Icons.edit_outlined,
                                            size: 15,
                                            color: const Color.fromARGB(
                                                255, 90, 76, 132)),
                                        label: Text("Edit",
                                            style: TextStyle(
                                                color: const Color
                                                    .fromARGB(
                                                    255, 90, 76, 132),
                                                fontSize: 13)),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size(0, 0),
                                        ),
                                      ),

                                      SizedBox(width: 4),

                                      // Delete button
                                      TextButton.icon(
                                        onPressed: () => _confirmDelete(
                                            context, item.id, name),
                                        icon: Icon(Icons.delete_outline,
                                            size: 15,
                                            color: Colors.red[400]),
                                        label: Text("Delete",
                                            style: TextStyle(
                                                color: Colors.red[400],
                                                fontSize: 13)),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size(0, 0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
}