import '../storage/customer_directory.dart';
import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
// lib/pages/quotations_page.dart
//import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel;
//import 'package:path_provider/path_provider.dart';
//import '../data/product_catalog.dart';
import 'product_list_page.dart';
import 'quotation_preview_page.dart'; // ✅ new preview page import

import 'dashboard_page.dart'; // added for return home page
//import '../data/customers_data.dart';
import 'customers_page.dart';
import '../models/quotation.dart';
import '../storage/quotation_storage.dart';
import 'saved_quotations_page.dart'; // ✅ new page
import 'page_setup_page.dart'; // ✅ for logo/watermark setup
import '../storage/cloud_preferences.dart';
import 'dart:convert';
import 'dart:typed_data'; // added new for export pdf editing <-- ⭐ REQUIRED for Uint8List
import 'package:file_picker/file_picker.dart';

import '../utils/quotation_pdf_helper.dart'; // adjust path if needed

import '../pages/print_body_settings_page.dart';

class QuotationsPage extends StatefulWidget {
  final Quotation? quotationToEdit; // ✅ for edit mode
  const QuotationsPage({super.key, this.quotationToEdit});
  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> {
  int quotationNumber = 1;
  final List<List<Map<String, dynamic>>> productTables = [[]];
  final List<bool> tableTotalVisibility = [true];
  // Search state
  final TextEditingController customerController = TextEditingController();

  // 🔍 SEARCH CONTROLLER FOR CUSTOMER SEARCH
  final TextEditingController customerSearchCtrl = TextEditingController();

  //String _search = '';//added new
  // Controller so user can edit number manually
  final TextEditingController quotationNumberController =
      TextEditingController();
  Map<String, dynamic>? selectedCustomer; // ✅ instead of String?
  // 🧱 Holds product list loaded from disposeCloudPreferences
  List<Map<String, dynamic>> productList = [];
  List<Map<String, dynamic>> customerList = [];

  String? selectedCategory;
  String? selectedMake;

  // 🔹 Column visibility toggles (DEFAULT = false)
  bool showModelNo = false;
  bool showQty = false;
  bool showUnit = false;
  bool showAmount = true; // 🔹 NEW — Amount column visible by default

  @override
  void initState() {
    super.initState();

    loadColumnToggles(); // ✅ ADD THIS CALL LOAD TOGGLES

    // 1️⃣ load product models saved in CloudPreferences
    loadProductList();

    loadCustomers(); // ✅ Load saved customers for dropdown

    // Compute next number asynchronously (doesn't block UI)
    _initQuotationNumber();

    // 2️⃣ if we came here to edit an existing quotation, pre-fill everything
    if (widget.quotationToEdit != null) {
      final q = widget
          .quotationToEdit!; // fill controller with the existing quotation number (edit mode)
      quotationNumber = q.quotationNumber;
      quotationNumberController.text = q.quotationNumber
          .toString(); // added new

      selectedCustomer = {'name': q.customerName};
      productTables
        ..clear()
        ..addAll(
          q.productTables
              .map(
                (table) =>
                    table.map((row) => Map<String, dynamic>.from(row)).toList(),
              )
              .toList(),
        );
      tableTotalVisibility
        ..clear()
        ..addAll(q.tableTotalVisibility);
    }
  }

  // Helper: load saved quotations and set next available number
  // Helper: load saved quotations and set next available number
  Future<void> _initQuotationNumber() async {
    try {
      //     // 1️⃣ Capture messenger BEFORE await
      // final messenger = ScaffoldMessenger.of(context);

      final list =
          await QuotationStorage.loadQuotations(); // returns List<Quotation>
      // 3️⃣ Always check mounted after await
      if (!mounted) return;

      // // 4️⃣ Use messenger safely
      // messenger.showSnackBar(
      //   const SnackBar(content: Text('Quotations loaded')),
      // );

      // If saved list is empty -> start from 1
      if (list.isEmpty) {
        quotationNumber = 1;
      } else {
        // find max quotationNumber and add 1
        int maxNum = 0;
        // ✅ list is List<Quotation>, so just read the property
        for (final q in list) {
          if (q.quotationNumber > maxNum) {
            maxNum = q.quotationNumber;
          }
        }

        quotationNumber = maxNum + 1;
      }
    } catch (_) {
      // fallback if storage fails
      quotationNumber = 1;
    }

    // If user didn't open in edit-mode (no widget.quotationToEdit),
    // set the controller to suggested number
    if (widget.quotationToEdit == null) {
      quotationNumberController.text = quotationNumber.toString();
    }

    if (!mounted) return;
    setState(() {}); // refresh UI to show number
  }

  // Compute next number asynchronously (doesn't block UI)
  //initQuotationNumber();

  // 3️⃣ keep the helper function outside initState
  Future<void> loadProductList() async {
    final prefs = await CloudPreferences.getInstance();
    final stored = prefs.getStringList('models') ?? <String>[];
    final loaded = stored
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();

    setState(() {
      productList = loaded;
    });
  }

  // Load customers from CloudPreferences

  Future<void> loadCustomers() async {
    try {
      final records = await CustomerDirectory.load();
      if (!mounted) return;

      setState(() {
        customerList = records.map((decoded) {
          return {
            'name': decoded['customerName'] ?? '',
            '_ownerEmail': decoded['_ownerEmail'] ?? '',
            'email': decoded['email'] ?? '',
            'phone': decoded['phone'] ?? '',
            'address': decoded['address'] ?? '',
            'area': decoded['area'] ?? '',
            'state': decoded['state'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load customer directory: $e')),
      );
    }
  }

  // =====================================================
  // 🔍 SEARCHABLE CUSTOMER DIALOG
  // =====================================================
  void openCustomerSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        List<Map<String, dynamic>> filteredCustomers = customerList;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Customer / Building Name'),

              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // 🔍 SEARCH BOX
                    TextField(
                      controller: customerSearchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search customer...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredCustomers = customerList.where((c) {
                            return c['name'].toString().toLowerCase().contains(
                              value.toLowerCase(),
                            );
                          }).toList();
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    // 📜 CUSTOMER LIST
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];

                          return ListTile(
                            title: Text(customer['name']),
                            subtitle: Text(
                              '${customer['area'] ?? ''}\nAdded by: ${customer['_ownerEmail'] ?? ''}',
                            ),
                            onTap: () {
                              setState(() {
                                selectedCustomer = customer;
                              });

                              customerSearchCtrl.clear();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    customerSearchCtrl.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================================
  // QUOTATION COLUMN SETTINGS POPUP
  // ================================
  void _showColumnSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Quotation Column Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Show Model No'),
                value: showModelNo,
                onChanged: (v) {
                  setState(() => showModelNo = v);
                  saveColumnToggles();
                },
              ),
              SwitchListTile(
                title: const Text('Show Quantity'),
                value: showQty,
                onChanged: (v) {
                  setState(() => showQty = v);
                  saveColumnToggles();
                },
              ),
              SwitchListTile(
                title: const Text('Show Unit Price'),
                value: showUnit,
                onChanged: (v) {
                  setState(() => showUnit = v);
                  saveColumnToggles();
                },
              ),
              SwitchListTile(
                title: const Text('Show Amount'),
                value: showAmount,
                onChanged: (v) {
                  setState(() => showAmount = v);
                  saveColumnToggles();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  //LOAD & SAVE TOGGLES (CloudPreferences)

  Future<void> loadColumnToggles() async {
    final prefs = await CloudPreferences.getInstance();

    setState(() {
      showModelNo = prefs.getBool('showModelNo') ?? false;
      showQty = prefs.getBool('showQty') ?? false;
      showUnit = prefs.getBool('showUnit') ?? false;
      // 🔹 NEW
      showAmount = prefs.getBool('showAmount') ?? true; // default ON
    });
  }

  Future<void> saveColumnToggles() async {
    final prefs = await CloudPreferences.getInstance();
    await prefs.setBool('showModelNo', showModelNo);
    await prefs.setBool('showQty', showQty);
    await prefs.setBool('showUnit', showUnit);
    // 🔹 NEW
    await prefs.setBool('showAmount', showAmount);
  }

  double get totalAmount {
    double sum = 0.0;

    for (var i = 0; i < productTables.length; i++) {
      if (!tableTotalVisibility[i]) continue;

      sum += productTables[i].fold(
        0.0,
        (tableSum, row) => tableSum + ((row['total'] ?? 0.0) as num).toDouble(),
      );
    }

    return sum;
  }

  List<Map<String, dynamic>> _tableAt(int tableIndex) =>
      productTables[tableIndex];

  List<Map<String, dynamic>> _cloneTable(List<Map<String, dynamic>> table) {
    return table.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  List<List<Map<String, dynamic>>> _cloneAllTables() {
    return productTables.map(_cloneTable).toList();
  }

  void _renumberTable(int tableIndex) {
    final table = _tableAt(tableIndex);
    for (var i = 0; i < table.length; i++) {
      table[i]['serial'] = i + 1;
    }
  }

  void addProductTable() {
    setState(() {
      productTables.add([]);
      tableTotalVisibility.add(true);
    });
  }

  void addProductRow([int? tableIndex]) {
    final targetTableIndex = tableIndex ?? (productTables.length - 1);
    setState(() {
      final table = _tableAt(targetTableIndex);
      table.add({
        'serial': table.length + 1,
        'modelNo': '',
        'modelDesc': '',
        'notes': '', // ✅ NEW
        'qty': 1,
        'unit': 0.0,
        'total': 0.0,
      });
    });
  }

  //--------- update row --------- updated due to not save the product
  void updateRow(int tableIndex, int index, String field, dynamic value) {
    setState(() {
      final table = _tableAt(tableIndex);
      table[index][field] = value;

      final qty = (table[index]['qty'] ?? 0).toDouble();
      final unit = (table[index]['unit'] ?? 0.0).toDouble();
      table[index]['total'] = qty * unit;
    });
  }

  /// Remove product row at [index] and re-number serials.
  void removeProductRow(int tableIndex, int index) {
    final table = _tableAt(tableIndex);
    if (index < 0 || index >= table.length) return;
    setState(() {
      table.removeAt(index);
      _renumberTable(tableIndex);
    });
  }

  void removeProductTable(int tableIndex) {
    if (productTables.length <= 1 ||
        tableIndex < 0 ||
        tableIndex >= productTables.length) {
      return;
    }

    setState(() {
      productTables.removeAt(tableIndex);
      tableTotalVisibility.removeAt(tableIndex);
    });
  }

  /// Ask user to confirm row deletion.
  Future<void> confirmDeleteRow(
    BuildContext context,
    int tableIndex,
    int index,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product'),
        content: const Text(
          'Are you sure you want to delete this product row?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      removeProductRow(tableIndex, index);
    }
  }

  Future<void> confirmDeleteTable(BuildContext context, int tableIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete table'),
        content: const Text('Are you sure you want to delete this table?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      removeProductTable(tableIndex);
    }
  }

  Future<void> addQuotation() async {
    // ============================================================
    // ✅ STEP 1: CAPTURE CONTEXT-DEPENDENT OBJECTS
    // ============================================================
    // We MUST capture these BEFORE any `await`
    // This fixes: use_build_context_synchronously warning
    //final messenger = ScaffoldMessenger.of(context);
    //final navigator = Navigator.of(context);
    //final dialogContext = context; // 👈 VERY IMPORTANT

    // 1) Get customer name
    final customerName = selectedCustomer?['name'] ?? '';

    // ✅ VALIDATION MUST BE BEFORE ANY await
    if (customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a customer / building name'),
        ),
      );
      return;
    }
    // 3) Parse quotation number from controller (fallback to computed)
    int chosenNumber;
    final textVal = quotationNumberController.text.trim();

    if (textVal.isEmpty) {
      // fallback to computed number
      chosenNumber = quotationNumber;
    } else {
      chosenNumber = int.tryParse(textVal) ?? quotationNumber;
    }

    // 4) Load existing quotations to check duplicates
    final savedList =
        await QuotationStorage.loadQuotations(); // List<Quotation>

    // ✅ Add this line to satisfy the analyzer:
    if (!mounted) return;

    final existsIndex = savedList.indexWhere(
      (q) => q.quotationNumber == chosenNumber,
    );

    // 5) If not in edit mode and number already exists, choose behavior:
    if (widget.quotationToEdit == null && existsIndex >= 0) {
      // 1) guard in case widget unmounted before we attempt to show anything
      if (!mounted) return;

      // 2) capture a local BuildContext variable **right now** (no async gap between capture and use)

      // 3) show dialog using the captured local context

      // Show dialog safely
      final action = await showDialog<String>(
        context: context, // ✅ State.context
        builder: (ctx) => AlertDialog(
          title: const Text('Quotation number exists'),
          content: Text(
            'Quotation number $chosenNumber already exists. What do you want to do?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'increment'),
              child: const Text('Use next number'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              child: const Text('Overwrite'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      // ✅ REQUIRED immediately after await
      if (!mounted) return;

      // 4) defend again immediately after the await
      //if (!mounted) return;

      if (action == 'cancel' || action == null) {
        return; // user cancelled
      } else if (action == 'increment') {
        // find max and use next number
        int maxNum = 0;
        for (var q in savedList) {
          if (q.quotationNumber > maxNum) maxNum = q.quotationNumber;
        }
        chosenNumber = maxNum + 1;
        quotationNumberController.text = chosenNumber.toString();
      } else {
        // overwrite chosenNumber -> we'll save with same number (saveQuotation will update existing)
      }
    }

    // 6) Build clean copies of all tables to save
    final productTablesToStore = productTables.map((table) {
      return table.map((r) {
        return {
          'serial': r['serial'],
          'modelNo': r['modelNo'] ?? '',
          'modelDesc': r['modelDesc'] ?? '',
          'notes': r['notes'] ?? '',
          'qty': r['qty'] ?? 0,
          'unit': (r['unit'] ?? 0.0).toDouble(),
          'total': (r['total'] ?? 0.0).toDouble(),
          'category': r['category'] ?? '',
          'make': r['make'] ?? '',
        };
      }).toList();
    }).toList();

    // 7) Create Quotation model instance (you imported ../models/quotation.dart)
    final quotation = Quotation(
      // quotationNumber: quotationNumber,
      quotationNumber: chosenNumber, // ✅ use the number from the field
      customerName: customerName,
      date: DateTime.now(),
      products: productTablesToStore.first,
      productTables: productTablesToStore,
      tableTotalVisibility: List<bool>.from(tableTotalVisibility),
      totalAmount: totalAmount,
    );

    // 8) Save permanently using your storage helper
    //    (QuotationStorage.saveQuotation should accept a Quotation object)
    await QuotationStorage.saveQuotation(quotation);

    // 9) Guard: if widget disposed while saving, stop (prevents exceptions)
    if (!mounted) return;

    // 10) Update UI for next new quotation (only when not editing)
    if (widget.quotationToEdit == null) {
      // compute next expected number
      final next = chosenNumber + 1;
      setState(() {
        quotationNumber = next;
        quotationNumberController.text = next.toString();
        productTables
          ..clear()
          ..add([]);
        tableTotalVisibility
          ..clear()
          ..add(true);
        selectedCustomer = null;
      });
    } else {
      // If we were editing, keep current controller in sync
      setState(() {
        quotationNumber = chosenNumber;
        quotationNumberController.text = chosenNumber.toString();
      });
    }

    // 11) Feedback to user
    // ✅ Final UI feedback (safe: context captured before await)
    if (!mounted) return;
    // ✅ CORRECT — use captured context
    final messenger = ScaffoldMessenger.of(context);

    if (!mounted) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Quotation saved successfully')),
    );
  }

  Future<void> openProductListPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductListPage()),
    );

    if (!mounted) return;

    // reload products after returning
    await loadProductList();
    setState(() {});
  }

  //// Shows a wide dialog for editing a product row (model no / desc / qty / unit).
  /// 🔹 Now includes a 2nd popup for LP & Discount to auto-calc Unit Price.
  Future<void> showEditProductDialog(int tableIndex, int index) async {
    final row = _tableAt(tableIndex)[index];
    // 🔹 Category & Make (backend filtering) // state variables FIRST
    String selectedCategory = row['category'] ?? '';
    String selectedMake = row['make'] ?? '';
    // Controllers (prefill from existing row)
    String? currentModelNo = (row['modelNo'] as String?)?.trim();
    String currentDesc = (row['modelDesc'] as String?) ?? '';
    String currentNotes = row['notes'] ?? '';

    // ================================
    // CATEGORY → MAKE → MODEL HELPERS
    // ================================

    List<String> getCategories(List<Map<String, dynamic>> products) {
      return products
          .map((e) => (e['category'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    List<String> getMakesByCategory(
      List<Map<String, dynamic>> products,
      String category,
    ) {
      if (category.isEmpty) return [];

      return products
          .where((e) => e['category'] == category)
          .map((e) => (e['make'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    List<Map<String, dynamic>> getFilteredModels({
      required List<Map<String, dynamic>> products,
      required String category,
      required String make,
    }) {
      return products.where((e) {
        if (category.isNotEmpty && e['category'] != category) return false;
        if (make.isNotEmpty && e['make'] != make) return false;
        return true;
      }).toList();
    }

    final qtyController = TextEditingController(
      text: (row['qty'] ?? 1).toString(),
    );
    final unitController = TextEditingController(
      text: (row['unit'] ?? 0.0).toString(),
    );

    final formKey = GlobalKey<FormState>();

    int modelRebuildKey = 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StatefulBuilder(
                builder: (contextSB, setStateSB) {
                  void resetModelSelection() {
                    currentModelNo = null;
                    currentDesc = '';
                    unitController.text = '';
                    // 🔥 force rebuild autocomplete
                    modelRebuildKey++;
                  }

                  // -------------------------------
                  // CHECK AVAILABLE PRICES (for icon color)
                  // -------------------------------
                  bool hasBasicPrice = false;
                  bool hasLpOrSp = false;

                  if (currentModelNo != null && currentModelNo!.isNotEmpty) {
                    final model = productList.firstWhere(
                      (m) => (m['no'] ?? '') == currentModelNo,
                      orElse: () => {},
                    );

                    final bp = double.tryParse('${model['bp'] ?? 0}') ?? 0;
                    final lp = double.tryParse('${model['lp'] ?? 0}') ?? 0;
                    final sp = double.tryParse('${model['sp'] ?? 0}') ?? 0;

                    hasBasicPrice = bp > 0;
                    hasLpOrSp = lp > 0 || sp > 0;
                  }

                  // ================================
                  // FILTER DATA (LIVE, DEPENDENT)
                  // ================================

                  // Category list (always full)
                  final categories = getCategories(productList);

                  // Makes depend on selected category
                  final makes = getMakesByCategory(
                    productList,
                    selectedCategory,
                  );

                  // Filter products by category + make
                  final filteredProducts = getFilteredModels(
                    products: productList,
                    category: selectedCategory,
                    make: selectedMake,
                  );

                  // Model numbers
                  final modelNumbers = filteredProducts
                      .map((e) => (e['no'] ?? '').toString())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  // Descriptions
                  final descriptions = filteredProducts
                      .map((e) => (e['desc'] ?? '').toString())
                      .where((e) => e.isNotEmpty)
                      .toSet()
                      .toList();

                  // 🔹 NEW: function to open LP & Discount popup
                  // REPLACE the old openLpDiscountDialog() with this updated function.
                  // It auto-fills LP/SP from productList based on currentModelNo
                  Future<void> openLpDiscountDialog() async {
                    // Create controllers for this small dialog
                    final lpController = TextEditingController();
                    final discController = TextEditingController(
                      text: '0',
                    ); // default 0%

                    // Try to find LP/SP from productList for the currently selected model no
                    double foundLp = 0.0;
                    double foundSp = 0.0;

                    if (currentModelNo != null && currentModelNo!.isNotEmpty) {
                      final match = productList.firstWhere(
                        (m) => (m['no'] ?? '') == currentModelNo,
                        orElse: () => {},
                      );
                      // Defensive parsing
                      try {
                        foundLp = (match['lp'] is num)
                            ? (match['lp'] as num).toDouble()
                            : double.tryParse(
                                    (match['lp'] ?? '0').toString(),
                                  ) ??
                                  0.0;
                      } catch (_) {
                        foundLp = 0.0;
                      }
                      try {
                        foundSp = (match['sp'] is num)
                            ? (match['sp'] as num).toDouble()
                            : double.tryParse(
                                    (match['sp'] ?? '0').toString(),
                                  ) ??
                                  0.0;
                      } catch (_) {
                        foundSp = 0.0;
                      }
                    }

                    // Pre-fill LP controller with foundLP (or blank if 0)
                    if (foundLp > 0) {
                      lpController.text = foundLp.toStringAsFixed(2);
                    } else {
                      lpController.text = '';
                    }

                    // Show the small dialog
                    await showDialog<void>(
                      context: contextSB,
                      builder: (ctx2) {
                        return AlertDialog(
                          title: const Text('List Price & Discount'),
                          content: Form(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // LP field (prefilled if available)
                                TextFormField(
                                  controller: lpController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'List Price (LP)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Show SP value and quick buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Special Price (SP)',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (foundSp > 0)
                                                ? '₹${foundSp.toStringAsFixed(2)}'
                                                : 'Not set',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        // Use LP button
                                        ElevatedButton(
                                          onPressed: () {
                                            // If LP present, use it as unit price
                                            final lp =
                                                double.tryParse(
                                                  lpController.text,
                                                ) ??
                                                0.0;
                                            if (lp > 0) {
                                              unitController.text = lp
                                                  .toStringAsFixed(2);
                                            }
                                            Navigator.pop(ctx2);
                                          },
                                          child: const Text('Use LP'),
                                        ),
                                        const SizedBox(height: 6),
                                        // Use SP button
                                        ElevatedButton(
                                          onPressed: () {
                                            if (foundSp > 0) {
                                              unitController.text = foundSp
                                                  .toStringAsFixed(2);
                                            }
                                            Navigator.pop(ctx2);
                                          },
                                          child: const Text('Use SP'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Discount input (optional) - user can apply discount to LP
                                TextFormField(
                                  controller: discController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Discount (%) — applied to LP',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx2),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                // apply LP and discount to compute unit
                                final lp =
                                    double.tryParse(lpController.text) ??
                                    foundLp;
                                final disc =
                                    double.tryParse(discController.text) ?? 0.0;
                                final unit = lp - (lp * disc / 100.0);
                                unitController.text = unit.toStringAsFixed(2);
                                Navigator.pop(ctx2);
                              },
                              child: const Text('Apply'),
                            ),
                          ],
                        );
                      },
                    );
                  }

                  Future<void> openMarginDialog(double basicPrice) async {
                    final marginCtrl = TextEditingController(text: '0');

                    double computedUnit = basicPrice;

                    await showDialog(
                      context: contextSB,
                      builder: (ctx) {
                        return StatefulBuilder(
                          builder: (context, setLocalState) {
                            return AlertDialog(
                              title: const Text('Basic Price & Margin'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ✅ BASIC PRICE DISPLAY
                                  Row(
                                    children: [
                                      const Text(
                                        'Basic Price:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        basicPrice > 0
                                            ? '₹${basicPrice.toStringAsFixed(2)}'
                                            : 'Not available',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: basicPrice > 0
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // ✅ MARGIN INPUT
                                  TextFormField(
                                    controller: marginCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Margin (%)',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) {
                                      final margin =
                                          double.tryParse(val) ?? 0.0;

                                      setLocalState(() {
                                        computedUnit =
                                            basicPrice +
                                            (basicPrice * margin / 100);
                                      });
                                    },
                                  ),

                                  const SizedBox(height: 14),

                                  // ✅ SHOW UNIT PRICE PREVIEW
                                  Row(
                                    children: [
                                      const Text(
                                        'Unit Price:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '₹${computedUnit.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    unitController.text = computedUnit
                                        .toStringAsFixed(2);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Apply'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  }

                  Future<void> openMoqApplyDialog(
                    Map<String, dynamic> model,
                  ) async {
                    final double moqQty =
                        double.tryParse('${model['moqQty'] ?? 0}') ?? 0;
                    final double moqPrice =
                        double.tryParse('${model['moqPrice'] ?? 0}') ?? 0;

                    final qtyCtrl = TextEditingController(
                      text: moqQty.toString(),
                    );
                    final priceCtrl = TextEditingController(
                      text: moqPrice.toString(),
                    );

                    final marginPercentCtrl = TextEditingController(text: '0');

                    bool applyMargin = false;
                    double marginAmount = 0;
                    double finalUnitPrice = moqPrice;

                    await showDialog(
                      context: contextSB,
                      builder: (ctx) {
                        return StatefulBuilder(
                          builder: (context, setLocal) {
                            void recalc() {
                              final percent =
                                  double.tryParse(marginPercentCtrl.text) ?? 0;

                              marginAmount = moqPrice * percent / 100;
                              finalUnitPrice = applyMargin
                                  ? moqPrice + marginAmount
                                  : moqPrice;
                            }

                            return AlertDialog(
                              title: const Text('Apply MOQ Price'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextFormField(
                                    controller: qtyCtrl,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'MOQ Quantity',
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  TextFormField(
                                    controller: priceCtrl,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'MOQ Unit Price',
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  TextFormField(
                                    controller: marginPercentCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Margin % (Optional)',
                                    ),
                                    onChanged: (_) {
                                      setLocal(() {
                                        recalc();
                                      });
                                    },
                                  ),

                                  const SizedBox(height: 6),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Margin Amount'),
                                      Text(
                                        '₹${marginAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  CheckboxListTile(
                                    value: applyMargin,
                                    onChanged: (v) {
                                      setLocal(() {
                                        applyMargin = v ?? false;
                                        recalc();
                                      });
                                    },
                                    title: const Text('Apply Margin'),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    // ✅ APPLY TO EDIT PRODUCT
                                    qtyController.text = moqQty
                                        .toInt()
                                        .toString();
                                    unitController.text = finalUnitPrice
                                        .toStringAsFixed(2);

                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Apply'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  }

                  return Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Edit Product',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // =======================
                        // CATEGORY DROPDOWN
                        // =======================
                        Row(
                          children: [
                            // CATEGORY
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedCategory.isEmpty
                                    ? null
                                    : selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setStateSB(() {
                                    selectedCategory = val ?? '';
                                    selectedMake = '';
                                    resetModelSelection(); // 👈 important
                                    //currentModelNo = null;
                                    //currentDesc = '';
                                    //unitController.text = '';
                                  });
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            // MAKE
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedMake.isEmpty
                                    ? null
                                    : selectedMake,
                                decoration: const InputDecoration(
                                  labelText: 'Make',
                                  border: OutlineInputBorder(),
                                ),
                                items: makes
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setStateSB(() {
                                    selectedMake = val ?? '';
                                    // 🔥 IMPORTANT FIX
                                    resetModelSelection();
                                    //currentModelNo = null;
                                    //currentDesc = '';
                                    //unitController.text = '';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Row: Model No + Description
                        // =======================
                        // MODEL NO (FULL WIDTH)
                        // =======================
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Model No',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),

                            //Model dropdown (filtered by category + make)
                            Autocomplete<String>(
                              key: ValueKey('model_$modelRebuildKey'),
                              optionsBuilder: (text) {
                                if (text.text.isEmpty) return modelNumbers;
                                return modelNumbers.where(
                                  (m) => m.toLowerCase().contains(
                                    text.text.toLowerCase(),
                                  ),
                                );
                              },
                              initialValue: TextEditingValue(
                                text: currentModelNo ?? '',
                              ),
                              onSelected: (selected) {
                                currentModelNo = selected;

                                final match = filteredProducts.firstWhere(
                                  (m) => (m['no'] ?? '') == selected,
                                  orElse: () => {},
                                );

                                currentDesc = (match['desc'] ?? '').toString();

                                // auto price fill
                                final sp =
                                    double.tryParse('${match['sp']}') ?? 0;
                                final lp =
                                    double.tryParse('${match['lp']}') ?? 0;

                                if (sp > 0) {
                                  unitController.text = sp.toStringAsFixed(2);
                                } else if (lp > 0) {
                                  unitController.text = lp.toStringAsFixed(2);
                                }

                                setStateSB(() {});
                              },
                              fieldViewBuilder:
                                  (context, controller, focusNode, _) {
                                    controller.text = currentModelNo ?? '';
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      onChanged: (val) {
                                        currentModelNo = val; // ✅ KEEP IN SYNC
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Model No',
                                        border: OutlineInputBorder(),
                                      ),
                                    );
                                  },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // =======================
                        // DESCRIPTION + NOTES
                        // =======================
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Description',
                                  style: TextStyle(fontSize: 12),
                                ),

                                Row(
                                  children: [
                                    // 🟢 MOQ ICON (COLOR BASED ON MOQ DATA)
                                    IconButton(
                                      tooltip: 'Apply MOQ',
                                      icon: Icon(
                                        Icons.inventory_2,
                                        color: (() {
                                          if (currentModelNo == null ||
                                              currentModelNo!.isEmpty) {
                                            return Colors.grey;
                                          }

                                          final model = productList.firstWhere(
                                            (m) => m['no'] == currentModelNo,
                                            orElse: () => {},
                                          );

                                          final double moqQty =
                                              double.tryParse(
                                                '${model['moqQty'] ?? 0}',
                                              ) ??
                                              0;
                                          final double moqPrice =
                                              double.tryParse(
                                                '${model['moqPrice'] ?? 0}',
                                              ) ??
                                              0;

                                          // ✅ BOTH REQUIRED
                                          return (moqQty > 0 && moqPrice > 0)
                                              ? Colors.green
                                              : Colors.grey;
                                        })(),
                                      ),
                                      onPressed: () {
                                        if (currentModelNo == null ||
                                            currentModelNo!.isEmpty) {
                                          return;
                                        }

                                        final model = productList.firstWhere(
                                          (m) => m['no'] == currentModelNo,
                                          orElse: () => {},
                                        );

                                        final double moqQty =
                                            double.tryParse(
                                              '${model['moqQty'] ?? 0}',
                                            ) ??
                                            0;
                                        final double moqPrice =
                                            double.tryParse(
                                              '${model['moqPrice'] ?? 0}',
                                            ) ??
                                            0;

                                        // ✅ Only open dialog if MOQ exists
                                        if (moqQty > 0 && moqPrice > 0) {
                                          openMoqApplyDialog(model);
                                        }
                                      },
                                    ),

                                    // ⋮ NOTES
                                    IconButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _openNotesDialog(
                                          contextSB,
                                          currentNotes,
                                          (v) => setStateSB(
                                            () => currentNotes = v,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),
                            //Description dropdown (linked)
                            Autocomplete<String>(
                              key: ValueKey('desc_$modelRebuildKey'),
                              optionsBuilder: (text) {
                                if (text.text.isEmpty) return descriptions;
                                return descriptions.where(
                                  (d) => d.toLowerCase().contains(
                                    text.text.toLowerCase(),
                                  ),
                                );
                              },
                              initialValue: TextEditingValue(text: currentDesc),
                              onSelected: (value) {
                                currentDesc = value;

                                final match = filteredProducts.firstWhere(
                                  (m) => (m['desc'] ?? '') == value,
                                  orElse: () => {},
                                );

                                currentModelNo = (match['no'] ?? '').toString();
                                setStateSB(() {});
                              },
                              fieldViewBuilder:
                                  (context, controller, focusNode, _) {
                                    controller.text = currentDesc;
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      maxLines: 2,
                                      onChanged: (val) {
                                        currentDesc = val; // ✅ KEEP IN SYNC
                                      },
                                      decoration: const InputDecoration(
                                        hintText: 'Description',
                                        border: OutlineInputBorder(),
                                      ),
                                    );
                                  },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Row: Qty + Unit (with LP/Discount button)
                        Row(
                          children: [
                            // Qty
                            // ✅ SMALL QTY BOX
                            SizedBox(
                              width: 80, // 👈 small fixed width
                              child: TextFormField(
                                controller: qtyController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Qty';
                                  }
                                  if (int.tryParse(v) == null) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Unit Price + LP/Disc button
                            // ✅ BIG UNIT PRICE AREA
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: unitController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Unit Price',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Enter price';
                                        }
                                        if (double.tryParse(v) == null) {
                                          return 'Invalid';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  Row(
                                    children: [
                                      // 🔹 MARGIN ICON
                                      IconButton(
                                        tooltip: 'Set by Margin',
                                        icon: Icon(
                                          Icons.trending_up,
                                          color: hasBasicPrice
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        onPressed: hasBasicPrice
                                            ? () {
                                                final model = productList
                                                    .firstWhere(
                                                      (m) =>
                                                          m['no'] ==
                                                          currentModelNo,
                                                      orElse: () => {},
                                                    );
                                                final bp =
                                                    (model['bp'] ?? 0.0)
                                                        as double;
                                                if (bp > 0) {
                                                  openMarginDialog(bp);
                                                }
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),

                                  // LP / Discount
                                  IconButton(
                                    tooltip: 'Set by LP & Discount',
                                    icon: Icon(
                                      Icons.calculate,
                                      color: hasLpOrSp
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    onPressed: hasLpOrSp
                                        ? openLpDiscountDialog
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setStateSB(() {
                                  currentModelNo = null;
                                  currentDesc = '';
                                  selectedCategory = '';
                                  selectedMake = '';

                                  qtyController.text =
                                      '1'; // for standar 1qty display
                                  unitController.text = '';
                                });
                              },
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 95, 156, 197),
                                ),
                              ),
                            ),

                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }

                                final newQty =
                                    int.tryParse(qtyController.text) ??
                                    (row['qty'] ?? 1);
                                final newUnit =
                                    double.tryParse(unitController.text) ??
                                    (row['unit'] ?? 0.0);

                                // 🔥 FIRST update data
                                final table = _tableAt(tableIndex);
                                table[index]['modelNo'] = (currentModelNo ?? '')
                                    .toString();
                                table[index]['modelDesc'] = currentDesc;
                                table[index]['notes'] = currentNotes;
                                table[index]['qty'] = newQty;
                                table[index]['unit'] = newUnit;
                                table[index]['total'] = newQty * newUnit;
                                table[index]['category'] = selectedCategory;
                                table[index]['make'] = selectedMake;

                                // 🔥 THEN rebuild parent safely
                                if (mounted) {
                                  setState(
                                    () {},
                                  ); // 👈 forces quotation page refresh
                                }

                                Navigator.pop(ctx);
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNotesDialog(
    BuildContext context,
    String initialNotes,
    Function(String) onSave,
  ) async {
    final controller = TextEditingController(text: initialNotes);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remarks / Notes'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter notes / remarks here',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // 🟢 Export PDF using common helper (same layout everywhere)
  Future<void> exportToPDF() async {
    final freshProductTables = _cloneAllTables();
    final freshProducts = freshProductTables.expand((table) => table).toList();

    final freshCustomer = selectedCustomer == null
        ? null
        : Map<String, dynamic>.from(selectedCustomer!);

    final pdfBytes = await buildQuotationPdfBytes(
      quotationNumber: quotationNumber,
      customerName: freshCustomer?['name'] ?? '',
      area: freshCustomer?['area'] ?? '',
      products: freshProducts, // ✅ latest
      productTables: freshProductTables,
      tableTotalVisibility: List<bool>.from(tableTotalVisibility),
      totalAmount: totalAmount,
    );

    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  // 🟢 Export Excel with "Save As" dialog that works on Android/iOS
  Future<void> exportToExcel() async {
    // 1️⃣ Create Excel workbook + sheet
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Quotation'];

    // Customer row
    sheet.appendRow([
      excel.TextCellValue('Customer / Building Name'),
      excel.TextCellValue(selectedCustomer?['name'] ?? '-'),
    ]);

    sheet.appendRow([]); // empty row

    for (var tableIndex = 0; tableIndex < productTables.length; tableIndex++) {
      if (productTables.length > 1) {
        sheet.appendRow([excel.TextCellValue('Table ${tableIndex + 1}')]);
      }

      sheet.appendRow([
        excel.TextCellValue('S.No'),
        excel.TextCellValue('Model No'),
        excel.TextCellValue('Description'),
        excel.TextCellValue('Qty'),
        excel.TextCellValue('Unit'),
        excel.TextCellValue('Total'),
      ]);

      for (final r in productTables[tableIndex]) {
        sheet.appendRow([
          excel.IntCellValue(r['serial']),
          excel.TextCellValue(r['modelNo'] ?? ''),
          excel.TextCellValue(r['modelDesc'] ?? ''),
          excel.IntCellValue(r['qty']),
          excel.DoubleCellValue(r['unit']),
          excel.DoubleCellValue(r['total']),
        ]);
      }

      sheet.appendRow([]);
    }

    // Total
    sheet.appendRow([
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue('Total Amount'),
      excel.DoubleCellValue(totalAmount),
    ]);

    // 2️⃣ Encode workbook to bytes
    final bytes = excelFile.encode();
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate Excel file')),
      );
      return;
    }

    // 3️⃣ Ask user where to save, and pass bytes (required on Android/iOS)
    final String defaultFileName = 'Quotation_$quotationNumber.xlsx';

    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select location to save Excel file',
        fileName: defaultFileName,
        bytes: Uint8List.fromList(bytes), // ⭐ important for Android/iOS
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (!mounted) return;

      // User pressed "Cancel"
      if (savedPath == null) {
        return;
      }

      // Plugin already wrote the file. Just show success.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel saved: $savedPath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
    }
  }

  void openPrintPreview() {
    // 🔥 Create a deep copy of latest data
    final freshProductTables = _cloneAllTables();
    final freshProducts = freshProductTables.expand((table) => table).toList();

    final freshCustomer = selectedCustomer == null
        ? null
        : Map<String, dynamic>.from(selectedCustomer!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationPreviewPage(
          quotationNumber: quotationNumber,
          products: freshProducts, // ✅ latest
          productTables: freshProductTables,
          tableTotalVisibility: List<bool>.from(tableTotalVisibility),
          totalAmount: totalAmount,
          selectedCustomer: freshCustomer, // ✅ latest
        ),
      ),
    );
  }

  //added dispose
  @override
  void dispose() {
    customerController.dispose();
    quotationNumberController.dispose(); // <-- important
    customerSearchCtrl.dispose(); // 🔹 CLEANUP

    super.dispose();
  }

  PopupMenuItem<String> _quotationMenuItem(
    String value,
    IconData icon,
    String label,
  ) => PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );

  Future<void> _onQuotationMenuSelected(String value) async {
    switch (value) {
      case 'preview':
        openPrintPreview();
        break;
      case 'pdf':
        exportToPDF();
        break;
      case 'excel':
        exportToExcel();
        break;
      case 'products':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductListPage()),
        );
        if (!mounted) return;
        await loadProductList();
        if (!mounted) return;
        setState(() {});
        break;
      case 'columns':
        _showColumnSettingsDialog();
        break;
      case 'body':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrintBodySettingsPage()),
        );
        break;
      case 'setup':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PageSetupPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('quotations')) return const AccessDenied();
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    //final modelNumbers = ProductCatalog.modelNumbers();
    // final productList = ProductCatalog.getAllProducts();

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Quotations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Saved quotations',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedQuotationsPage()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Quotation menu',
            icon: const Icon(Icons.more_vert),
            position: PopupMenuPosition.under,
            constraints: const BoxConstraints(minWidth: 250),
            onSelected: _onQuotationMenuSelected,
            itemBuilder: (context) => [
              _quotationMenuItem(
                'preview',
                Icons.print_outlined,
                'Print preview',
              ),
              _quotationMenuItem(
                'pdf',
                Icons.picture_as_pdf_outlined,
                'Export PDF',
              ),
              _quotationMenuItem(
                'excel',
                Icons.grid_on_outlined,
                'Export Excel',
              ),
              const PopupMenuDivider(),
              _quotationMenuItem(
                'products',
                Icons.inventory_2_outlined,
                'Manage products',
              ),
              const PopupMenuDivider(),
              _quotationMenuItem(
                'columns',
                Icons.view_column_outlined,
                'Column settings',
              ),
              _quotationMenuItem(
                'body',
                Icons.article_outlined,
                'Print page body',
              ),
              _quotationMenuItem('setup', Icons.tune, 'Page setup'),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      // ✅ Your existing body remains same
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Customer dropdown // below code new added
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: openCustomerSearchDialog, // 🔥 OPEN SEARCH
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Customer / Building Name',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          controller: TextEditingController(
                            text: selectedCustomer?['name'] ?? '',
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8), // space between dropdown & button
                  ElevatedButton.icon(
                    onPressed: () async {
                      //final BuildContext safeContext = context;

                      final newCustomer = await Navigator.push(
                        context, // ✅ use State.context directly
                        MaterialPageRoute(
                          builder: (_) => const CustomersPage(),
                        ),
                      );

                      if (!mounted) return;

                      if (!mounted) return;

                      // ✅ Update UI FIRST
                      if (newCustomer != null &&
                          newCustomer is Map<String, dynamic>) {
                        setState(() {
                          customerList.add({
                            'name': newCustomer['customerName'] ?? '',
                            'email': newCustomer['email'] ?? '',
                            'phone': newCustomer['phone'] ?? '',
                            'address': newCustomer['address'] ?? '',
                            'area': newCustomer['area'] ?? '',
                            'state': newCustomer['state'] ?? '',
                          });

                          selectedCustomer = {
                            'name': newCustomer['customerName'] ?? '',
                            'email': newCustomer['email'] ?? '',
                            'phone': newCustomer['phone'] ?? '',
                            'address': newCustomer['address'] ?? '',
                            'area': newCustomer['area'] ?? '',
                            'state': newCustomer['state'] ?? '',
                          };
                        });
                      }

                      await loadCustomers();

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Customer list updated')),
                      );
                    },

                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Put this above the header row, e.g. after date row:
            //TextFormField(
            //controller: customerController,
            //decoration: const InputDecoration(
            //labelText: 'Customer / Building Name',
            //border: OutlineInputBorder(),
            //isDense: true,
            //contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            //),
            //),
            //const SizedBox(height: 12),

            // Quotation number + date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Editable Quotation Number
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: quotationNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quotation No',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                    ),
                    // simple validation: only numbers
                    onChanged: (val) {
                      // keep quotationNumber in sync when user types a valid int
                      final parsed = int.tryParse(val);
                      if (parsed != null) {
                        quotationNumber = parsed;
                      }
                    },
                  ),
                ),

                // Date (unchanged)
                Text('Date: $date', style: const TextStyle(color: Colors.grey)),
              ],
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: productTables.length,
                itemBuilder: (context, tableIndex) {
                  final table = productTables[tableIndex];
                  final tableTotal = table.fold<double>(
                    0.0,
                    (sum, row) =>
                        sum + ((row['total'] ?? 0.0) as num).toDouble(),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Table ${tableIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Add Total',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Switch(
                                    value: tableTotalVisibility[tableIndex],
                                    onChanged: (value) {
                                      setState(() {
                                        tableTotalVisibility[tableIndex] =
                                            value;
                                      });
                                    },
                                  ),
                                  if (productTables.length > 1)
                                    IconButton(
                                      tooltip: 'Delete table',
                                      onPressed: () => confirmDeleteTable(
                                        context,
                                        tableIndex,
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 6,
                            ),
                            color: Colors.grey[200],
                            child: Row(
                              children: [
                                const Expanded(
                                  flex: 1,
                                  child: Center(child: Text('S.No')),
                                ),
                                if (showModelNo)
                                  const Expanded(
                                    flex: 3,
                                    child: Center(child: Text('Model No')),
                                  ),
                                const Expanded(
                                  flex: 4,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('Description'),
                                  ),
                                ),
                                if (showQty)
                                  const Expanded(
                                    flex: 2,
                                    child: Center(child: Text('Qty')),
                                  ),
                                if (showUnit)
                                  const Expanded(
                                    flex: 2,
                                    child: Center(child: Text('Unit')),
                                  ),
                                if (showAmount)
                                  const Expanded(
                                    flex: 2,
                                    child: Center(child: Text('Amount')),
                                  ),
                                const SizedBox(width: 42),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (table.isEmpty)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('No products yet.'),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => addProductRow(tableIndex),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Product'),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: table.length,
                              itemBuilder: (context, index) {
                                final row = table[index];
                                final String modelNoVal =
                                    (row['modelNo'] as String?) ?? '';
                                final String modelDescVal =
                                    (row['modelDesc'] as String?) ?? '';
                                final String qtyVal = (row['qty'] ?? '')
                                    .toString();
                                final String unitVal = (row['unit'] ?? '')
                                    .toString();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text('${row['serial']}'),
                                        ),
                                      ),
                                      if (showModelNo)
                                        Expanded(
                                          flex: 3,
                                          child: InkWell(
                                            onTap: () => showEditProductDialog(
                                              tableIndex,
                                              index,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  modelNoVal.isNotEmpty
                                                      ? modelNoVal
                                                      : '(No model)',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        flex: 4,
                                        child: InkWell(
                                          onTap: () => showEditProductDialog(
                                            tableIndex,
                                            index,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                modelDescVal.isNotEmpty
                                                    ? modelDescVal
                                                    : '(No description)',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (showQty) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: InkWell(
                                            onTap: () => showEditProductDialog(
                                              tableIndex,
                                              index,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                color: Colors.grey.shade50,
                                              ),
                                              child: Center(
                                                child: Text(qtyVal),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (showUnit) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: InkWell(
                                            onTap: () => showEditProductDialog(
                                              tableIndex,
                                              index,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                color: Colors.grey.shade50,
                                              ),
                                              child: Center(
                                                child: Text(unitVal),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (showAmount) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Text(
                                              'Rs.${((row['total'] ?? 0.0) as num).toDouble().toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Delete row',
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Color.fromARGB(
                                              104,
                                              244,
                                              54,
                                              54,
                                            ),
                                          ),
                                          onPressed: () => confirmDeleteRow(
                                            context,
                                            tableIndex,
                                            index,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => addProductRow(tableIndex),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Product Row'),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tableTotalVisibility[tableIndex]
                                    ? 'Table Total: Rs.${tableTotal.toStringAsFixed(2)}'
                                    : 'Table Total: Rs.${tableTotal.toStringAsFixed(2)} (Not added)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: addProductTable,
                  icon: const Icon(Icons.table_rows),
                  label: const Text('Add Table'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: openProductListPage,
                  icon: const Icon(Icons.list),
                  label: const Text('Product List'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showAmount)
                  Text(
                    'Total: ?${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: addQuotation,
                      child: Text(
                        widget.quotationToEdit == null
                            ? 'Add Quotation' // when creating new
                            : 'Update Quotation', // when editing existing
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DashboardPage(toggleTheme: () {}),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
