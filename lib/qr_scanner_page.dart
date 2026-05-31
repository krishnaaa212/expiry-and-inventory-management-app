import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'add_item.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isScanning = true;
  bool _isFetching = false;
  String _statusMessage = "Point camera at any product barcode";

  final List<Map<String, String>> _databases = [
    {
      'name': 'Food & Drinks',
      'url': 'https://world.openfoodfacts.org/api/v0/product/',
    },
    {
      'name': 'Cosmetics & Beauty',
      'url': 'https://world.openbeautyfacts.org/api/v0/product/',
    },
    {
      'name': 'Pet Food',
      'url': 'https://world.openpetfoodfacts.org/api/v0/product/',
    },
    {
      'name': 'Household & Cleaning',
      'url': 'https://world.openproductsfacts.org/api/v0/product/',
    },
  ];

  // ── Camera scan handler ──────────────────────────────────────────
  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_isScanning) return;
    final String? barcode = capture.barcodes.first.rawValue;
    if (barcode == null) return;

    setState(() {
      _isScanning = false;
      _isFetching = true;
      _statusMessage = "Barcode: $barcode";
    });

    await _cameraController.stop();
    await _lookupBarcode(barcode);
  }

  // ── Gallery picker ───────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (image == null) return;

      setState(() {
        _isScanning = false;
        _isFetching = true;
        _statusMessage = "Scanning image from gallery...";
      });

      await _cameraController.stop();

      final BarcodeCapture? result =
          await _cameraController.analyzeImage(image.path);

      if (result == null || result.barcodes.isEmpty) {
        setState(() => _isFetching = false);
        _showNoBarcodeDialog();
        return;
      }

      final String? barcode = result.barcodes.first.rawValue;
      if (barcode == null) {
        setState(() => _isFetching = false);
        _showNoBarcodeDialog();
        return;
      }

      setState(() => _statusMessage = "Barcode found: $barcode");
      await _lookupBarcode(barcode);
    } catch (e) {
      setState(() => _isFetching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not read image. Try again.")),
      );
      _resetScanner();
    }
  }

  // ── Lookup barcode across all databases ──────────────────────────
  Future<void> _lookupBarcode(String barcode) async {
    String? foundName;
    String? foundGroup;
    DateTime? foundExpiry;
    String? foundDb;

    for (final db in _databases) {
      if (foundName != null) break;

      setState(() =>
          _statusMessage = "Checking ${db['name']} database...");

      // Pass the database name so we can auto-assign group from it
      final result = await _queryDatabase(
        barcode: barcode,
        url: db['url']!,
        dbName: db['name']!,
      );

      if (result != null) {
        foundName = result['name'];
        foundGroup = result['group'];
        foundDb = db['name'];

        // Parse expiry date if returned
        final String? expiryStr = result['expiry'];
        if (expiryStr != null && expiryStr.isNotEmpty) {
          foundExpiry = _parseExpiryDate(expiryStr);
        }
      }
    }

    setState(() => _isFetching = false);

    _showReminderSheet(
      barcode: barcode,
      prefillName: foundName ?? '',
      prefillGroup: foundGroup ?? 'General',
      prefillExpiry: foundExpiry,
      wasFound: foundName != null,
      foundInDb: foundDb ?? '',
    );
  }

  // ── Query single database — now returns name, group, expiry ──────
  Future<Map<String, String>?> _queryDatabase({
    required String barcode,
    required String url,
    required String dbName,
  }) async {
    try {
      final res = await http
          .get(Uri.parse('$url$barcode.json'))
          .timeout(Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 1) {
          final product = data['product'];

          // ── Product name ────────────────────────────────
          final String name = (product['product_name'] ??
                  product['product_name_en'] ??
                  product['abbreviated_product_name'] ??
                  '')
              .toString()
              .trim();

          if (name.isEmpty) return null;

          // ── Auto group from API category OR database name ─
          final String group = _resolveGroup(
            apiCategories: product['categories']?.toString() ?? '',
            dbName: dbName,
          );

          // ── Expiry date ─────────────────────────────────
          final String expiry = (product['expiration_date'] ??
                  product['expiry_date'] ??
                  '')
              .toString()
              .trim();

          return {
            'name': name,
            'group': group,
            'expiry': expiry,
          };
        }
      }
    } catch (e) {
      print("DB error ($url): $e");
    }
    return null;
  }

  // ── Smart group resolver ─────────────────────────────────────────
  // Tries to pick a clean group from API categories string
  // Falls back to database name if nothing useful found
  String _resolveGroup(
      {required String apiCategories, required String dbName}) {
    
    // Map of keywords → clean group name
    final Map<String, String> keywordMap = {
      // Food
      'dairy': 'Food',
      'milk': 'Food',
      'cheese': 'Food',
      'yogurt': 'Food',
      'meat': 'Food',
      'poultry': 'Food',
      'fish': 'Food',
      'seafood': 'Food',
      'bread': 'Food',
      'bakery': 'Food',
      'cereal': 'Food',
      'snack': 'Food',
      'chocolate': 'Food',
      'biscuit': 'Food',
      'beverage': 'Food',
      'juice': 'Food',
      'water': 'Food',
      'coffee': 'Food',
      'tea': 'Food',
      'sauce': 'Food',
      'condiment': 'Food',
      'oil': 'Food',
      'spice': 'Food',
      'pasta': 'Food',
      'rice': 'Food',
      'frozen': 'Food',
      'organic': 'Food',
      'vegetable': 'Food',
      'fruit': 'Food',
      'egg': 'Food',
      'butter': 'Food',
      'cream': 'Food',
      'ice cream': 'Food',
      'soup': 'Food',
      'noodle': 'Food',

      // Drinks
      'soda': 'Drinks',
      'soft drink': 'Drinks',
      'energy drink': 'Drinks',
      'alcohol': 'Drinks',
      'beer': 'Drinks',
      'wine': 'Drinks',
      'spirits': 'Drinks',

      // Medicine
      'medicine': 'Medicine',
      'tablet': 'Medicine',
      'capsule': 'Medicine',
      'syrup': 'Medicine',
      'supplement': 'Medicine',
      'vitamin': 'Medicine',
      'pharmaceutical': 'Medicine',
      'drug': 'Medicine',

      // Cosmetics
      'cosmetic': 'Cosmetics',
      'beauty': 'Cosmetics',
      'skincare': 'Cosmetics',
      'makeup': 'Cosmetics',
      'lipstick': 'Cosmetics',
      'foundation': 'Cosmetics',
      'shampoo': 'Cosmetics',
      'conditioner': 'Cosmetics',
      'moisturizer': 'Cosmetics',
      'sunscreen': 'Cosmetics',
      'perfume': 'Cosmetics',
      'deodorant': 'Cosmetics',
      'soap': 'Cosmetics',
      'lotion': 'Cosmetics',
      'toothpaste': 'Cosmetics',

      // Pet Food
      'pet': 'Pet Food',
      'dog food': 'Pet Food',
      'cat food': 'Pet Food',
      'animal feed': 'Pet Food',

      // Household
      'household': 'Household',
      'cleaning': 'Household',
      'detergent': 'Household',
      'bleach': 'Household',
      'disinfectant': 'Household',
      'laundry': 'Household',
      'dishwash': 'Household',
    };

    final String lower = apiCategories.toLowerCase();

    for (final entry in keywordMap.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // Fallback — use the database name as group
    switch (dbName) {
      case 'Food & Drinks':
        return 'Food';
      case 'Cosmetics & Beauty':
        return 'Cosmetics';
      case 'Pet Food':
        return 'Pet Food';
      case 'Household & Cleaning':
        return 'Household';
      default:
        return 'General';
    }
  }

  // ── Parse expiry date string from API ────────────────────────────
  // API returns dates in various formats: 
  // "2025-06", "06/2025", "2025-06-30", "30/06/2025"
  DateTime? _parseExpiryDate(String raw) {
    try {
      raw = raw.trim();

      // Format: 2025-06-30
      final RegExp fullDash = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
      final match1 = fullDash.firstMatch(raw);
      if (match1 != null) {
        return DateTime(
          int.parse(match1.group(1)!),
          int.parse(match1.group(2)!),
          int.parse(match1.group(3)!),
        );
      }

      // Format: 30/06/2025
      final RegExp ddmmyyyy = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
      final match2 = ddmmyyyy.firstMatch(raw);
      if (match2 != null) {
        return DateTime(
          int.parse(match2.group(3)!),
          int.parse(match2.group(2)!),
          int.parse(match2.group(1)!),
        );
      }

      // Format: 2025-06 (year-month only, use last day of month)
      final RegExp yearMonth = RegExp(r'^(\d{4})-(\d{2})$');
      final match3 = yearMonth.firstMatch(raw);
      if (match3 != null) {
        final int year = int.parse(match3.group(1)!);
        final int month = int.parse(match3.group(2)!);
        // Last day of that month
        final DateTime lastDay =
            DateTime(year, month + 1, 0);
        return lastDay;
      }

      // Format: 06/2025 (month/year only)
      final RegExp mmyyyy = RegExp(r'^(\d{2})/(\d{4})$');
      final match4 = mmyyyy.firstMatch(raw);
      if (match4 != null) {
        final int month = int.parse(match4.group(1)!);
        final int year = int.parse(match4.group(2)!);
        final DateTime lastDay = DateTime(year, month + 1, 0);
        return lastDay;
      }
    } catch (e) {
      print("Expiry parse error: $e");
    }
    return null; // Could not parse
  }

  // ── Show no barcode dialog ───────────────────────────────────────
  void _showNoBarcodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code, color: Colors.orange),
            SizedBox(width: 8),
            Text("No Barcode Found"),
          ],
        ),
        content: Text(
          "No barcode was detected in that image.\n\nTips:\n• Make sure barcode is clear\n• Try a closer crop\n• Use camera scan instead",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pickFromGallery();
            },
            child: Text("Try Again"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetScanner();
            },
            child: Text("Use Camera"),
          ),
        ],
      ),
    );
  }

  // ── Reminder-only bottom sheet ───────────────────────────────────
  // Only asks for reminder days — everything else is auto-filled
  void _showReminderSheet({
    required String barcode,
    required String prefillName,
    required String prefillGroup,
    required DateTime? prefillExpiry,
    required bool wasFound,
    required String foundInDb,
  }) {
    final TextEditingController nameController =
        TextEditingController(text: prefillName);
    final TextEditingController reminderController =
        TextEditingController();
    DateTime? selectedExpiry = prefillExpiry;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Header
                Row(
                  children: [
                    Icon(
                      wasFound ? Icons.check_circle : Icons.qr_code,
                      color: wasFound ? Colors.green
                          : const Color.fromARGB(255, 90, 76, 132),
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wasFound
                                ? "Product Found!"
                                : "Barcode Scanned",
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            wasFound
                                ? "Found in: $foundInDb"
                                : "Not found — enter details below.",
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 14),

                // ── Auto-filled info cards ──────────────────
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        "Auto-filled Details",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                        ),
                      ),

                      SizedBox(height: 10),

                      // Product name (editable)
                      Text("Product Name",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          hintText: "Enter product name",
                        ),
                      ),

                      SizedBox(height: 10),

                      // Category — auto assigned, shown as badge
                      Row(
                        children: [
                          Text("Category:  ",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600])),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 90, 76, 132)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color.fromARGB(
                                    255, 90, 76, 132).withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              prefillGroup,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color.fromARGB(
                                    255, 90, 76, 132),
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.auto_awesome,
                              size: 14, color: Colors.amber[600]),
                          SizedBox(width: 3),
                          Text(
                            "Auto",
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber[700]),
                          ),
                        ],
                      ),

                      SizedBox(height: 10),

                      // Expiry date — show if fetched, allow picking if not
                      Row(
                        children: [
                          Text("Expiry Date:  ",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600])),
                          if (selectedExpiry != null)
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.green[300]!),
                                  ),
                                  child: Text(
                                    "${selectedExpiry!.day}/${selectedExpiry!.month}/${selectedExpiry!.year}",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.amber[600]),
                                SizedBox(width: 3),
                                Text(
                                  "Auto",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber[700]),
                                ),
                              ],
                            )
                          else
                            // Not found in API — let user pick
                            GestureDetector(
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now()
                                      .add(Duration(days: 1)),
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
                                  setSheetState(
                                      () => selectedExpiry = picked);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.orange[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 13,
                                        color: Colors.orange[700]),
                                    SizedBox(width: 5),
                                    Text(
                                      "Tap to pick date *",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: 10),

                      // Barcode
                      Row(
                        children: [
                          Icon(Icons.qr_code,
                              size: 14, color: Colors.grey[400]),
                          SizedBox(width: 6),
                          Text(
                            barcode,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // ── Only manual input: Reminder Days ───────
                Text(
                  "Reminder Days",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                TextField(
                  controller: reminderController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        "e.g. 3 (notified 3 days before expiry)",
                    prefixIcon: Icon(Icons.notifications_outlined,
                        color: Colors.grey[400]),
                  ),
                ),

                SizedBox(height: 20),

                // Continue button
                ElevatedButton.icon(
                  onPressed: () {
                    final String name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text("Please enter a product name")),
                      );
                      return;
                    }
                    if (selectedExpiry == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text("Please select an expiry date")),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddItemPage(
                          prefillName: name,
                          prefillGroup: prefillGroup,
                          prefillBarcode: barcode,
                          prefillExpiry: selectedExpiry,
                          prefillReminderDays: reminderController
                              .text
                              .trim(),
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.save),
                  label: Text("Save Item"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color.fromARGB(255, 90, 76, 132),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),

                SizedBox(height: 10),

                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetScanner();
                  },
                  child: Center(child: Text("Scan Again")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _isScanning = true;
      _statusMessage = "Point camera at any product barcode";
    });
    _cameraController.start();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan Product"),
        backgroundColor: const Color.fromARGB(255, 90, 76, 132),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library),
            onPressed: _isFetching ? null : _pickFromGallery,
            tooltip: "Pick from Gallery",
          ),
          IconButton(
            icon: Icon(Icons.flashlight_on),
            onPressed: () => _cameraController.toggleTorch(),
            tooltip: "Toggle Flashlight",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: _onBarcodeDetected,
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color.fromARGB(255, 90, 76, 132),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(children: _buildCorners()),
                  ),
                ),
                if (_isFetching)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: const Color.fromARGB(
                                  255, 90, 76, 132),
                            ),
                            SizedBox(height: 14),
                            Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700]),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Searching all 4 databases...",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding:
                EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              children: [
                Text(
                  "Point camera at any product barcode",
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  "Food • Cosmetics • Pet Food • Household",
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
                SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isFetching ? null : _pickFromGallery,
                  icon: Icon(Icons.photo_library_outlined,
                      color:
                          const Color.fromARGB(255, 90, 76, 132),
                      size: 18),
                  label: Text(
                    "Pick Barcode Image from Gallery",
                    style: TextStyle(
                      color: const Color.fromARGB(255, 90, 76, 132),
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 42),
                    side: BorderSide(
                        color:
                            const Color.fromARGB(255, 90, 76, 132)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const Color c = Color.fromARGB(255, 90, 76, 132);
    const double s = 22;
    const double t = 3;
    return [
      Positioned(top: 0, left: 0, child: Container(width: s, height: t, color: c)),
      Positioned(top: 0, left: 0, child: Container(width: t, height: s, color: c)),
      Positioned(top: 0, right: 0, child: Container(width: s, height: t, color: c)),
      Positioned(top: 0, right: 0, child: Container(width: t, height: s, color: c)),
      Positioned(bottom: 0, left: 0, child: Container(width: s, height: t, color: c)),
      Positioned(bottom: 0, left: 0, child: Container(width: t, height: s, color: c)),
      Positioned(bottom: 0, right: 0, child: Container(width: s, height: t, color: c)),
      Positioned(bottom: 0, right: 0, child: Container(width: t, height: s, color: c)),
    ];
  }
}