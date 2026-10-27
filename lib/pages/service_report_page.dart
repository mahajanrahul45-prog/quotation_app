import '../storage/customer_directory.dart';
import '../widgets/inspection_photo.dart';
import '../widgets/service_language_scope.dart';
import '../widgets/remarks_field.dart';
import '../utils/service_report_language.dart';
import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../storage/cloud_preferences.dart';
import '../storage/service_buildings.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'saved_service_reports_page.dart';
import '../models/service_report.dart';
import '../models/service_checklist.dart';
import 'service_report_body_page.dart';

import 'service_report_preview_page.dart';

class ServiceReportPage extends StatefulWidget {
  final ServiceReport? editReport;

  const ServiceReportPage({super.key, this.editReport});

  @override
  State<ServiceReportPage> createState() => _ServiceReportPageState();
}

class _ServiceReportPageState extends State<ServiceReportPage> {
  // ----------------------------
  // SIGNATURE CONTROLLER
  // ----------------------------
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // Saved signature image path
  String? customerSignaturePath;

  // ✅ NEW: Saved signature as Base64 (for PDF preview/print/share)
  String? customerSignatureBase64;

  String _monthName(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return ServiceReportLanguage(
      _languageCode,
    ).month('${months[month - 1]} 2000').split(' ').first;
  }

  // ----------------------------
  // Controllers
  // ----------------------------
  final srNoController = TextEditingController();
  final dateController = TextEditingController();
  final locationController = TextEditingController();
  final serviceMonthController = TextEditingController();
  final liftServiceDateController = TextEditingController();
  final liftQtyController = TextEditingController();
  final customerPersonController = TextEditingController();
  final servicePersonController = TextEditingController();
  final workDoneController = TextEditingController();
  final nextServiceMonthController = TextEditingController();
  List<ServiceInspection> _inspections = [];
  String _reportHeading = 'LIFT SERVICE REPORT', _liftStatus = 'Not assessed';
  String _languageCode = 'en_hi';
  String _t(String text) => ServiceReportLanguage(_languageCode).text(text);

  void _changeLanguage(String code) {
    setState(() {
      _languageCode = code;
      serviceMonthController.text = ServiceReportLanguage(
        code,
      ).month(serviceMonthController.text);
      nextServiceMonthController.text = ServiceReportLanguage(
        code,
      ).month(nextServiceMonthController.text);
      // Only built-in default wording is translated; free text is preserved.
      final known = ServiceReportLanguage.hindi[defaultServiceWork];
      if (workDoneController.text == defaultServiceWork ||
          workDoneController.text == known ||
          workDoneController.text ==
              const ServiceReportLanguage('en_hi').text(defaultServiceWork)) {
        workDoneController.text = _t(defaultServiceWork);
      }
    });
  }

  String _defaultWork = defaultServiceWork;
  bool _bodyReady = false;
  String? _bodyError;

  // ----------------------------
  // Customer data (MAP based)
  // ----------------------------
  List<Map<String, dynamic>> customers = [];
  String? selectedCustomerName;
  bool _loadingBuildings = true, _addingBuilding = false;
  String? _buildingError;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadBody();

    if (widget.editReport == null) {
      final today = DateTime.now();
      final date = '${today.day}/${today.month}/${today.year}';
      dateController.text = date;
      liftServiceDateController.text = date;
      serviceMonthController.text = '${_monthName(today.month)} ${today.year}';
      final nextMonth = DateTime(today.year, today.month + 1);
      nextServiceMonthController.text =
          '${_monthName(nextMonth.month)} ${nextMonth.year}';
    }

    // 🔁 Edit mode
    if (widget.editReport != null) {
      final r = widget.editReport!;
      _languageCode = r.languageCode;
      srNoController.text = r.srNo.toString();
      dateController.text = r.date;
      selectedCustomerName = r.buildingName;
      locationController.text = r.location;
      liftQtyController.text = r.liftQty.toString(); // ✅ ADD
      serviceMonthController.text = ServiceReportLanguage(
        _languageCode,
      ).month(r.serviceMonth);
      liftServiceDateController.text = r.liftServiceDate;
      customerPersonController.text = r.customerPersonName;
      customerSignatureBase64 = r.customerSignatureBase64;
      servicePersonController.text = r.servicePersonName;
      workDoneController.text = r.workDone;
      nextServiceMonthController.text = ServiceReportLanguage(
        _languageCode,
      ).month(r.nextServiceMonth);
      _reportHeading = r.heading;
      _liftStatus = r.liftStatus;
      _inspections = r.checklist
          .map((p) => ServiceInspection.fromJson(p.toJson()))
          .toList();
    }
  }

  Future<void> _loadBody() async {
    if (widget.editReport != null) {
      setState(() => _bodyReady = true);
      return;
    }
    try {
      final body = await ServiceBodyTemplate.load();
      if (!mounted) return;
      final existing = {for (final p in _inspections) p.id: p};
      setState(() {
        _reportHeading = body.heading;
        _inspections = body.newInspections().map((p) {
          final old = existing[p.id];
          if (old != null) {
            p.ok = old.ok;
            p.remarks = old.remarks;
            p.photoBase64 = old.photoBase64;
          }
          return p;
        }).toList();
        if (workDoneController.text.isEmpty ||
            workDoneController.text == _defaultWork ||
            workDoneController.text == defaultServiceWork ||
            workDoneController.text ==
                ServiceReportLanguage.hindi[defaultServiceWork]) {
          workDoneController.text =
              (body.workDone == defaultServiceWork ||
                  body.workDone ==
                      ServiceReportLanguage.hindi[defaultServiceWork])
              ? _t(body.workDone)
              : body.workDone;
        }
        _defaultWork = body.workDone;
        _bodyReady = true;
        _bodyError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _bodyError = 'Could not load checklist: $e');
    }
  }

  Future<void> _configureBody() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceReportBodyPage(languageCode: _languageCode),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _bodyReady = false);
      await _loadBody();
    }
  }

  // ----------------------------
  // LOAD CUSTOMERS (SAME FORMAT AS CustomersPage)
  // ----------------------------
  Future<void> _loadCustomers() async {
    if (!mounted) return;
    setState(() {
      _loadingBuildings = true;
      _buildingError = null;
    });
    try {
      final records = await CustomerDirectory.load();
      // Keep an existing report editable even if its building predates the list.
      if (selectedCustomerName != null &&
          !records.any(
            (c) =>
                buildingNameKey(c['customerName']) ==
                buildingNameKey(selectedCustomerName!),
          )) {
        records.add({
          'customerName': selectedCustomerName!,
          'area': locationController.text,
        });
      }
      if (!mounted) return;
      setState(() {
        customers = records;
        if (selectedCustomerName != null) {
          selectedCustomerName = records.firstWhere(
            (c) =>
                buildingNameKey(c['customerName']) ==
                buildingNameKey(selectedCustomerName!),
          )['customerName'];
        }
        _loadingBuildings = false;
        _buildingError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBuildings = false;
          _buildingError =
              'Unable to load customers and buildings. Please try again.';
        });
      }
    }
  }

  Future<void> _addBuilding() async {
    final name = TextEditingController(), location = TextEditingController();
    final form = GlobalKey<FormState>();
    final route = DialogRoute<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Add building')),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _t('Customer / Building Name'),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? _t('Enter building name')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: location,
                  decoration: InputDecoration(labelText: _t('Location / area')),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? _t('Enter location')
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, <String, dynamic>{
                  'customerName': name.text.trim().replaceAll(
                    RegExp(r'\s+'),
                    ' ',
                  ),
                  'area': location.text.trim(),
                });
              }
            },
            child: Text(_t('Save building')),
          ),
        ],
      ),
    );
    final result = await Navigator.of(context).push(route);
    unawaited(
      route.completed.then((_) {
        name.dispose();
        location.dispose();
      }),
    );
    if (result == null || !mounted) return;
    setState(() => _addingBuilding = true);
    try {
      final prefs = await CloudPreferences.getInstance();
      final stored = ServiceBuildings.decode(
        prefs.getStringList(ServiceBuildings.storageKey) ?? [],
      );
      final key = buildingNameKey(result['customerName']);
      final existing = stored
          .where((c) => buildingNameKey(c['customerName']) == key)
          .firstOrNull;
      final selected = existing ?? result;
      if (existing == null) {
        stored.add({...result, ...CustomerDirectory.creatorMetadata()});
        await prefs.setStringList(
          ServiceBuildings.storageKey,
          stored.map(jsonEncode).toList(),
        );
      }
      if (!mounted) return;
      selectedCustomerName = selected['customerName'];
      locationController.text = selected['area'] ?? '';
      await _loadCustomers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null
                  ? 'Building saved online.'
                  : 'Building already exists. Selected existing building.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save building: $e')));
      }
    } finally {
      if (mounted) setState(() => _addingBuilding = false);
    }
  }

  // ----------------------------
  // SAVE SERVICE REPORT
  // ----------------------------
  Future<void> _saveServiceReport() async {
    final prefs = await CloudPreferences.getInstance();
    final stored = prefs.getString('service_reports');

    List<ServiceReport> reports = [];
    if (stored != null) {
      final decoded = jsonDecode(stored) as List;
      reports = decoded.map((e) => ServiceReport.fromJson(e)).toList();
    }

    // 🔢 AUTO SR NO
    final nextSrNo = reports.isEmpty
        ? 1
        : reports.map((e) => e.srNo).reduce((a, b) => a > b ? a : b) + 1;

    final report = ServiceReport(
      languageCode: _languageCode,
      heading: _reportHeading,
      checklist: _inspections,
      workDone: workDoneController.text.trim(),
      liftStatus: _liftStatus,
      nextServiceMonth: nextServiceMonthController.text,
      srNo: widget.editReport?.srNo ?? nextSrNo,
      date: dateController.text,
      buildingName: selectedCustomerName ?? '',
      location: locationController.text,
      liftQty: int.tryParse(liftQtyController.text) ?? 0, // ✅ FIX
      serviceMonth: serviceMonthController.text,
      liftServiceDate: liftServiceDateController.text,
      customerPersonName: customerPersonController.text,
      customerSignaturePath: customerSignaturePath ?? '',
      customerSignatureBase64: customerSignatureBase64 ?? '', // ✅ ADD

      servicePersonName: servicePersonController.text,
    );

    if (widget.editReport != null) {
      final index = reports.indexWhere(
        (e) => e.srNo == widget.editReport!.srNo,
      );
      if (index != -1) reports[index] = report;
    } else {
      reports.add(report);
    }

    await prefs.setString(
      'service_reports',
      jsonEncode(reports.map((e) => e.toJson()).toList()),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ----------------------------
  // DATE PICKER
  // ----------------------------
  DateTime _selectedDate(String text) {
    final parts = text.split('/').map(int.tryParse).toList();
    if (parts.length == 3 && !parts.contains(null)) {
      return DateTime(parts[2]!, parts[1]!, parts[0]!);
    }
    return DateTime.now();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      builder: (_, child) =>
          ServiceLanguageScope(code: _languageCode, child: child!),
      initialDate: _selectedDate(controller.text),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = '${picked.day}/${picked.month}/${picked.year}';
    }
  }

  // ----------------------------
  // ✍️ SIGNATURE SKETCH DIALOG
  // ----------------------------
  Future<void> _openSignaturePad() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Customer Signature')),
        content: SizedBox(
          height: 220,
          width: double.maxFinite,
          child: Signature(
            controller: _signatureController,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _signatureController.clear(),
            child: Text(_t('Clear')),
          ),
          ElevatedButton(
            child: Text(_t('Save')),
            onPressed: () async {
              if (_signatureController.isEmpty) {
                Navigator.pop(ctx);
                return;
              }

              final Uint8List? bytes = await _signatureController.toPngBytes();

              if (bytes == null) return;

              final dir = await getApplicationDocumentsDirectory();
              final file = File(
                '${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png',
              );

              // 🔹 Convert drawn signature to Base64 (PDF-safe)
              final String base64 = base64Encode(bytes);

              // 🔹 Save file (only for UI preview)
              await file.writeAsBytes(bytes);

              setState(() {
                customerSignaturePath = file.path; // UI preview
                customerSignatureBase64 = base64; // ✅ PDF usage
              });

              _signatureController.clear();

              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ----------------------------
  // 📤 UPLOAD SIGNATURE IMAGE
  // ----------------------------
  Future<void> _uploadSignatureImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    // 🔹 Read image bytes
    final bytes = await picked.readAsBytes();

    // 🔹 Convert to Base64 (PDF-safe)
    final String base64 = base64Encode(bytes);

    // 🔹 Save file for UI preview
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/uploaded_signature_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(bytes);

    setState(() {
      customerSignaturePath = file.path; // UI preview
      customerSignatureBase64 = base64; // ✅ PDF usage
    });
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('service')) return const AccessDenied();
    return ServiceLanguageScope(
      code: _languageCode,
      child: Builder(
        builder: (context) => AppScaffold(
          appBar: AppBar(
            title: Text(
              widget.editReport == null
                  ? _t('Service Report')
                  : _t('Edit Service Report'),
            ),

            // 🔹 ACTION ICONS (RIGHT SIDE)
            actions: [
              // 🖨️ PRINT PREVIEW ICON
              if (widget.editReport == null)
                IconButton(
                  tooltip: _t('Configure service checklist'),
                  icon: const Icon(Icons.checklist),
                  onPressed: _bodyReady ? _configureBody : null,
                ),
              IconButton(
                tooltip: _t('Print Preview'),
                icon: const Icon(Icons.print),
                onPressed: !_bodyReady
                    ? null
                    : () {
                        final report = ServiceReport(
                          languageCode: _languageCode,
                          heading: _reportHeading,
                          checklist: _inspections,
                          workDone: workDoneController.text.trim(),
                          liftStatus: _liftStatus,
                          nextServiceMonth: nextServiceMonthController.text,
                          srNo: widget.editReport?.srNo ?? 0,
                          date: dateController.text,
                          buildingName: selectedCustomerName ?? '',
                          location: locationController.text,
                          serviceMonth: serviceMonthController.text,
                          liftServiceDate: liftServiceDateController.text,
                          liftQty: int.tryParse(liftQtyController.text) ?? 0,
                          customerPersonName: customerPersonController.text,
                          customerSignaturePath: customerSignaturePath ?? '',
                          customerSignatureBase64:
                              customerSignatureBase64 ?? '', // ✅ ADD
                          servicePersonName: servicePersonController.text,
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ServiceReportPreviewPage(report: report),
                          ),
                        );
                      },
              ),

              // 🕒 SAVED SERVICE REPORTS ICON
              IconButton(
                tooltip: _t('Saved Service Reports'),
                icon: const Icon(Icons.history),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SavedServiceReportsPage(),
                    ),
                  );
                  if (mounted && widget.editReport == null) await _loadBody();
                },
              ),
            ],
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('service_language'),
                      initialValue: _languageCode,
                      decoration: const InputDecoration(
                        labelText: 'Language / भाषा',
                        prefixIcon: Icon(Icons.translate),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'en_hi',
                          child: Text(
                            'English / Hindi',
                            style: TextStyle(fontFamily: 'NotoService'),
                          ),
                        ),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(
                          value: 'hi',
                          child: Text(
                            'हिंदी',
                            style: TextStyle(fontFamily: 'NotoService'),
                          ),
                        ),
                      ],
                      onChanged: (code) {
                        if (code != null) _changeLanguage(code);
                      },
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _t('REPORT & BUILDING DETAILS'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sr No
                    TextField(
                      controller: srNoController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: _t('Sr No (Auto)'),
                      ),
                    ),

                    // Date
                    const SizedBox(height: 20),
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: _t('Date'),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () => _pickDate(dateController),
                    ),

                    // 🔽 Building Name (Customer Dropdown)
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      key: ValueKey('$_loadingBuildings:$selectedCustomerName'),
                      initialValue:
                          customers.any(
                            (c) => c['customerName'] == selectedCustomerName,
                          )
                          ? selectedCustomerName
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _t('Customer / Building Name'),
                        prefixIcon: const Icon(Icons.business_outlined),
                        hintText: 'Select a customer or building',
                      ),
                      selectedItemBuilder: (context) => customers
                          .map(
                            (c) => Text(
                              c['customerName'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                          .toList(),
                      itemHeight: 64,
                      items: customers.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['customerName'],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['customerName'] ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Added by: ${c['_ownerEmail'] ?? 'This workspace'}',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _loadingBuildings || _addingBuilding
                          ? null
                          : (value) {
                              setState(() {
                                selectedCustomerName = value;

                                final selected = customers.firstWhere(
                                  (c) => c['customerName'] == value,
                                );

                                // 📍 Auto-fill area
                                locationController.text =
                                    selected['area'] ?? '';
                              });
                            },
                    ),
                    if (_loadingBuildings) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                    if (_buildingError != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _buildingError!,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadCustomers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    if (selectedCustomerName != null && _buildingError == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Added by: ${customers.where((c) => c['customerName'] == selectedCustomerName).firstOrNull?['_ownerEmail'] ?? 'This workspace'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _loadingBuildings || _addingBuilding
                            ? null
                            : _addBuilding,
                        icon: const Icon(Icons.add_business),
                        label: Text(
                          _addingBuilding
                              ? _t('Saving building...')
                              : _t('Add building'),
                        ),
                      ),
                    ),

                    // Location (auto)
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: _t('Location')),
                    ),

                    // ----------------------------
                    // 📅 SERVICE MONTH PICKER (MONTH + YEAR)
                    // ----------------------------
                    const SizedBox(height: 20),
                    TextField(
                      controller: serviceMonthController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: _t('Service Month (MMM YYYY)'),
                        suffixIcon: Icon(Icons.calendar_month),
                      ),
                      onTap: () async {
                        final now = DateTime.now();

                        final picked = await showDatePicker(
                          context: context,
                          builder: (_, child) => ServiceLanguageScope(
                            code: _languageCode,
                            child: child!,
                          ),
                          initialDate: now,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          helpText: _t('Select Service Month'),
                        );

                        if (picked != null) {
                          serviceMonthController.text =
                              '${_monthName(picked.month)} ${picked.year}';
                        }
                      },
                    ),
                    // Lift qty
                    const SizedBox(height: 20),
                    TextField(
                      controller: liftQtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _t('Lift Quantity'),
                      ),
                    ),

                    // Date of Lift Serviced
                    const SizedBox(height: 20),
                    TextField(
                      controller: liftServiceDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: _t('Date Of Lift Serviced'),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () => _pickDate(liftServiceDateController),
                    ),

                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _t('BASIC SERVICE CHECKLIST'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (!_bodyReady && _bodyError == null)
                      const LinearProgressIndicator(),
                    if (_bodyError != null)
                      TextButton(
                        onPressed: _loadBody,
                        child: Text('$_bodyError — Retry'),
                      ),
                    if (_inspections.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            for (final p in _inspections) {
                              p.ok = true;
                            }
                          }),
                          icon: const Icon(Icons.done_all),
                          label: Text(_t('Mark all OK')),
                        ),
                      ),
                    if (_bodyReady && _inspections.isEmpty)
                      Text(
                        _t(
                          'No active inspection points. Add points in Service report body.',
                        ),
                      ),
                    for (final point in _inspections)
                      LayoutBuilder(
                        builder: (_, constraints) {
                          final status = Row(
                            children: [
                              Expanded(child: Text(_t(point.point))),
                              Checkbox(
                                value: point.ok,
                                onChanged: (v) =>
                                    setState(() => point.ok = v ?? false),
                              ),
                              Text(_t('OK')),
                            ],
                          );
                          final remarks = RemarksField(
                            key: ValueKey('remarks_${point.id}'),
                            initialValue: point.remarks,
                            label: _t('Remarks (optional)'),
                            languageCode: _languageCode,
                            onChanged: (v) => point.remarks = v,
                          );
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                constraints.maxWidth < 600
                                    ? Column(
                                        children: [
                                          status,
                                          const SizedBox(height: 8),
                                          remarks,
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(child: status),
                                          const SizedBox(width: 16),
                                          Expanded(child: remarks),
                                        ],
                                      ),
                                InspectionPhoto(
                                  key: ValueKey('inspection_photo_${point.id}'),
                                  photoBase64: point.photoBase64,
                                  point: point.point,
                                  languageCode: _languageCode,
                                  onChanged: (value) =>
                                      setState(() => point.photoBase64 = value),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                    RemarksField(
                      controller: workDoneController,
                      label: _t('WORK DONE / REMARKS'),
                      languageCode: _languageCode,
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _t('LIFT STATUS & NEXT VISIT'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _liftStatus,
                      key: const ValueKey('service_lift_status'),
                      isExpanded: true,
                      decoration: InputDecoration(labelText: _t('Lift status')),
                      items: {...serviceLiftStatuses, _liftStatus}
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(_t(s))),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _liftStatus = v ?? 'Not assessed'),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const ValueKey('service_next_month'),
                      controller: nextServiceMonthController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: _t('Next service month'),
                        hintText: _t('Select month and year'),
                        suffixIcon: IconButton(
                          tooltip: _t('Clear next service month'),
                          icon: const Icon(Icons.clear),
                          onPressed: nextServiceMonthController.clear,
                        ),
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          builder: (_, child) => ServiceLanguageScope(
                            code: _languageCode,
                            child: child!,
                          ),
                          initialDate: now,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          helpText: _t('Select next service month'),
                        );
                        if (date != null) {
                          nextServiceMonthController.text =
                              '${_monthName(date.month)} ${date.year}';
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Customer present
                    TextField(
                      controller: customerPersonController,
                      decoration: InputDecoration(
                        labelText: _t('Customer / representative name'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ----------------------------
                    // ✍️ CUSTOMER SIGNATURE UI
                    // ----------------------------
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _t('Customer Signature'),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 8),

                    if (customerSignaturePath != null)
                      Container(
                        height: 120,
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Image.file(
                          File(customerSignaturePath!),
                          fit: BoxFit.contain,
                        ),
                      ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.draw),
                            label: Text(_t('Draw Signature')),
                            onPressed: _openSignaturePad,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.upload),
                            label: Text(_t('Upload Signature')),
                            onPressed: _uploadSignatureImage,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    // Service person
                    TextField(
                      controller: servicePersonController,
                      decoration: InputDecoration(
                        labelText: _t('Service person name'),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SAVE / UPDATE
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _bodyReady ? _saveServiceReport : null,
                        child: Text(
                          widget.editReport == null ? _t('SAVE') : _t('UPDATE'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------
  // 🧹 DISPOSE CONTROLLERS (BEST PRACTICE)
  // ----------------------------
  @override
  void dispose() {
    // ✍️ Signature controller
    _signatureController.dispose();

    // 🧾 Text controllers
    liftQtyController.dispose();
    srNoController.dispose();
    dateController.dispose();
    locationController.dispose();
    serviceMonthController.dispose();
    liftServiceDateController.dispose();
    customerPersonController.dispose();
    servicePersonController.dispose();
    workDoneController.dispose();
    nextServiceMonthController.dispose();

    super.dispose();
  }
}
