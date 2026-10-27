import '../models/maintenance_lifecycle.dart';
import '../storage/customer_directory.dart';
import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'saved_maintenance_quotations_page.dart'; // create later
import 'dashboard_page.dart';
import 'customers_page.dart';
import '../models/maintenance_quotation.dart';
import '../storage/maintenance_quotation_storage.dart';
//import 'maintenance_page_setup_page.dart';
import 'page_setup_page.dart'; // ✅ COMMON PAGE SETUP
import 'maintenance_preview_page.dart';
import 'maintenance_page_body_page.dart';
import '../utils/maintenance_pdf_helper.dart'; // 🔥 REQUIRED for PDF export
import 'dart:io'; // 🔥 For File
import 'package:file_picker/file_picker.dart'; // 🔥 For FilePicker
import 'package:path/path.dart' as p;

class MaintenanceQuotationPage extends StatefulWidget {
  final MaintenanceQuotation? quotationToEdit;
  final MaintenanceQuotation? quotationToRenew;

  const MaintenanceQuotationPage({
    super.key,
    this.quotationToEdit,
    this.quotationToRenew,
  }) : assert(quotationToEdit == null || quotationToRenew == null);

  @override
  State<MaintenanceQuotationPage> createState() =>
      _MaintenanceQuotationPageState();
}

class _MaintenanceQuotationPageState extends State<MaintenanceQuotationPage> {
  // =====================================================
  // 🔹 TEXT CONTROLLERS (ADD HERE)
  // =====================================================
  late TextEditingController liftQtyCtrl;
  late TextEditingController monthsCtrl;
  late TextEditingController liftAmountCtrl;

  // =====================================================
  // 🔹 STATUS DROPDOWN STATE
  // =====================================================
  late String _selectedStatus; // Active | Pending | Lost

  // 🔹 CUSTOMER SEARCH CONTROLLER (FOR SEARCHABLE DROPDOWN)
  final TextEditingController customerSearchCtrl = TextEditingController();

  late bool isEditMode;
  bool get isRenewal => widget.quotationToRenew != null;
  bool _saving = false;

  // =====================================================
  // 🔹 BASIC STATE
  // =====================================================

  int srNo = 1;

  Map<String, dynamic>? selectedCustomer;

  // 🔹 TEMP STORE CUSTOMER NAME (EDIT MODE FIX)
  String? editingCustomerName;

  // =====================================================
  // 🔹 HELPER — Get selected customer area safely
  // =====================================================
  String get selectedCustomerArea {
    return selectedCustomer?['area'] ?? '';
  }

  List<Map<String, dynamic>> customerList = [];

  DateTime? startDate;
  DateTime? endDate;

  DateTime? offerDate; // 🔹 Offer / Quotation Date

  int liftQty = 1;
  int months = 12;
  double liftAmount = 0;

  // =====================================================
  // 🔹 AUTO CALCULATIONS
  // =====================================================

  double get monthlyAmount => months > 0 ? liftAmount / months : 0;

  double get totalAmount => liftQty * liftAmount;

  // =====================================================
  // 🔹 INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    // 🔹 Default offer date = today
    offerDate = DateTime.now();

    // =====================================================
    // 🔹 INIT TEXT CONTROLLERS
    // =====================================================
    liftQtyCtrl = TextEditingController();
    monthsCtrl = TextEditingController();
    liftAmountCtrl = TextEditingController();

    isEditMode = widget.quotationToEdit != null; // ✅ EDIT OR NEW

    // 🔹 DEFAULT STATUS FOR NEW QUOTATION
    if (!isEditMode) {
      _selectedStatus = 'New';
    }

    // =====================================================
    // 🔹 EDIT MODE — PREFILL DATA
    // =====================================================
    if (widget.quotationToEdit != null || isRenewal) {
      final q =
          widget.quotationToEdit ??
          MaintenanceLifecycle.renewalDraft(widget.quotationToRenew!);

      // 🔹 LOAD STATUS FOR EDIT MODE
      _selectedStatus = q.status;

      offerDate = q.offerDate; // 🔹 load saved offer date

      // ✅ STORE CUSTOMER NAME TEMPORARILY
      editingCustomerName = q.customerName;
      selectedCustomer = {'name': q.customerName, 'area': q.area ?? ''};

      //   // 🔹 Find customer from list later after loadCustomers()
      //  selectedCustomer = {
      //   'name': q.customerName,
      //   'area': q.area,   // ✅ ADD THIS
      // };

      startDate = q.startDate;
      endDate = q.endDate;
      liftQty = q.liftQty;
      months = q.months;
      liftAmount = q.liftAmount;

      // 🔹 keep same srNo while editing
      srNo = q.srNo;

      // ✅ NOW set controller values (AFTER assigning data)
      liftQtyCtrl.text = liftQty.toString();
      monthsCtrl.text = months.toString();
      liftAmountCtrl.text = liftAmount.toString();
    } else {
      // ✅ NEW MODE — set default values
      liftQtyCtrl.text = liftQty.toString();
      monthsCtrl.text = months.toString();
      liftAmountCtrl.text = liftAmount.toString();
    }

    loadCustomers();
  }

  // =====================================================
  // 🔹 LOAD CUSTOMERS
  // =====================================================

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
          };
        }).toList();

        // =====================================================
        // ✅ EDIT MODE: AUTO SELECT SAVED CUSTOMER
        // =====================================================
        if (editingCustomerName != null) {
          final match = customerList.firstWhere(
            (c) => c['name'] == editingCustomerName,
            orElse: () => {},
          );

          if (match.isNotEmpty && !isRenewal) {
            selectedCustomer = match; // ✅ EXACT OBJECT REFERENCE
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load customer directory: $e')),
      );
    }
  }

  // =====================================================
  // 🔹 SEARCHABLE CUSTOMER DIALOG
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
                    // 🔍 SEARCH INPUT
                    TextField(
                      controller: customerSearchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search customer / building name...',
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

  // =====================================================
  // 🔹 SAVE MAINTENANCE QUOTATION
  // =====================================================

  // =====================================================
  // 🔹 SAVE / UPDATE MAINTENANCE QUOTATION
  // =====================================================
  Future<void> saveMaintenanceQuotation() async {
    if (_saving) return;
    String? error;
    if (selectedCustomer == null) {
      error = 'Select a customer / building.';
    } else if (startDate == null || endDate == null) {
      error = 'Select the contract start and end dates.';
    } else if (endDate!.isBefore(startDate!)) {
      error = 'End date must be on or after the start date.';
    } else if (liftQty <= 0 ||
        months <= 0 ||
        liftAmount < 0 ||
        double.tryParse(liftAmountCtrl.text.trim()) == null ||
        !liftAmount.isFinite ||
        !totalAmount.isFinite) {
      error = 'Enter a valid lift quantity, duration and amount.';
    } else if (isRenewal &&
        !MaintenanceLifecycle.day(
          startDate!,
        ).isAfter(MaintenanceLifecycle.day(widget.quotationToRenew!.endDate))) {
      error = 'Renewal must start after the previous contract ends.';
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    try {
      final quotation = MaintenanceQuotation(
        srNo:
            widget.quotationToEdit?.srNo ??
            DateTime.now().microsecondsSinceEpoch,
        offerDate: offerDate ?? DateTime.now(),
        customerName: selectedCustomer!['name'],
        area: selectedCustomer?['area'] ?? '',
        startDate: startDate!,
        endDate: endDate!,
        liftQty: liftQty,
        months: months,
        liftAmount: liftAmount,
        monthlyAmount: monthlyAmount,
        totalAmount: totalAmount,
        status: isRenewal ? 'Active' : _selectedStatus,
        renewedFromSrNo:
            widget.quotationToRenew?.srNo ??
            widget.quotationToEdit?.renewedFromSrNo,
        renewedAt: isRenewal
            ? DateTime.now()
            : widget.quotationToEdit?.renewedAt,
      );
      await MaintenanceQuotationStorage.save(quotation);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRenewal
                ? 'Maintenance renewed. The previous contract is retained in history.'
                : isEditMode
                ? 'Maintenance quotation updated'
                : 'Maintenance quotation saved',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save maintenance: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =====================================================
  // 🔹 EXPORT MAINTENANCE PDF
  // =====================================================
  // =====================================================
  // 🔹 EXPORT MAINTENANCE PDF (ANDROID / IOS SAFE)
  // =====================================================
  Future<void> exportMaintenancePdf() async {
    try {
      if (selectedCustomer == null || startDate == null || endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required data')),
        );
        return;
      }

      // 🔹 Build quotation object
      final quotation = MaintenanceQuotation(
        srNo: srNo,
        offerDate: offerDate ?? DateTime.now(),
        customerName: selectedCustomer!['name'],
        area: selectedCustomer?['area'] ?? '',
        startDate: startDate!,
        endDate: endDate!,
        liftQty: liftQty,
        months: months,
        liftAmount: liftAmount,
        monthlyAmount: monthlyAmount,
        totalAmount: totalAmount,
        status: _selectedStatus,
      );

      // 🔹 Generate PDF bytes
      final bytes = await buildMaintenancePdfBytes(quotation);

      // 🔹 Ask user to choose DIRECTORY (mobile-safe)
      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to save PDF',
      );

      if (dirPath == null) return;

      // 🔹 Build file name
      final fileName =
          'Maintenance_${quotation.srNo}_${quotation.customerName.replaceAll(' ', '_')}.pdf';

      final filePath = p.join(dirPath, fileName);

      // 🔹 Save file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF saved at:\n$filePath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    }
  }

  // =====================================================
  // 🔹 UI
  // =====================================================

  void _openPrintPreview() {
    if (selectedCustomer == null || startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required data')),
      );
      return;
    }

    final quotation = MaintenanceQuotation(
      srNo: srNo,
      offerDate: offerDate ?? DateTime.now(),
      customerName: selectedCustomer!['name'],
      area: selectedCustomerArea, // ✅ ADD THIS LINE
      startDate: startDate!,
      endDate: endDate!,
      liftQty: liftQty,
      months: months,
      liftAmount: liftAmount,
      monthlyAmount: monthlyAmount,
      totalAmount: totalAmount,
      status: _selectedStatus,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenancePreviewPage(quotation: quotation),
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'preview':
        _openPrintPreview();
        break;
      case 'pdf':
        exportMaintenancePdf();
        break;
      case 'body':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MaintenancePageBodyPage()),
        );
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PageSetupPage()),
        );
        break;
      case 'close':
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardPage(toggleTheme: () {}),
            ),
          );
        }
        break;
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('maintenance')) {
      return const AccessDenied();
    }
    final df = DateFormat('dd/MM/yyyy');

    return AppScaffold(
      appBar: AppBar(
        title: Text(
          isRenewal
              ? 'Renew Maintenance'
              : isEditMode
              ? 'Update Maintenance Quotation'
              : 'Maintenance Quotation',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Saved Maintenance Quotations',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SavedMaintenanceQuotationsPage(),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Maintenance menu',
            position: PopupMenuPosition.under,
            onSelected: _onMenuSelected,
            itemBuilder: (_) => [
              _menuItem('preview', Icons.print_outlined, 'Print preview'),
              _menuItem('pdf', Icons.picture_as_pdf_outlined, 'Export PDF'),
              const PopupMenuDivider(),
              _menuItem('body', Icons.article_outlined, 'Print page body'),
              _menuItem('settings', Icons.tune, 'Page setup'),
              const PopupMenuDivider(),
              _menuItem('close', Icons.close, 'Close'),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            if (isRenewal)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Renew contract #${widget.quotationToRenew!.srNo}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Previous contract ends ${df.format(widget.quotationToRenew!.endDate)}. Review the next period and amounts, then select Renew Maintenance. The previous quotation stays in history.',
                      ),
                    ],
                  ),
                ),
              ),
            // =================================================
            // OFFER DATE
            // =================================================
            ListTile(
              title: Text(
                offerDate == null
                    ? 'Select Offer Date'
                    : 'Offer Date: ${df.format(offerDate!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: offerDate ?? DateTime.now(),
                );
                if (d != null) setState(() => offerDate = d);
              },
            ),

            const SizedBox(height: 10),

            // =================================================
            // CUSTOMER
            // =================================================
            // =================================================
            // CUSTOMER WITH ADD ICON
            // =================================================
            Row(
              children: [
                // -------- CUSTOMER DROPDOWN --------
                Expanded(
                  child: GestureDetector(
                    onTap: isRenewal
                        ? null
                        : openCustomerSearchDialog, // 🔥 OPEN SEARCH DIALOG
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

                const SizedBox(width: 8),

                // -------- ADD CUSTOMER ICON --------
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Add New Customer',
                  onPressed: isRenewal
                      ? null
                      : () async {
                          // 🔹 Open Customers Page
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomersPage(),
                            ),
                          );

                          // 🔹 Reload customers after return
                          await loadCustomers();
                        },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // =================================================
            // START DATE
            // =================================================
            ListTile(
              title: Text(
                startDate == null
                    ? 'Select Maintenance Start Date'
                    : 'Start Date: ${df.format(startDate!)}',
              ),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: startDate ?? DateTime.now(),
                );
                if (d != null) {
                  setState(() {
                    startDate = d;
                    if (isRenewal && months > 0) {
                      endDate = MaintenanceLifecycle.periodEnd(d, months);
                    }
                  });
                }
              },
            ),

            // =================================================
            // END DATE
            // =================================================
            ListTile(
              title: Text(
                endDate == null
                    ? 'Select Maintenance End Date'
                    : 'End Date: ${df.format(endDate!)}',
              ),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: endDate ?? DateTime.now(),
                );
                if (d != null) setState(() => endDate = d);
              },
            ),

            const SizedBox(height: 10),

            // =================================================
            // LIFT QTY
            // =================================================
            TextField(
              controller: liftQtyCtrl,
              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: 'Lift Quantity',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => liftQty = int.tryParse(v) ?? 0),
            ),

            const SizedBox(height: 10),

            // =================================================
            // MONTHS
            // =================================================
            TextField(
              keyboardType: TextInputType.number,
              controller: monthsCtrl,
              decoration: const InputDecoration(
                labelText: 'Months',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() {
                months = int.tryParse(v) ?? 0;
                if (isRenewal && startDate != null && months > 0) {
                  endDate = MaintenanceLifecycle.periodEnd(startDate!, months);
                }
              }),
            ),

            const SizedBox(height: 10),

            // =================================================
            // LIFT AMOUNT
            // =================================================
            TextField(
              keyboardType: TextInputType.number,
              controller: liftAmountCtrl,
              decoration: const InputDecoration(
                labelText: 'Lift Amount',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  setState(() => liftAmount = double.tryParse(v) ?? 0),
            ),

            const SizedBox(height: 16),

            // =================================================
            // AUTO CALCULATED
            // =================================================
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Amount: ₹${monthlyAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Amount: ₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // SAVE BUTTON
            // =================================================
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(
                _saving
                    ? 'Saving...'
                    : isRenewal
                    ? 'Renew Maintenance'
                    : isEditMode
                    ? 'Update Maintenance Quotation'
                    : 'Save Maintenance Quotation',
              ),

              onPressed: _saving ? null : saveMaintenanceQuotation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 🔹 CLEAN UP CONTROLLERS
  // =====================================================
  @override
  void dispose() {
    liftQtyCtrl.dispose();
    monthsCtrl.dispose();
    liftAmountCtrl.dispose();
    customerSearchCtrl.dispose(); // 🔹 CLEANUP
    super.dispose();
  }
}
