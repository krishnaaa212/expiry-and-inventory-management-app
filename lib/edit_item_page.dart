import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
 
class EditItemPage extends StatefulWidget {
  final String docId;       // Firestore document ID
  final Map<String, dynamic> itemData; // Existing item data
 
  const EditItemPage({
    super.key,
    required this.docId,
    required this.itemData,
  });
 
  @override
  State<EditItemPage> createState() => _EditItemPageState();
}
 
class _EditItemPageState extends State<EditItemPage> {
  late final TextEditingController itemController;
  late final TextEditingController reminderController;
  late final TextEditingController groupController;
  late final TextEditingController barcodeController;
 
  DateTime? selectedExpiryDate;
  TimeOfDay? selectedNotificationTime;
  bool _isSaving = false;
 
  @override
  void initState() {
    super.initState();
    // Pre-fill all fields with existing item data
    itemController =
        TextEditingController(text: widget.itemData['name'] ?? '');
    groupController =
        TextEditingController(text: widget.itemData['group'] ?? '');
    barcodeController =
        TextEditingController(text: widget.itemData['barcode'] ?? '');
    reminderController =
        TextEditingController(text: widget.itemData['reminderDays'] ?? '0');
 
    // Pre-fill expiry date
    final Timestamp? ts = widget.itemData['expiryDate'] as Timestamp?;
    if (ts != null) selectedExpiryDate = ts.toDate();
 
    // Pre-fill notification time
    final String? timeStr = widget.itemData['notificationTime'];
    if (timeStr != null && timeStr != 'Not set') {
      selectedNotificationTime = _parseTime(timeStr);
    }
  }
 
  @override
  void dispose() {
    itemController.dispose();
    groupController.dispose();
    barcodeController.dispose();
    reminderController.dispose();
    super.dispose();
  }
 
  // Parses "9:00 AM" string back to TimeOfDay
  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      final minPeriod = parts[1].split(' ');
      int minute = int.parse(minPeriod[0]);
      final period = minPeriod[1];
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return TimeOfDay(hour: 9, minute: 0);
    }
  }
 
  String _formatTime(TimeOfDay time) {
    final String hour =
        time.hourOfPeriod == 0 ? '12' : time.hourOfPeriod.toString();
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
 
  Future<void> _pickExpiryDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedExpiryDate ?? DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color.fromARGB(255, 90, 76, 132),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedExpiryDate = picked);
  }
 
  Future<void> _pickNotificationTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedNotificationTime ?? TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color.fromARGB(255, 90, 76, 132),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedNotificationTime = picked);
  }
 
  Future<void> _saveChanges() async {
    String name = itemController.text.trim();
    String group = groupController.text.trim();
    String barcode = barcodeController.text.trim();
    String reminder = reminderController.text.trim();
 
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter item name")),
      );
      return;
    }
    if (selectedExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select an expiry date")),
      );
      return;
    }
 
    setState(() => _isSaving = true);
 
    try {
      final TimeOfDay notifTime =
          selectedNotificationTime ?? TimeOfDay(hour: 9, minute: 0);
      final int reminderDays = int.tryParse(reminder) ?? 0;
 
      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.docId)
          .update({
        'name': name,
        'group': group.isEmpty ? 'General' : group,
        'barcode': barcode,
        'expiryDate': Timestamp.fromDate(selectedExpiryDate!),
        'reminderDays': reminder.isEmpty ? '0' : reminder,
        'notificationTime': _formatTime(notifTime),
      });
 
      // Cancel old notification and reschedule with new data
      await NotificationService().cancelNotification(
        NotificationService.docIdToNotificationId(widget.docId),
      );
      await NotificationService().scheduleItemNotification(
        id: NotificationService.docIdToNotificationId(widget.docId),
        itemName: name,
        expiryDate: selectedExpiryDate!,
        reminderDays: reminderDays,
        notificationTime: notifTime,
      );
 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Item updated successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update item. Try again.")),
      );
    }
 
    setState(() => _isSaving = false);
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Item"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
 
              Text("Item Name *",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              TextField(
                controller: itemController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "e.g. Milk, Bread, Medicine",
                ),
              ),
 
              SizedBox(height: 16),
 
              Text("Barcode",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              TextField(
                controller: barcodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Barcode number",
                  prefixIcon: Icon(Icons.qr_code,
                      color: Colors.grey[400], size: 20),
                ),
              ),
 
              SizedBox(height: 16),
 
              Text("Group / Category",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              TextField(
                controller: groupController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "e.g. Food, Medicine, Cosmetics",
                ),
              ),
 
              SizedBox(height: 16),
 
              Text("Expiry Date *",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              GestureDetector(
                onTap: _pickExpiryDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18, color: Colors.grey[500]),
                      SizedBox(width: 10),
                      Text(
                        selectedExpiryDate == null
                            ? "Tap to select expiry date"
                            : "${selectedExpiryDate!.day}/${selectedExpiryDate!.month}/${selectedExpiryDate!.year}",
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedExpiryDate == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
 
              SizedBox(height: 16),
 
              Text("Reminder (days before expiry)",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              TextField(
                controller: reminderController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "e.g. 3",
                ),
              ),
 
              SizedBox(height: 16),
 
              Text("Notification Time",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              GestureDetector(
                onTap: _pickNotificationTime,
                child: Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 18, color: Colors.grey[500]),
                      SizedBox(width: 10),
                      Text(
                        selectedNotificationTime == null
                            ? "Tap to select time"
                            : _formatTime(selectedNotificationTime!),
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedNotificationTime == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
 
              SizedBox(height: 30),
 
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 90, 76, 132),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text("Save Changes"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}