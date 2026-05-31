import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class BillScannerPage extends StatefulWidget {
  const BillScannerPage({super.key});

  @override
  State<BillScannerPage> createState() => _BillScannerPageState();
}

class _BillScannerPageState extends State<BillScannerPage> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isProcessing = false;
  String _statusMessage = "Scan or upload a bill image";

  // Each product in the bill
  List<_BillItem> _items = [];

  // Databases to search
  final List<Map<String, String>> _databases = [
    {'name': 'Food & Drinks', 'url': 'https://world.openfoodfacts.org/api/v0/product/'},
    {'name': 'Cosmetics & Beauty', 'url': 'https://world.openbeautyfacts.org/api/v0/product/'},
    {'name': 'Pet Food', 'url': 'https://world.openpetfoodfacts.org/api/v0/product/'},
    {'name': 'Household & Cleaning', 'url': 'https://world.openproductsfacts.org/api/v0/product/'},
  ];

  // ── Pick bill image ────────────────────────────────────────────
  Future<void> _pickBill(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 100,
    );
    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _items = [];
      _statusMessage = "Reading bill...";
    });

    await _processBill(image.path);
  }

  // ── OCR + Parse + Lookup ────────────────────────────────────────
  Future<void> _processBill(String imagePath) async {
    try {
      // Step 1 — OCR: extract all text from bill
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final String fullText = recognizedText.text;
      print("📄 OCR Text:\n$fullText");

      if (fullText.trim().isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "No text found in image. Try a clearer photo.";
        });
        return;
      }

      // Step 2 — Extract product names from bill text
      setState(() => _statusMessage = "Extracting products...");
      final List<String> productNames = _extractProductNames(fullText);

      if (productNames.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "No products found. Try again with a clearer bill.";
        });
        return;
      }

      // Step 3 — For each product, search API
      final List<_BillItem> foundItems = [];

      for (int i = 0; i < productNames.length; i++) {
        final String name = productNames[i];
        setState(() =>
            _statusMessage = "Looking up ${i + 1}/${productNames.length}: $name");

        final Map<String, dynamic> info = await _lookupProduct(name);

        foundItems.add(_BillItem(
          name: info['name'] ?? name,
          category: info['category'] ?? 'General',
          expiryDate: info['expiry'],
          reminderDays: TextEditingController(),
          notifTime: null,
        ));
      }

      setState(() {
        _items = foundItems;
        _isProcessing = false;
        _statusMessage = "${foundItems.length} products found from bill";
      });

    } catch (e) {
      print("Bill processing error: $e");
      setState(() {
        _isProcessing = false;
        _statusMessage = "Error reading bill. Please try again.";
      });
    }
  }

  // ── Extract product names from OCR text ────────────────────────
  // Bills typically have one product per line
  // We filter out prices, totals, dates, short lines
  List<String> _extractProductNames(String text) {
    final List<String> lines = text.split('\n');
    final List<String> products = [];

    // Patterns to skip — prices, totals, tax lines, store info
    final RegExp skipPattern = RegExp(
      r'(total|subtotal|tax|gst|vat|discount|cash|change|receipt|invoice|thank|date|time|bill|amount|rs\.?|₹|\d{2}/\d{2}|\d{4}|payment|paid|balance|mrp|hsn|qty|sr\.?\s*no)',
      caseSensitive: false,
    );

    // Must have at least 3 chars and not be mostly numbers/symbols
    final RegExp validLine = RegExp(r'[a-zA-Z]{3,}');

    for (String line in lines) {
      line = line.trim();

      // Skip empty or very short lines
      if (line.length < 3) continue;

      // Skip lines matching price/total/tax patterns
      if (skipPattern.hasMatch(line)) continue;

      // Must contain actual letters
      if (!validLine.hasMatch(line)) continue;

      // Clean up the line — remove prices at end
      // e.g. "Amul Milk 500ml    45.00" → "Amul Milk 500ml"
      String cleaned = line
          .replaceAll(RegExp(r'\s+\d+\.?\d*\s*$'), '')
          .replaceAll(RegExp(r'[\*\#\@\!\|]+'), '')
          .trim();

      if (cleaned.length < 3) continue;

      // Avoid duplicates
      if (!products.contains(cleaned)) {
        products.add(cleaned);
      }
    }

    // Limit to 20 products max
    return products.take(20).toList();
  }

  // ── Lookup product name in all databases ───────────────────────
  Future<Map<String, dynamic>> _lookupProduct(String productName) async {
    // Search by product name (not barcode)
    for (final db in _databases) {
      try {
        final Uri uri = Uri.parse(
          '${db['url']!.replaceAll('/api/v0/product/', '')}'
          '/cgi/search.pl?search_terms=${Uri.encodeComponent(productName)}'
          '&search_simple=1&action=process&json=1&page_size=1',
        );

        final res = await http.get(uri).timeout(Duration(seconds: 6));

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final List products = data['products'] ?? [];

          if (products.isNotEmpty) {
            final product = products.first;

            final String name = (product['product_name'] ??
                    product['product_name_en'] ??
                    productName)
                .toString()
                .trim();

            final String category = _resolveGroup(
              apiCategories: product['categories']?.toString() ?? '',
              dbName: db['name']!,
            );

            final String expiryRaw = (product['expiration_date'] ??
                    product['expiry_date'] ??
                    '')
                .toString()
                .trim();

            final DateTime? expiry = _parseExpiryDate(expiryRaw);

            return {
              'name': name.isNotEmpty ? name : productName,
              'category': category,
              'expiry': expiry,
            };
          }
        }
      } catch (e) {
        print("Search error for $productName: $e");
      }
    }

    // Nothing found — return original name with defaults
    return {
      'name': productName,
      'category': 'General',
      'expiry': null,
    };
  }

  // ── Auto group resolver ────────────────────────────────────────
  String _resolveGroup({required String apiCategories, required String dbName}) {
    final Map<String, String> keywordMap = {
      'dairy': 'Food', 'milk': 'Food', 'cheese': 'Food',
      'yogurt': 'Food', 'meat': 'Food', 'fish': 'Food',
      'bread': 'Food', 'cereal': 'Food', 'snack': 'Food',
      'chocolate': 'Food', 'biscuit': 'Food', 'beverage': 'Food',
      'juice': 'Food', 'coffee': 'Food', 'tea': 'Food',
      'sauce': 'Food', 'oil': 'Food', 'spice': 'Food',
      'pasta': 'Food', 'rice': 'Food', 'frozen': 'Food',
      'vegetable': 'Food', 'fruit': 'Food', 'egg': 'Food',
      'butter': 'Food', 'cream': 'Food', 'soup': 'Food',
      'noodle': 'Food', 'soda': 'Drinks', 'beer': 'Drinks',
      'wine': 'Drinks', 'spirits': 'Drinks',
      'medicine': 'Medicine', 'tablet': 'Medicine',
      'capsule': 'Medicine', 'syrup': 'Medicine',
      'supplement': 'Medicine', 'vitamin': 'Medicine',
      'cosmetic': 'Cosmetics', 'beauty': 'Cosmetics',
      'skincare': 'Cosmetics', 'shampoo': 'Cosmetics',
      'moisturizer': 'Cosmetics', 'sunscreen': 'Cosmetics',
      'soap': 'Cosmetics', 'lotion': 'Cosmetics',
      'toothpaste': 'Cosmetics', 'deodorant': 'Cosmetics',
      'pet': 'Pet Food', 'dog food': 'Pet Food', 'cat food': 'Pet Food',
      'cleaning': 'Household', 'detergent': 'Household',
      'bleach': 'Household', 'laundry': 'Household',
    };

    final String lower = apiCategories.toLowerCase();
    for (final entry in keywordMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    switch (dbName) {
      case 'Food & Drinks': return 'Food';
      case 'Cosmetics & Beauty': return 'Cosmetics';
      case 'Pet Food': return 'Pet Food';
      case 'Household & Cleaning': return 'Household';
      default: return 'General';
    }
  }

  // ── Parse expiry date string ───────────────────────────────────
  DateTime? _parseExpiryDate(String raw) {
    try {
      raw = raw.trim();
      final RegExp fullDash = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
      final m1 = fullDash.firstMatch(raw);
      if (m1 != null) return DateTime(int.parse(m1.group(1)!), int.parse(m1.group(2)!), int.parse(m1.group(3)!));

      final RegExp ddmmyyyy = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
      final m2 = ddmmyyyy.firstMatch(raw);
      if (m2 != null) return DateTime(int.parse(m2.group(3)!), int.parse(m2.group(2)!), int.parse(m2.group(1)!));

      final RegExp yearMonth = RegExp(r'^(\d{4})-(\d{2})$');
      final m3 = yearMonth.firstMatch(raw);
      if (m3 != null) return DateTime(int.parse(m3.group(1)!), int.parse(m3.group(2)! ) + 1, 0);

      final RegExp mmyyyy = RegExp(r'^(\d{2})/(\d{4})$');
      final m4 = mmyyyy.firstMatch(raw);
      if (m4 != null) return DateTime(int.parse(m4.group(2)!), int.parse(m4.group(1)!) + 1, 0);
    } catch (e) { print("Date parse error: $e"); }
    return null;
  }

  // ── Save all items to Firestore ────────────────────────────────
  Future<void> _saveAllItems() async {
    // Validate — every item needs an expiry date
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].expiryDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please set expiry date for: ${_items[i].name}")),
        );
        return;
      }
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Saving items...";
    });

    try {
      final String userId = FirebaseAuth.instance.currentUser!.uid;

      for (final item in _items) {
        final TimeOfDay notifTime =
            item.notifTime ?? TimeOfDay(hour: 9, minute: 0);

        final int reminderDays =
            int.tryParse(item.reminderDays.text.trim()) ?? 0;

        final String formattedTime = _formatTime(notifTime);

        // Save to Firestore
        final DocumentReference docRef =
            await FirebaseFirestore.instance.collection('items').add({
          'userId': userId,
          'name': item.name,
          'expiryDate': Timestamp.fromDate(item.expiryDate!),
          'reminderDays': reminderDays.toString(),
          'notificationTime': formattedTime,
          'group': item.category,
          'barcode': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Schedule notification
        await NotificationService().scheduleItemNotification(
          id: NotificationService.docIdToNotificationId(docRef.id),
          itemName: item.name,
          expiryDate: item.expiryDate!,
          reminderDays: reminderDays,
          notificationTime: notifTime,
        );
      }

      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_items.length} items saved successfully!")),
      );

      Navigator.pop(context);

    } catch (e) {
      print("Save error: $e");
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save. Try again.")),
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final String hour =
        time.hourOfPeriod == 0 ? '12' : time.hourOfPeriod.toString();
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    _textRecognizer.close();
    for (final item in _items) {
      item.reminderDays.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan Bill"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isProcessing
          ? _buildLoadingState()
          : _items.isEmpty
              ? _buildPickerState()
              : _buildItemsState(),
    );
  }

  // ── Loading screen ─────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              color: const Color.fromARGB(255, 90, 76, 132)),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Initial pick screen ────────────────────────────────────────
  Widget _buildPickerState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long,
                size: 80, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              "Scan a Bill",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              "Take a photo of your grocery or pharmacy bill.\nAll products will be detected and saved automatically.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            SizedBox(height: 40),

            // Camera button
            ElevatedButton.icon(
              onPressed: () => _pickBill(ImageSource.camera),
              icon: Icon(Icons.camera_alt),
              label: Text("Take Photo of Bill"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 90, 76, 132),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            SizedBox(height: 12),

            // Gallery button
            OutlinedButton.icon(
              onPressed: () => _pickBill(ImageSource.gallery),
              icon: Icon(Icons.photo_library_outlined,
                  color: const Color.fromARGB(255, 90, 76, 132)),
              label: Text(
                "Upload Bill from Gallery",
                style: TextStyle(
                    color: const Color.fromARGB(255, 90, 76, 132)),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 52),
                side: BorderSide(
                    color: const Color.fromARGB(255, 90, 76, 132)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            SizedBox(height: 20),
            if (_statusMessage != "Scan or upload a bill image")
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[400], fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  // ── Items list screen ──────────────────────────────────────────
  Widget _buildItemsState() {
    return Column(
      children: [

        // Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color.fromARGB(255, 90, 76, 132).withOpacity(0.08),
          child: Row(
            children: [
              Icon(Icons.receipt_long,
                  color: const Color.fromARGB(255, 90, 76, 132), size: 20),
              SizedBox(width: 8),
              Text(
                "${_items.length} products found from bill",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 90, 76, 132),
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: () => _pickBill(ImageSource.camera),
                child: Text("Rescan",
                    style: TextStyle(
                        color: const Color.fromARGB(255, 90, 76, 132),
                        fontSize: 13)),
              ),
            ],
          ),
        ),

        // Items list — each item is its own card with its own settings
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              return _buildItemCard(index);
            },
          ),
        ),

        // Save all button
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _saveAllItems,
            icon: Icon(Icons.save),
            label: Text("Save All ${_items.length} Items"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 90, 76, 132),
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Individual item card ───────────────────────────────────────
  Widget _buildItemCard(int index) {
    final _BillItem item = _items[index];

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Item number + name + delete button
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 90, 76, 132),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red[400], size: 20),
                  onPressed: () {
                    setState(() => _items.removeAt(index));
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),

            SizedBox(height: 10),

            // Auto-filled badges row
            Row(
              children: [
                // Category badge
                _autoBadge(
                  label: item.category,
                  icon: Icons.folder_outlined,
                  color: const Color.fromARGB(255, 90, 76, 132),
                ),
                SizedBox(width: 8),
                // Expiry badge or pick button
                item.expiryDate != null
                    ? _autoBadge(
                        label:
                            "${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year}",
                        icon: Icons.calendar_today,
                        color: Colors.green[700]!,
                      )
                    : GestureDetector(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: const Color.fromARGB(
                                      255, 90, 76, 132),
                                  onPrimary: Colors.white,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(
                                () => _items[index].expiryDate = picked);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 12, color: Colors.orange[700]),
                              SizedBox(width: 4),
                              Text(
                                "Set Expiry *",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),

            SizedBox(height: 12),

            // Reminder days — manual input per item
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Reminder Days",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700])),
                      SizedBox(height: 4),
                      TextField(
                        controller: item.reminderDays,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "e.g. 3",
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),

                // Notification time per item
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Notif Time",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700])),
                      SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime:
                                item.notifTime ?? TimeOfDay(hour: 9, minute: 0),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: const Color.fromARGB(
                                      255, 90, 76, 132),
                                  onPrimary: Colors.white,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _items[index].notifTime = picked);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 16, color: Colors.grey[500]),
                              SizedBox(width: 6),
                              Text(
                                item.notifTime != null
                                    ? _formatTime(item.notifTime!)
                                    : "9:00 AM",
                                style: TextStyle(
                                    fontSize: 13,
                                    color: item.notifTime != null
                                        ? Colors.black
                                        : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Auto-filled badge widget ───────────────────────────────────
  Widget _autoBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          SizedBox(width: 4),
          Icon(Icons.auto_awesome, size: 10, color: Colors.amber[600]),
        ],
      ),
    );
  }
}

// ── Data model for each bill item ──────────────────────────────────
class _BillItem {
  String name;
  String category;
  DateTime? expiryDate;
  TextEditingController reminderDays;
  TimeOfDay? notifTime;

  _BillItem({
    required this.name,
    required this.category,
    this.expiryDate,
    required this.reminderDays,
    this.notifTime,
  });
}