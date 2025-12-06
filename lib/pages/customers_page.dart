// lib/pages/customers_page.dart
import 'dart:convert';
import 'dart:io';                         // 👈 NEW
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as excel;        // 👈 NEW
import 'package:file_picker/file_picker.dart';     // 👈 NEW


// import your dashboard page at top:
import '../pages/dashboard_page.dart'; // or correct relative path
import 'dart:typed_data'; // 👈 NEW for Uint8List (Excel export)


class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}


// =======================================
// 📄 View Customers Page (with search)
// =======================================
class CustomersListViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> customers;

  const CustomersListViewPage({super.key, required this.customers});

  @override
  State<CustomersListViewPage> createState() => _CustomersListViewPageState();
}

class _CustomersListViewPageState extends State<CustomersListViewPage> {
  final TextEditingController _searchController = TextEditingController();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    // Start with full list
    _filtered = List<Map<String, dynamic>>.from(widget.customers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter(String query) {
    final q = query.toLowerCase().trim();

    if (q.isEmpty) {
      setState(() {
        _filtered = List<Map<String, dynamic>>.from(widget.customers);
      });
      return;
    }

    setState(() {
      _filtered = widget.customers.where((c) {
        final name = (c['customerName'] ?? '').toString().toLowerCase();
        final area = (c['area'] ?? '').toString().toLowerCase();
        return name.contains(q) || area.contains(q); // 🔍 search by name or area
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer List')),
      body: Column(
        children: [
          // 🔍 Search box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Customer or Area',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter('');
                        },
                      ),
              ),
              onChanged: _applyFilter,
            ),
          ),

          // 📋 Filtered list
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('No customers found'))
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final c = _filtered[index];
                      final sNo = index + 1; // auto numbering in view page

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('$sNo'),
                        ),
                        title: Text(c['customerName'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((c['partyName'] ?? '').toString().isNotEmpty)
                              Text('Party: ${c['partyName']}'),
                            if ((c['area'] ?? '').toString().isNotEmpty)
                              Text('Area: ${c['area']}'),
                            if ((c['phone'] ?? '').toString().isNotEmpty)
                              Text('Phone: ${c['phone']}'),
                            if ((c['email'] ?? '').toString().isNotEmpty)
                              Text('Email: ${c['email']}'),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}




class _CustomersPageState extends State<CustomersPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController partyNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController stateController = TextEditingController();

  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers(); // ✅ load saved customers locally
  }
  

  @override
  void dispose() {
    customerNameController.dispose();
    partyNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    areaController.dispose();
    stateController.dispose();
    super.dispose();
  }

  // Load saved customers from SharedPreferences
  Future<void> _loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('customers') ?? <String>[];

    setState(() {
      _customers = stored.map((s) {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        return {
          'customerName': decoded['customerName'] ?? '',
          'partyName': decoded['partyName'] ?? '',
          'email': decoded['email'] ?? '',
          'address': decoded['address'] ?? '',
          'area': decoded['area'] ?? '',
          'state': decoded['state'] ?? '',
          'phone': decoded['phone'] ?? '',
        };
      }).toList();
    });
  }

  // Save a new customer permanently
  Future<void> _saveCustomer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newCustomer = {
      'customerName': customerNameController.text.trim(),
      'partyName': partyNameController.text.trim(),
      'email': emailController.text.trim(),
      'address': addressController.text.trim(),
      'area': areaController.text.trim(),
      'state': stateController.text.trim(),
      'phone': phoneController.text.trim(),
    };

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('customers') ?? <String>[];

    stored.add(jsonEncode(newCustomer));
    await prefs.setStringList('customers', stored);

    if (!mounted) return;
    // ✅ Return the new customer to the previous page
    Navigator.pop(context, newCustomer);

    // (Optional) show feedback after return
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customer saved successfully')),
    );
  
    // Clear input fields
    customerNameController.clear();
    partyNameController.clear();
    phoneController.clear();
    emailController.clear();
    addressController.clear();
    areaController.clear();
    stateController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customer saved permanently')),
    );
  }

  // Delete a customer
  Future<void> _deleteCustomer(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('customers') ?? <String>[];
    if (index < 0 || index >= stored.length) return;

    stored.removeAt(index);
    await prefs.setStringList('customers', stored);

    if (!mounted) return;
    setState(() {
      _customers.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customer deleted')),
    );
  }

  // Edit existing customer
  Future<void> _editCustomer(int index) async {
    final existing = _customers[index];
    final editCustomerName =
        TextEditingController(text: existing['customerName']);
    final editPartyName = TextEditingController(text: existing['partyName']);
    final editEmail = TextEditingController(text: existing['email']);
    final editAddress = TextEditingController(text: existing['address']);
    final editArea = TextEditingController(text: existing['area']);
    final editState = TextEditingController(text: existing['state']);
    final editPhone = TextEditingController(text: existing['phone']);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Customer'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: editCustomerName,
                  decoration:
                      const InputDecoration(labelText: 'Customer Name'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter name' : null,
                ),
                TextFormField(
                  controller: editPartyName,
                  decoration: const InputDecoration(labelText: 'Party Name'),
                ),
                TextFormField(
                    controller: editEmail,
                    decoration: const InputDecoration(labelText: 'Email')),
                TextFormField(
                    controller: editAddress,
                    decoration: const InputDecoration(labelText: 'Address')),
                TextFormField(
                    controller: editArea,
                    decoration: const InputDecoration(labelText: 'Area')),
                TextFormField(
                    controller: editState,
                    decoration: const InputDecoration(labelText: 'State')),
                TextFormField(
                    controller: editPhone,
                    decoration: const InputDecoration(labelText: 'Phone')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;

              final prefs = await SharedPreferences.getInstance();
              
              final stored = prefs.getStringList('customers') ?? <String>[];

              final updated = {
                'customerName': editCustomerName.text.trim(),
                'partyName': editPartyName.text.trim(),
                'email': editEmail.text.trim(),
                'address': editAddress.text.trim(),
                'area': editArea.text.trim(),
                'state': editState.text.trim(),
                'phone': editPhone.text.trim(),
              };

              stored[index] = jsonEncode(updated);
              await prefs.setStringList('customers', stored);

              if (!mounted) return;
              await _loadCustomers();
              if (!mounted) return;

              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customer updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }





  /// 📥 IMPORT customers from an Excel (.xlsx) file.
  ///
  /// Expected columns:
  /// Customer Name | Party Name | Email | Address | Area | State | Phone
  Future<void> _importCustomersFromExcel() async {
    try {
      // 1) Open file picker to choose an .xlsx file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        // user cancelled
        return;
      }

      final filePath = result.files.single.path!;
      final fileBytes = File(filePath).readAsBytesSync();

      // 2) Decode Excel file
      final excelFile = excel.Excel.decodeBytes(fileBytes);

      if (excelFile.tables.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sheet found in Excel file')),
        );
        return;
      }

      // 3) Read the first sheet
      final firstSheetName = excelFile.tables.keys.first;
      final sheet = excelFile.tables[firstSheetName]!;

      // 4) Option: clear old customers or merge with them
      // If you want to REPLACE all old customers, uncomment:
      // _customers.clear();

      // 5) Go through rows (skip header row = index 0)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        if (row.isEmpty) continue;

        String cellToString(int index) {
          if (index >= row.length || row[index] == null) return '';
          return (row[index]!.value ?? '').toString().trim();
        }

        final customerName = cellToString(0);
        final partyName    = cellToString(1);
        final email        = cellToString(2);
        final address      = cellToString(3);
        final area         = cellToString(4);
        final state        = cellToString(5);
        final phone        = cellToString(6);

        // skip completely empty line
        if (customerName.isEmpty &&
            partyName.isEmpty &&
            email.isEmpty &&
            address.isEmpty &&
            area.isEmpty &&
            state.isEmpty &&
            phone.isEmpty) {
          continue;
        }

        final newCustomer = {
          'customerName': customerName,
          'partyName': partyName,
          'email': email,
          'address': address,
          'area': area,
          'state': state,
          'phone': phone,
        };

        // If you want to avoid duplicates: match by name+phone
        final existingIndex = _customers.indexWhere((c) =>
            c['customerName'] == customerName && c['phone'] == phone);

        if (existingIndex >= 0) {
          _customers[existingIndex] = newCustomer; // update
        } else {
          _customers.add(newCustomer); // add new
        }
      }

      // 6) Save to SharedPreferences (same format as _saveCustomer uses)
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          _customers.map((c) => jsonEncode(c)).toList();
      await prefs.setStringList('customers', encoded);

      if (!mounted) return;
      setState(() {}); // refresh list

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customers imported from Excel successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing customers: $e')),
      );
    }
  }


  /// 📤 EXPORT customers to an Excel file.
  ///
  /// Now asks user for a location (desktop, mobile, etc.) using FilePicker.saveFile.
  Future<void> _exportCustomersToExcel() async {
    try {
      if (_customers.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No customers to export')),
        );
        return;
      }

      // 1) Create Excel file
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Customers']; // sheet name

      // 2) Header row (with S.No)
      sheet.appendRow([
        excel.TextCellValue('S.No'),
        excel.TextCellValue('Customer Name'),
        excel.TextCellValue('Party Name'),
        excel.TextCellValue('Email'),
        excel.TextCellValue('Address'),
        excel.TextCellValue('Area'),
        excel.TextCellValue('State'),
        excel.TextCellValue('Phone'),
      ]);

      // 3) Data rows with auto numbering
      for (int i = 0; i < _customers.length; i++) {
        final c = _customers[i];
        final sNo = i + 1;

        sheet.appendRow([
          excel.IntCellValue(sNo),
          excel.TextCellValue((c['customerName'] ?? '').toString()),
          excel.TextCellValue((c['partyName'] ?? '').toString()),
          excel.TextCellValue((c['email'] ?? '').toString()),
          excel.TextCellValue((c['address'] ?? '').toString()),
          excel.TextCellValue((c['area'] ?? '').toString()),
          excel.TextCellValue((c['state'] ?? '').toString()),
          excel.TextCellValue((c['phone'] ?? '').toString()),
        ]);
      }

      // 4) Encode to bytes
      final bytes = excelFile.encode();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to encode Excel file')),
        );
        return;
      }

      // 5) Ask user where to save the file
      const defaultFileName = 'customers_list.xlsx';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select location to save customers Excel file',
        fileName: defaultFileName,
        bytes: Uint8List.fromList(bytes), // ⭐ REQUIRED for Android/iOS
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (!mounted) return;

      // User canceled dialog
      if (savePath == null) {
        return;
      }

      // FilePicker already saved the file to savePath.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customers exported to: $savePath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting customers: $e')),
      );
    }
  }







  // Build UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [

      // 🔴 CLOSE BUTTON (returns to quotation page)
            Align(
  alignment: Alignment.centerRight,
  child: ElevatedButton.icon(
    onPressed: () {
      // If there is a previous route on the Navigator stack -> just pop (return to caller).
      // If not (this page was opened as the root), replace with DashboardPage.
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context); // return to caller
      } else {
         // opened directly -> send user to Dashboard (replace route)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(toggleTheme: () {}), // provide toggleTheme as required by your Dashboard
          ),
        );
      }
    },
    icon: const Icon(Icons.close),
    label: const Text("Close"),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
  ),
),

      const SizedBox(height: 12), 

     // 🔹 Import / Export buttons
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _importCustomersFromExcel,
              icon: const Icon(Icons.file_upload),
              label: const Text('Import from Excel'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exportCustomersToExcel,
              icon: const Icon(Icons.file_download),
              label: const Text('Export to Excel'),
            ),
          ),
        ],
      ),

      const SizedBox(height: 12),

      // 👁 View Customers button -> opens separate page with search
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomersListViewPage(
                  customers: List<Map<String, dynamic>>.from(_customers),
                ),
              ),
            );
          },
          icon: const Icon(Icons.visibility),
          label: const Text('View Customers'),
        ),
      ),

      const SizedBox(height: 12),


            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: customerNameController,
                    decoration:
                        const InputDecoration(labelText: 'Customer Name'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter name' : null,
                  ),
                  TextFormField(
                    controller: partyNameController,
                    decoration:
                        const InputDecoration(labelText: 'Party Name'),
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  TextFormField(
                    controller: areaController,
                    decoration: const InputDecoration(labelText: 'Area'),
                  ),
                  TextFormField(
                    controller: stateController,
                    decoration: const InputDecoration(labelText: 'State'),
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveCustomer,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Customer'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          customerNameController.clear();
                          partyNameController.clear();
                          emailController.clear();
                          addressController.clear();
                          areaController.clear();
                          stateController.clear();
                          phoneController.clear();
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _customers.isEmpty
                  ? const Center(
                      child:
                          Text('No customers yet. Add new customer above.'),
                    )
                  : ListView.separated(
                      itemCount: _customers.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final c = _customers[index];
                        return ListTile(
  leading: CircleAvatar(
    child: Text('${index + 1}'),   // 👈 auto S.No
  ),
  title: Text(c['customerName'] ?? ''),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Party: ${c['partyName']}'),
      Text('Email: ${c['email']}'),
      Text('Phone: ${c['phone']}'),
      Text('Address: ${c['address']}'),
      Text('Area: ${c['area']}'),
      Text('State: ${c['state']}'),
    ],
  ),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editCustomer(index),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCustomer(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
