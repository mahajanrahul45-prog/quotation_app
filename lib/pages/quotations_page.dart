// lib/pages/quotations_page.dart
//import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel;
//import 'package:path_provider/path_provider.dart';
import '../data/product_catalog.dart';
import 'product_list_page.dart';
import 'quotation_preview_page.dart'; // ✅ new preview page import

import 'dashboard_page.dart'; // added for return home page
//import '../data/customers_data.dart';
import 'customers_page.dart';
import '../models/quotation.dart';
import '../storage/quotation_storage.dart';
import 'saved_quotations_page.dart'; // ✅ new page
import 'page_setup_page.dart'; // ✅ for logo/watermark setup
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:convert';
import 'dart:typed_data';// added new for export pdf editing <-- ⭐ REQUIRED for Uint8List
import 'package:file_picker/file_picker.dart';


import '../utils/quotation_pdf_helper.dart'; // adjust path if needed







class QuotationsPage extends StatefulWidget {
  final Quotation? quotationToEdit; // ✅ for edit mode
  const QuotationsPage({super.key, this.quotationToEdit});
  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}


class _QuotationsPageState extends State<QuotationsPage> {
  
  int quotationNumber = 1;
  final List<Map<String, dynamic>> productRows = [];
  final TextEditingController customerController = TextEditingController();//added new
  // Controller so user can edit number manually
final TextEditingController quotationNumberController = TextEditingController();
    Map<String, dynamic>? selectedCustomer; // ✅ instead of String?
    // 🧱 Holds product list loaded from SharedPreferences
    List<Map<String, dynamic>> productList = [];
    List<Map<String, dynamic>> customerList = [];


  @override
void initState() {
  super.initState();

  // 1️⃣ load product models saved in SharedPreferences
  loadProductList();

  loadCustomers(); // ✅ Load saved customers for dropdown

    // Compute next number asynchronously (doesn't block UI)
  _initQuotationNumber();

// 2️⃣ if we came here to edit an existing quotation, pre-fill everything
  if (widget.quotationToEdit != null) {
    final q = widget.quotationToEdit!; // fill controller with the existing quotation number (edit mode)
    quotationNumber = q.quotationNumber;
    quotationNumberController.text = q.quotationNumber.toString(); // added new

    selectedCustomer = {'name': q.customerName};
    productRows.addAll(q.products);
  }
   
}

  // Helper: load saved quotations and set next available number
// Helper: load saved quotations and set next available number
Future<void> _initQuotationNumber() async {
  try {
    final list = await QuotationStorage.loadQuotations(); // returns List<Quotation>
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
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList('models') ?? <String>[];
  final loaded =
      stored.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

  setState(() {
    productList = loaded;
  });

  
}





// Load customers from SharedPreferences

Future<void> loadCustomers() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList('customers') ?? <String>[];

  setState(() {
    customerList = stored.map((s) {
      final decoded = jsonDecode(s) as Map<String, dynamic>;
      return {
        'name': decoded['customerName'] ?? '',
        'email': decoded['email'] ?? '',
        'phone': decoded['phone'] ?? '',
        'address': decoded['address'] ?? '',
        'area': decoded['area'] ?? '',
        'state': decoded['state'] ?? '',
      };
    }).toList();
  });
}

  double get totalAmount =>
      productRows.fold(0.0, (sum, r) => sum + (r['total'] ?? 0.0));

  void addProductRow() {
    setState(() {
      productRows.add({
        'serial': productRows.length + 1,
        'modelNo': null,
        'modelDesc': null,
        'qty': 1,
        'unit': 0.0,
        'total': 0.0,
      });
    });
  }

  void updateRow(int index, String field, dynamic value) {
    setState(() {
      productRows[index][field] = value;
      if (field == 'modelNo') {
  final match = productList.firstWhere((m) => m['no'] == value, orElse: () => {'desc': ''});
  productRows[index]['modelDesc'] = match['desc'];
} else if (field == 'modelDesc') {
  final match = productList.firstWhere((m) => m['desc'] == value, orElse: () => {'no': ''});
  productRows[index]['modelNo'] = match['no'];
}


      final qty = (productRows[index]['qty'] ?? 0).toDouble();
      final unit = (productRows[index]['unit'] ?? 0.0).toDouble();
      productRows[index]['total'] = qty * unit;
    });
  }

/// Remove product row at [index] and re-number serials.
void removeProductRow(int index) {
  if (index < 0 || index >= productRows.length) return;
  setState(() {
    productRows.removeAt(index);
    for (var i = 0; i < productRows.length; i++) {
      productRows[i]['serial'] = i + 1;
    }
  });
}

/// Ask user to confirm row deletion.
Future<void> confirmDeleteRow(BuildContext context, int index) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete product'),
      content: const Text('Are you sure you want to delete this product row?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );

  if (confirmed == true) {
    removeProductRow(index);
  }
}





  Future<void> addQuotation() async {
  // 1) Get customer name: prefer selectedCustomer dropdown, otherwise typed name
  final customerName = selectedCustomer?['name'] ?? '';

  // 2) Validate - require a customer name
  if (customerName.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter or select a customer name')),
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
  final savedList = await QuotationStorage.loadQuotations(); // List<Quotation>

  // ✅ Add this line to satisfy the analyzer:
  if (!mounted) return;
  final existsIndex = savedList.indexWhere((q) => q.quotationNumber == chosenNumber);

  // 5) If not in edit mode and number already exists, choose behavior:
  //    - For beginner-friendly approach: show confirmation dialog: overwrite existing or auto-increment
  if (widget.quotationToEdit == null && existsIndex >= 0) {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quotation number exists'),
        content: Text('Quotation number $chosenNumber already exists. What do you want to do?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'increment'), child: const Text('Use next number')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), child: const Text('Overwrite')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
        ],
      ),
    );

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

  // 6) Build a clean copy of product rows to save (avoid holding UI controllers) //Build products list to store
  final productsToStore = productRows.map((r) {
    return {
      'serial': r['serial'],
      'modelNo': r['modelNo'] ?? '',
      'modelDesc': r['modelDesc'] ?? '',
      'qty': r['qty'] ?? 0,
      'unit': (r['unit'] ?? 0.0).toDouble(),
      'total': (r['total'] ?? 0.0).toDouble(),
    };
  }).toList();

  // 7) Create Quotation model instance (you imported ../models/quotation.dart)
  final quotation = Quotation(
   // quotationNumber: quotationNumber,
   quotationNumber: chosenNumber,   // ✅ use the number from the field
    customerName: customerName,
    date: DateTime.now(),
    products: productsToStore,
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
      productRows.clear();
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
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Quotation saved successfully')));
}

  Future<void> openProductListPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductListPage()),
    );
    setState(() {});// important: rebuild to pick up new products
  }

  Future<void> showAddModelDialog() async {
    final noController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Model'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: noController,
              decoration: const InputDecoration(labelText: 'Model No.'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter model no' : null,
            ),
            TextFormField(
              controller: descController,
              decoration:
                  const InputDecoration(labelText: 'Model Description'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter description' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                ProductCatalog.addOrUpdateModel(
                    noController.text, descController.text);
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Model "${noController.text}" added')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }



//// Shows a wide dialog for editing a product row (model no / desc / qty / unit).
/// 🔹 Now includes a 2nd popup for LP & Discount to auto-calc Unit Price.
Future<void> showEditProductDialog(int index) async {
  final row = productRows[index];

  // Controllers (prefill from existing row)
  String? currentModelNo = (row['modelNo'] as String?)?.trim();
  String currentDesc = (row['modelDesc'] as String?) ?? '';
  final qtyController =
      TextEditingController(text: (row['qty'] ?? 1).toString());
  final unitController =
      TextEditingController(text: (row['unit'] ?? 0.0).toString());

  final formKey = GlobalKey<FormState>();

  // Build lists for dropdowns
  final modelNumbers = productList
      .map((m) => (m['no'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toList();
  final descriptions = productList
      .map((m) => (m['desc'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StatefulBuilder(
              builder: (contextSB, setStateSB) {
                // 🔹 NEW: function to open LP & Discount popup
                Future<void> openLpDiscountDialog() async {
                  final lpController = TextEditingController();
                  final discController = TextEditingController();
                  final lpFormKey = GlobalKey<FormState>();

                  await showDialog<void>(
                    context: contextSB,
                    builder: (ctx2) {
                      return AlertDialog(
                        title: const Text('List Price & Discount'),
                        content: Form(
                          key: lpFormKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: lpController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'List Price (LP)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter list price';
                                  }
                                  if (double.tryParse(v) == null) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: discController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Discount (%)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter discount %';
                                  }
                                  if (double.tryParse(v) == null) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
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
                              if (!(lpFormKey.currentState?.validate() ??
                                  false)) {return;}

                              final lp =
                                  double.tryParse(lpController.text) ?? 0.0;
                              final disc =
                                  double.tryParse(discController.text) ?? 0.0;

                              // 🧮 Unit Price = LP − (LP * disc / 100)
                              final unit = lp - (lp * disc / 100.0);

                              // 🔹 Fill the Unit Price field automatically
                              unitController.text =
                                  unit.toStringAsFixed(2);

                              // You can still manually change Unit price later in main dialog
                              Navigator.pop(ctx2);
                            },
                            child: const Text('Apply'),
                          ),
                        ],
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
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // Row: Model No + Description
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Model No dropdown
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  (currentModelNo?.isNotEmpty == true)
                                      ? currentModelNo
                                      : null,
                              decoration: const InputDecoration(
                                labelText: 'Model No',
                                border: OutlineInputBorder(),
                              ),
                              items: modelNumbers
                                  .map((no) => DropdownMenuItem(
                                      value: no, child: Text(no)))
                                  .toList(),
                              onChanged: (val) {
                                currentModelNo = val;
                                final match = productList.firstWhere(
                                  (m) => (m['no'] ?? '') == val,
                                  orElse: () =>
                                      {'desc': '', 'no': ''},
                                );
                                final newDesc =
                                    (match['desc'] ?? '') as String;
                                currentDesc = newDesc;
                                setStateSB(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Description — Autocomplete (editable)
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text('Description',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 6),
                                Autocomplete<String>(
                                  optionsBuilder:
                                      (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text == '') {
                                      return descriptions;
                                    }
                                    return descriptions.where((d) => d
                                        .toLowerCase()
                                        .contains(textEditingValue.text
                                            .toLowerCase()));
                                  },
                                  initialValue:
                                      TextEditingValue(text: currentDesc),
                                  onSelected: (selection) {
                                    currentDesc = selection;
                                    final match = productList.firstWhere(
                                      (m) =>
                                          (m['desc'] ?? '') == selection,
                                      orElse: () =>
                                          {'no': '', 'desc': ''},
                                    );
                                    final matchedNo =
                                        (match['no'] ?? '') as String;
                                    if (matchedNo.isNotEmpty) {
                                      currentModelNo = matchedNo;
                                    } else {
                                      currentModelNo = null;
                                    }
                                    setStateSB(() {});
                                  },
                                  fieldViewBuilder: (contextField,
                                      controller,
                                      focusNode,
                                      onEditingComplete) {
                                    controller.text = currentDesc;
                                    controller.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset:
                                              controller.text.length),
                                    );
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (v) {
                                        currentDesc = v;
                                        final match =
                                            productList.firstWhere(
                                          (m) => (m['desc'] ?? '')
                                              .toString()
                                              .toLowerCase() ==
                                              v.toLowerCase(),
                                          orElse: () =>
                                              {'no': '', 'desc': ''},
                                        );
                                        final matchedNo =
                                            (match['no'] ?? '') as String;
                                        if (matchedNo.isNotEmpty) {
                                          currentModelNo = matchedNo;
                                        } else {
                                          currentModelNo = null;
                                        }
                                        setStateSB(() {});
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Row: Qty + Unit (with LP/Discount button)
                      Row(
                        children: [
                          // Qty
                          Expanded(
                            child: TextFormField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter qty';
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
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: unitController,
                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                                decimal: true),
                                    decoration:
                                        const InputDecoration(
                                      labelText: 'Unit Price',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) {
                                      if (v == null ||
                                          v.trim().isEmpty) {
                                        return 'Enter unit';
                                      }
                                      if (double.tryParse(v) ==
                                          null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // 🔹 NEW: Button to open LP/Discount popup
                                IconButton(
                                  tooltip:
                                      'Set by LP & Discount',
                                  icon: const Icon(Icons.calculate),
                                  onPressed: openLpDiscountDialog,
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
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {return;}

                              final newQty =
                                  int.tryParse(qtyController.text) ??
                                      (row['qty'] ?? 1);
                              final newUnit = double.tryParse(
                                      unitController.text) ??
                                  (row['unit'] ?? 0.0);

                              // Apply changes to productRows
                              setState(() {
                                productRows[index]['modelNo'] =
                                    (currentModelNo ?? '')
                                        .toString();
                                productRows[index]['modelDesc'] =
                                    currentDesc;
                                productRows[index]['qty'] = newQty;
                                productRows[index]['unit'] = newUnit;
                                productRows[index]['total'] =
                                    (newQty * newUnit);
                              });

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









// 🟢 Export PDF using common helper (same layout everywhere)
Future<void> exportToPDF() async {
  final String customerName = selectedCustomer?['name'] ?? '';

  final pdfBytes = await buildQuotationPdfBytes(
    quotationNumber: quotationNumber,
    customerName: customerName,
    products: productRows,
    totalAmount: totalAmount,
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdfBytes,
  );
}





  

  // 🟢 Export Excel with "Save As" dialog that works on Android/iOS
Future<void> exportToExcel() async {
  // 1️⃣ Create Excel workbook + sheet
  final excelFile = excel.Excel.createExcel();
  final sheet = excelFile['Quotation'];

  // Customer row
  sheet.appendRow([
    excel.TextCellValue('Customer'),
    excel.TextCellValue(selectedCustomer?['name'] ?? '-'),
  ]);

  sheet.appendRow([]); // empty row

  // Header row
  sheet.appendRow([
    excel.TextCellValue('S.No'),
    excel.TextCellValue('Model No'),
    excel.TextCellValue('Description'),
    excel.TextCellValue('Qty'),
    excel.TextCellValue('Unit'),
    excel.TextCellValue('Total'),
  ]);

  // Data rows
  for (var r in productRows) {
    sheet.appendRow([
      excel.IntCellValue(r['serial']),
      excel.TextCellValue(r['modelNo'] ?? ''),
      excel.TextCellValue(r['modelDesc'] ?? ''),
      excel.IntCellValue(r['qty']),
      excel.DoubleCellValue(r['unit']),
      excel.DoubleCellValue(r['total']),
    ]);
  }

  // Empty row
  sheet.appendRow([]);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel saved: $savedPath')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving file: $e')),
    );
  }
}




  // 🟢 Print Preview Page
  void openPrintPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationPreviewPage(
          quotationNumber: quotationNumber,
          products: productRows,
          totalAmount: totalAmount,
          selectedCustomer: selectedCustomer, // ✅ pass selected customer here
        ),
      ),
    );
  }

  //added dispose 
 @override
  void dispose() {
    customerController.dispose();
    quotationNumberController.dispose(); // <-- important
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    //final modelNumbers = ProductCatalog.modelNumbers();
   // final productList = ProductCatalog.getAllProducts();


    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations'),
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: exportToPDF),
          IconButton(
              icon: const Icon(Icons.grid_on),
              tooltip: 'Export Excel',
              onPressed: exportToExcel),
          IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print Preview',
              onPressed: openPrintPreview),
          IconButton(
              icon: const Icon(Icons.add_box),
              tooltip: 'Add Model',
              onPressed: showAddModelDialog),
          IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Product List',
              onPressed: openProductListPage),
          IconButton(
  icon: const Icon(Icons.history),
  tooltip: 'Saved Quotations',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedQuotationsPage()),
    );
  },
),
IconButton(
  icon: const Icon(Icons.settings),
  tooltip: 'Page Setup',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PageSetupPage()),
    );
  },
),

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
        child: DropdownButtonFormField<Map<String, dynamic>>(
          initialValue: selectedCustomer,
          decoration: const InputDecoration(
            labelText: 'Select Customer',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              selectedCustomer = value;
            });
          },
          items: customerList.map((customer) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: customer,
              child: Text(customer['name']),
            );
          }).toList(),
        ),
      ),
      const SizedBox(width: 8), // space between dropdown & button
      ElevatedButton.icon(
        onPressed: () async {
          final newCustomer = await Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const CustomersPage()),
);

await loadCustomers(); // Refresh list when returning

if (newCustomer != null && newCustomer is Map<String, dynamic>) {
  setState(() {
    // Add a proper map (not just a string)
    customerList.add({
      'name': newCustomer['customerName'] ?? '',
      'email': newCustomer['email'] ?? '',
      'phone': newCustomer['phone'] ?? '',
      'address': newCustomer['address'] ?? '',
      'area': newCustomer['area'] ?? '',
      'state': newCustomer['state'] ?? '',
    });

    // Select the newly added customer immediately
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

        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
      ),
    ],
  ),
),

// Put this above the header row, e.g. after date row:
//TextFormField(
  //controller: customerController,
  //decoration: const InputDecoration(
    //labelText: 'Customer Name',
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
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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

          // Header row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            color: Colors.grey[200],
            child: Row(children: const [
              Expanded(flex: 1, child: Text('S.No')),
              Expanded(flex: 3, child: Text('Model No')),
              Expanded(flex: 4, child: Text('Model Description')),
              Expanded(flex: 2, child: Text('Qty')),
              Expanded(flex: 2, child: Text('Unit')),
              Expanded(flex: 2, child: Text('Total')),
            ]),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: productRows.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('No products yet.'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(onPressed: addProductRow, icon: const Icon(Icons.add), label: const Text('Add Product')),
                    ]),
                  )
                : ListView.builder(
                    itemCount: productRows.length,
                    itemBuilder: (context, index) {
                      final row = productRows[index];
                      // Safe locals so we don't access nullable values directly in widget tree
                      final String modelNoVal = (row['modelNo'] as String?) ?? '';
                      final String modelDescVal = (row['modelDesc'] as String?) ?? '';
                      final String qtyVal = (row['qty'] ?? '').toString();
                      final String unitVal = (row['unit'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(flex: 1, child: Text('${row['serial']}')),
                          // inside itemBuilder, you already have: final row = productRows[index];
// ✅ Model No Dropdown
// Make the row tappable to open the wide popup editor
Expanded(
  flex: 3, // for the display area (model no + desc), occupy same layout space
  child: InkWell(
    onTap: () => showEditProductDialog(index),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // first line: model no (bold)
          Text(
            modelNoVal.isNotEmpty ? modelNoVal : '(No model)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          // second line: model description
          Text(
            modelDescVal,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    ),
  ),
),

// Qty (tap opens same dialog)
const SizedBox(width: 8),
Expanded(
  flex: 2,
  child: InkWell(
    onTap: () => showEditProductDialog(index),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey.shade50,
      ),
      child: Text(qtyVal),
    ),
  ),
),
const SizedBox(width: 8),

// Unit
Expanded(
  flex: 2,
  child: InkWell(
    onTap: () => showEditProductDialog(index),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey.shade50,
      ),
      child: Text(unitVal),
    ),
  ),
),

// Total value
const SizedBox(width: 8),
Expanded(
  flex: 2,
  child: Text('₹${(row['total'] ?? 0.0).toStringAsFixed(2)}'),
),

// small gap before delete icon
const SizedBox(width: 6),

// Delete button — placed inside the itemBuilder so `index` is available
SizedBox(
  width: 36, // keep it compact
  height: 36,
  child: IconButton(
    padding: EdgeInsets.zero,
    tooltip: 'Delete row',
    icon: const Icon(Icons.delete, color: Colors.red),
    onPressed: () => confirmDeleteRow(context, index),
  ),
),

                        ]),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),

          // Buttons row: Add Product Row and Product List (side by side)
          Row(
            children: [
              ElevatedButton.icon(onPressed: addProductRow, icon: const Icon(Icons.add), label: const Text('Add Product Row')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: openProductListPage, icon: const Icon(Icons.list), label: const Text('Product List')),
            ],
          ),

          const SizedBox(height: 12),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total: ₹${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(children: [
              ElevatedButton(
  onPressed: addQuotation,
  child: Text(
    widget.quotationToEdit == null
        ? 'Add Quotation'      // when creating new
        : 'Update Quotation',  // when editing existing
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


            ]),
          ]),
        ]),
      ),
    );
  }
}
