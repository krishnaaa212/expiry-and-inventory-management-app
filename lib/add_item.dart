import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart'; // Notification service

class AddItemPage extends StatefulWidget {
  final String? prefillName;
  final String? prefillGroup;
  final String? prefillBarcode;
  final DateTime? prefillExpiry;       // ← ADD THIS
  final String? prefillReminderDays;   // ← ADD THIS

  const AddItemPage({
    super.key,
    this.prefillName,
    this.prefillGroup,
    this.prefillBarcode,
    this.prefillExpiry,                // ← ADD THIS
    this.prefillReminderDays,          // ← ADD THIS
  });

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  late final TextEditingController itemController;
  late final TextEditingController reminderController;
  late final TextEditingController groupController;
  late final TextEditingController barcodeController;

  DateTime? selectedExpiryDate;
  TimeOfDay? selectedNotificationTime; // ✅ Time picker instead of text field
  bool _isSaving = false;

  @override
  @override
void initState() {
  super.initState();
  itemController = TextEditingController(text: widget.prefillName ?? '');
  groupController = TextEditingController(text: widget.prefillGroup ?? '');
  barcodeController = TextEditingController(text: widget.prefillBarcode ?? '');
  reminderController = TextEditingController(text: widget.prefillReminderDays ?? '');
  
  // ← ADD THIS: prefill expiry date if passed from scanner
  if (widget.prefillExpiry != null) {
    selectedExpiryDate = widget.prefillExpiry;
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

  // Opens date picker for expiry date
  Future<void> _pickExpiryDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color.fromARGB(255, 90, 76, 132),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedExpiryDate = picked);
  }

  // Opens time picker for notification time
  Future<void> _pickNotificationTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 9, minute: 0), // Default 9:00 AM
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color.fromARGB(255, 90, 76, 132),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedNotificationTime = picked);
  }

  // Formats TimeOfDay to readable string
  String _formatTime(TimeOfDay time) {
    final String hour =
        time.hourOfPeriod == 0 ? '12' : time.hourOfPeriod.toString();
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Saves item and schedules notification
  Future<void> _saveItem() async {
    String name = itemController.text.trim();
    String reminder = reminderController.text.trim();
    String group = groupController.text.trim();
    String barcode = barcodeController.text.trim();

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
      String userId = FirebaseAuth.instance.currentUser!.uid;

      // Default notification time to 9:00 AM if not selected
      final TimeOfDay notifTime =
          selectedNotificationTime ?? TimeOfDay(hour: 9, minute: 0);

      final int reminderDays = int.tryParse(reminder) ?? 0;

      // Save item to Firestore
      final DocumentReference docRef =
          await FirebaseFirestore.instance.collection('items').add({
        'userId': userId,
        'name': name,
        'expiryDate': Timestamp.fromDate(selectedExpiryDate!),
        'reminderDays': reminder.isEmpty ? '0' : reminder,
        'notificationTime': _formatTime(notifTime),
        'group': group.isEmpty ? 'General' : group,
        'barcode': barcode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ Schedule notification using the document ID as unique identifier
      await NotificationService().scheduleItemNotification(
        id: NotificationService.docIdToNotificationId(docRef.id),
        itemName: name,
        expiryDate: selectedExpiryDate!,
        reminderDays: reminderDays,
        notificationTime: notifTime,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Item added and notification scheduled!")),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Save error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save item. Try again.")),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Item"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Scanned banner
              if (widget.prefillBarcode != null)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_scanner,
                          color: Colors.green[700], size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Product scanned — edit details if needed.",
                          style: TextStyle(
                              color: Colors.green[700], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Item Name
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

              // Barcode
              Text("Barcode",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              TextField(
                controller: barcodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Barcode number (auto-filled if scanned)",
                  prefixIcon:
                      Icon(Icons.qr_code, color: Colors.grey[400], size: 20),
                ),
              ),

              SizedBox(height: 16),

              // Group
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

              // Expiry Date — date picker
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

              // Reminder Days
              Text("Reminder (days before expiry)",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              TextField(
                controller: reminderController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "e.g. 3 (notified 3 days before expiry)",
                ),
              ),

              SizedBox(height: 16),

              // ✅ Notification Time — proper time picker
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
                            ? "Tap to select time (default: 9:00 AM)"
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

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveItem,
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text("Save Item"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}