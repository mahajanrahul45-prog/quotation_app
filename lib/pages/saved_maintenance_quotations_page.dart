import '../storage/maintenance_quotation_storage.dart';
import 'dart:async';
import '../models/maintenance_lifecycle.dart';
import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../storage/cloud_preferences.dart';
import '../models/maintenance_quotation.dart';
import 'maintenance_quotation_page.dart';
import '../pages/maintenance_preview_page.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data'; // 🔥 REQUIRED for Uint8List

//import 'package:url_launcher/url_launcher.dart';
//import 'package:printing/printing.dart';

import '../utils/maintenance_pdf_helper.dart';

// =====================================================
// 🔹 SYSTEM MAINTENANCE STATUS (ENUM — BEST PRACTICE)
// =====================================================

// =====================================================
// 🔹 ENUM DISPLAY HELPERS
// =====================================================
extension MaintenanceSystemStatusExt on MaintenanceSystemStatus {
  String get label {
    switch (this) {
      case MaintenanceSystemStatus.active:
        return 'Active';
      case MaintenanceSystemStatus.expiringSoon:
        return 'Expiring Soon';
      case MaintenanceSystemStatus.expired:
        return 'Expired';
      case MaintenanceSystemStatus.archived:
        return 'Previous contract';
    }
  }

  Color get color {
    switch (this) {
      case MaintenanceSystemStatus.active:
        return Colors.green;
      case MaintenanceSystemStatus.expiringSoon:
        return Colors.orange;
      case MaintenanceSystemStatus.expired:
        return Colors.red;
      case MaintenanceSystemStatus.archived:
        return Colors.blueGrey;
    }
  }
}

// =====================================================
// 🔹 EXCEL / DISPLAY SR NO FORMATTER
// =====================================================
String formatSrNo(int index) {
  // index starts from 0 → convert to 1,2,3...
  return (index + 1).toString().padLeft(4, '0');
}

// =====================================================
// 🔹 EXCEL DATE FORMATTER
// Used for Offer Date, Start Date, End Date in Excel export
// =====================================================
final DateFormat excelDateFormat = DateFormat('dd/MM/yyyy');

// =====================================================
// 🔹 HELPER — BUILD PDF FILE NAME
// FORMAT: CustomerName-SrNo Maintenance.pdf
// Example: Jagdamba-1 Maintenance.pdf
// =====================================================
String buildPdfFileName(int srNo, String customerName) {
  final safeCustomer = customerName
      .replaceAll(RegExp(r'[^\w\s-]'), '') // remove symbols
      .trim();

  return '$safeCustomer-$srNo Maintenance.pdf';
}

class SavedMaintenanceQuotationsPage extends StatefulWidget {
  const SavedMaintenanceQuotationsPage({
    super.key,
    this.initialView = MaintenanceView.all,
  });
  final MaintenanceView initialView;

  @override
  State<SavedMaintenanceQuotationsPage> createState() =>
      _SavedMaintenanceQuotationsPageState();
}

class _SavedMaintenanceQuotationsPageState
    extends State<SavedMaintenanceQuotationsPage> {
  List<Map<String, dynamic>> quotations = [];
  List<Map<String, dynamic>> filtered = [];

  // =====================================================
  // 🔹 SYSTEM STATUS COUNTERS (AUTO)
  // =====================================================
  int activeCount = 0;
  int expiringSoonCount = 0;
  int expiredCount = 0;
  int renewedCount = 0;

  // =====================================================
  // 🔹 SYSTEM MAINTENANCE STATUS CALCULATOR (ENUM BASED)
  // =====================================================
  final TextEditingController searchCtrl = TextEditingController();

  // =====================================================
  // 🔹 SEARCH FILTER
  // =====================================================
  late MaintenanceView _view;
  Timer? _clock;
  bool _loading = true;
  String? _loadError;

  String get _title => switch (_view) {
    MaintenanceView.all => 'Saved Maintenance Quotations',
    MaintenanceView.active => 'Active Maintenance',
    MaintenanceView.expiringSoon => 'Expiring Soon',
    MaintenanceView.expired => 'Expired Maintenance',
    MaintenanceView.renewed => 'Renewed This Month',
  };

  void onSearch(String value) => _refreshDerived();

  void _refreshDerived() {
    if (!mounted) return;
    final all = quotations.map(MaintenanceQuotation.fromMap).toList();
    final query = searchCtrl.text.trim().toLowerCase();
    setState(() {
      activeCount = all
          .where(
            (q) => MaintenanceLifecycle.matches(q, all, MaintenanceView.active),
          )
          .length;
      expiringSoonCount = all
          .where(
            (q) => MaintenanceLifecycle.matches(
              q,
              all,
              MaintenanceView.expiringSoon,
            ),
          )
          .length;
      expiredCount = all
          .where(
            (q) =>
                MaintenanceLifecycle.matches(q, all, MaintenanceView.expired),
          )
          .length;
      renewedCount = all
          .where((q) => MaintenanceLifecycle.renewedThisMonth(q))
          .length;
      for (var i = 0; i < quotations.length; i++) {
        quotations[i]['systemStatus'] = MaintenanceLifecycle.status(
          all[i],
          all,
        );
      }
      filtered = quotations
          .where(
            (q) =>
                MaintenanceLifecycle.matches(
                  MaintenanceQuotation.fromMap(q),
                  all,
                  _view,
                ) &&
                ('${q['customer']} ${q['area']} ${q['srNo']}'
                    .toLowerCase()
                    .contains(query)),
          )
          .toList();
    });
  }

  void _changeView(MaintenanceView view) {
    _view = view;
    _refreshDerived();
  }

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    loadQuotations();
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshDerived(),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> loadQuotations() async {
    try {
      final all = await MaintenanceQuotationStorage.load();
      all.sort((a, b) => b.offerDate.compareTo(a.offerDate));
      if (!mounted) return;
      quotations = all.map((q) => q.toMap()).toList();
      _loadError = null;
      _loading = false;
      _refreshDerived();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Unable to load maintenance quotations. Please retry.';
      });
    }
  }

  // =====================================================
  // 🔹 DELETE
  // =====================================================
  Future<void> deleteQuotation(int srNo) async {
    final prefs = await CloudPreferences.getInstance();
    final list = prefs.getStringList('maintenance_quotations') ?? [];

    list.removeWhere((e) {
      final m = jsonDecode(e);
      return m['srNo'] == srNo;
    });

    await prefs.setStringList('maintenance_quotations', list);
    loadQuotations();
  }

  // =====================================================
  // 🔹 SAVE FULL LIST TO SHARED PREFERENCES (OVERWRITE)
  // =====================================================
  // =====================================================
  // 🔹 SAVE FULL LIST TO SHARED PREFERENCES (FIXED)
  // =====================================================
  Future<void> saveAllQuotations(List<Map<String, dynamic>> list) async {
    final prefs = await CloudPreferences.getInstance();

    final encoded = list.map((e) {
      return jsonEncode({
        'srNo': e['srNo'],
        'status': e['status'] ?? 'New',
        'renewedFromSrNo': e['renewedFromSrNo'],
        'renewedAt': e['renewedAt'],
        'offerDate': e['offerDate'] ?? DateTime.now().toIso8601String(),
        'customer': e['customer'],
        'area': e['area'] ?? '',
        'startDate': e['startDate'],
        'endDate': e['endDate'],
        'liftQty': e['liftQty'],
        'months': e['months'],
        'liftAmount': e['liftAmount'],
        'monthlyAmount': e['monthlyAmount'],
        'totalAmount': e['totalAmount'],
      });
    }).toList();

    await prefs.setStringList('maintenance_quotations', encoded);
  }

  // =====================================================
  // 🔹 UPDATE STATUS FOR SINGLE QUOTATION
  // =====================================================
  Future<void> updateStatus(int srNo, String newStatus) async {
    final prefs = await CloudPreferences.getInstance();
    final list = prefs.getStringList('maintenance_quotations') ?? [];

    final updated = list.map((e) {
      final m = jsonDecode(e);
      if (m['srNo'] == srNo) {
        m['status'] = newStatus; // ✅ UPDATE STATUS
      }
      return jsonEncode(m);
    }).toList();

    await prefs.setStringList('maintenance_quotations', updated);

    // 🔄 Reload UI
    await loadQuotations();
  }

  // =====================================================
  // 🔹 EXPORT MAINTENANCE LIST TO EXCEL (ANDROID SAFE)
  // =====================================================
  Future<void> exportToExcel() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Maintenance Quotations'];

      // 🔹 Header
      sheet.appendRow([
        TextCellValue('Sr No'),
        TextCellValue('Offer Date'),
        TextCellValue('Customer / Building Name'),
        TextCellValue('Start Date'),
        TextCellValue('End Date'),
        TextCellValue('Lift Qty'),
        TextCellValue('Months'),
        TextCellValue('Lift Amount'),
        TextCellValue('Monthly Amount'),
        TextCellValue('Total Amount'),
        TextCellValue('Quotation ID'),
        TextCellValue('Renewed From ID'),
        TextCellValue('Renewed At'),
        TextCellValue('Status'),
        TextCellValue('Area'),
      ]);

      // 🔹 Data rows
      for (int i = 0; i < quotations.length; i++) {
        final q = quotations[i];

        final String offerDate = q['offerDate'] != null
            ? excelDateFormat.format(DateTime.parse(q['offerDate']))
            : '';

        final String startDate = excelDateFormat.format(
          DateTime.parse(q['startDate']),
        );

        final String endDate = excelDateFormat.format(
          DateTime.parse(q['endDate']),
        );

        sheet.appendRow([
          TextCellValue(formatSrNo(i)),
          TextCellValue(offerDate),
          TextCellValue(q['customer']),
          TextCellValue(startDate),
          TextCellValue(endDate),
          IntCellValue(q['liftQty']),
          IntCellValue(q['months']),
          DoubleCellValue(q['liftAmount']),
          DoubleCellValue(q['monthlyAmount']),
          DoubleCellValue(q['totalAmount']),
          TextCellValue(q['srNo'].toString()),
          TextCellValue(q['renewedFromSrNo']?.toString() ?? ''),
          TextCellValue(q['renewedAt']?.toString() ?? ''),
          TextCellValue(q['status']?.toString() ?? 'New'),
          TextCellValue(q['area']?.toString() ?? ''),
        ]);
      } // ✅ CLOSE for-loop

      // 🔹 Encode Excel
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encoding failed');

      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Maintenance Quotations Excel',
        fileName: 'Saved_Maintenance_Quotations.xlsx',
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
    } catch (e) {
      // ✅ NOW Dart SEES THIS
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // =====================================================
  // 🔹 CHECK IF MAINTENANCE IS RENEWED
  // =====================================================
  Future<void> importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final sheet =
        excel.tables['Maintenance Quotations'] ??
        excel.tables.values.firstWhere((table) => table.rows.isNotEmpty);

    final List<Map<String, dynamic>> imported = [];

    // 🔹 START FROM ROW 1 (skip header)
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.length < 10 || (row[2]?.value?.toString().trim() ?? '').isEmpty) {
        continue;
      }
      String cell(int index) =>
          index < row.length ? row[index]?.value?.toString() ?? '' : '';

      // 🔹 SAFE DATE PARSING FROM EXCEL
      DateTime parseExcelDate(dynamic v) {
        if (v == null) return DateTime.now();
        if (v is DateTime) return v;
        final parsed = DateTime.tryParse(v.toString());
        if (parsed != null) return parsed;
        return excelDateFormat.parseStrict(v.toString());
      }

      imported.add({
        'srNo':
            int.tryParse(cell(10)) ?? DateTime.now().microsecondsSinceEpoch + i,
        'renewedFromSrNo': int.tryParse(cell(11)),
        'renewedAt': DateTime.tryParse(cell(12))?.toIso8601String(),
        'status': cell(13).isEmpty ? 'New' : cell(13),
        'offerDate': parseExcelDate(row[1]?.value).toIso8601String(),
        'customer': row[2]?.value?.toString() ?? '',
        'area': cell(14), // 🔥 REQUIRED
        'startDate': parseExcelDate(row[3]?.value).toIso8601String(),
        'endDate': parseExcelDate(row[4]?.value).toIso8601String(),
        'liftQty': int.tryParse(row[5]?.value?.toString() ?? '0') ?? 0,
        'months': int.tryParse(row[6]?.value?.toString() ?? '0') ?? 0,
        'liftAmount': double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0,
        'monthlyAmount': double.tryParse(row[8]?.value?.toString() ?? '0') ?? 0,
        'totalAmount': double.tryParse(row[9]?.value?.toString() ?? '0') ?? 0,
      });
    }

    // 🔹 OVERWRITE EXISTING DATA PERMANENTLY
    await saveAllQuotations(imported);

    // 🔹 RELOAD FROM STORAGE (single source of truth)
    await loadQuotations();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel imported and saved successfully')),
    );
  }

  // =====================================================
  // 🔹 UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('maintenance')) {
      return const AccessDenied();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppScaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Refresh quotations',
            icon: const Icon(Icons.refresh),
            onPressed: loadQuotations,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_loadError != null)
                    Row(
                      children: [
                        Expanded(child: Text(_loadError!)),
                        TextButton(
                          onPressed: loadQuotations,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  Text(
                    'Maintenance overview',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track contracts, review quotations and manage renewals.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final itemWidth =
                          (width - (width >= 700 ? 36 : 12)) /
                          (width >= 700 ? 4 : 2);
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: buildCounterChip(
                              label: 'Active',
                              count: activeCount,
                              color: const Color(0xFF16805D),
                              icon: Icons.verified_outlined,
                              view: MaintenanceView.active,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: buildCounterChip(
                              label: 'Expiring soon',
                              count: expiringSoonCount,
                              color: const Color(0xFFB56A08),
                              icon: Icons.schedule_outlined,
                              view: MaintenanceView.expiringSoon,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: buildCounterChip(
                              label: 'Expired',
                              count: expiredCount,
                              color: const Color(0xFFC04444),
                              icon: Icons.event_busy_outlined,
                              view: MaintenanceView.expired,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: buildCounterChip(
                              label: 'Renewed this month',
                              count: renewedCount,
                              color: const Color(0xFF3474B8),
                              icon: Icons.autorenew,
                              view: MaintenanceView.renewed,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Text(
                        'Quotations (${quotations.length})',
                        style: theme.textTheme.titleLarge,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: importFromExcel,
                            icon: const Icon(
                              Icons.upload_file_outlined,
                              size: 18,
                            ),
                            label: const Text('Import Excel'),
                          ),
                          OutlinedButton.icon(
                            onPressed: quotations.isEmpty
                                ? null
                                : exportToExcel,
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: const Text('Export Excel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final view in MaintenanceView.values)
                        ChoiceChip(
                          label: Text(switch (view) {
                            MaintenanceView.all => 'All quotations',
                            MaintenanceView.active => 'Active',
                            MaintenanceView.expiringSoon => 'Expiring soon',
                            MaintenanceView.expired => 'Expired',
                            MaintenanceView.renewed => 'Renewed this month',
                          }),
                          selected: _view == view,
                          onSelected: (_) => _changeView(view),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_view == MaintenanceView.renewed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Renewals completed in ${DateFormat('MMMM yyyy').format(DateTime.now())}. Contracts remain in their date-based status after this month.',
                      ),
                    ),
                  TextField(
                    controller: searchCtrl,
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search customer or quotation number',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                searchCtrl.clear();
                                onSearch('');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'quotation' : 'quotations'} | Latest offer first',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_loading && filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      searchCtrl.text.isEmpty
                          ? 'No quotations in this view'
                          : 'No quotations found',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      searchCtrl.text.isEmpty
                          ? 'Saved maintenance quotations will appear here.'
                          : 'Try another customer name or quotation number.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    _quotationCard(filtered[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildCounterChip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required MaintenanceView view,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _changeView(view),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('$count', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quotationCard(Map<String, dynamic> q) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = q['systemStatus'] as MaintenanceSystemStatus;
    final df = DateFormat('dd MMM yyyy');
    String date(dynamic value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      return parsed == null ? 'Not available' : df.format(parsed);
    }

    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 2,
    );
    String money(dynamic value) =>
        currency.format(num.tryParse(value.toString()) ?? 0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q['customer']?.toString() ?? '',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quotation #${q['srNo']} | ${date(q['offerDate'])}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if ((q['area'] ?? '').toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          q['area'].toString(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Quotation actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'renew':
                        openRenewal(q);
                        break;
                      case 'edit':
                        openEdit(q);
                        break;
                      case 'print':
                        openPreview(q);
                        break;
                      case 'mail':
                        sendMail(q);
                        break;
                      case 'whatsapp':
                        sendWhatsapp(q);
                        break;
                      case 'delete':
                        confirmDelete(q['srNo']);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'renew',
                      enabled: status != MaintenanceSystemStatus.archived,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.autorenew),
                        title: Text('Renew maintenance'),
                      ),
                    ),
                    PopupMenuItem(value: 'edit', child: Text('Edit quotation')),
                    PopupMenuItem(value: 'print', child: Text('Print preview')),
                    PopupMenuItem(value: 'mail', child: Text('Send via Mail')),
                    PopupMenuItem(
                      value: 'whatsapp',
                      child: Text('Send via WhatsApp'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete quotation',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.label,
                style: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? Color.lerp(status.color, Colors.white, 0.4)
                      : Color.lerp(status.color, Colors.black, 0.25),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (q['renewedAt'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Renewed on ${date(q['renewedAt'])} | Previous quotation #${q['renewedFromSrNo']}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                _detail(
                  'Contract period',
                  '${date(q['startDate'])} to ${date(q['endDate'])}',
                ),
                _detail('Lift quantity', '${q['liftQty']}'),
                _detail('Duration', '${q['months']} months'),
                _detail('Amount per lift', money(q['liftAmount'])),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total amount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      money(q['totalAmount']),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => openEdit(q),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openPreview(q),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview'),
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

  Widget _detail(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> openRenewal(Map<String, dynamic> q) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceQuotationPage(
          quotationToRenew: MaintenanceQuotation.fromMap(q),
        ),
      ),
    );
    if (saved == true && mounted) await loadQuotations();
  }

  void openEdit(Map<String, dynamic> q) {
    // 🔹 Convert Map → Model
    final quotation = MaintenanceQuotation.fromMap(q);

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceQuotationPage(quotationToEdit: quotation),
      ),
    ).then((updated) {
      // 🔹 If user saved or updated quotation
      if (updated == true) {
        loadQuotations(); // 🔄 reload saved list
      }
    });
  }

  // =====================================================
  // 🔹 OPEN PRINT PREVIEW
  // =====================================================
  void openPreview(Map<String, dynamic> q) {
    // 🔹 1) Convert MAP → MaintenanceQuotation MODEL
    final quotation = MaintenanceQuotation(
      srNo: q['srNo'],

      // ✅ ADD STATUS
      status: q['status'] ?? 'Pending',

      // ✅ ADD OFFER DATE
      offerDate: q['offerDate'] != null
          ? DateTime.parse(q['offerDate'])
          : DateTime.now(),
      customerName: q['customer'],
      area: q['area'], // ✅ ADD THIS
      startDate: DateTime.parse(q['startDate']),
      endDate: DateTime.parse(q['endDate']),
      liftQty: q['liftQty'],
      months: q['months'],
      liftAmount: q['liftAmount'],

      // ✅ ADD THESE TWO (FIX ERROR)
      monthlyAmount: q['monthlyAmount'],
      totalAmount: q['totalAmount'],
    );

    // 🔹 2) Open preview page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenancePreviewPage(
          quotation: quotation, // pass MODEL
        ),
      ),
    );
  }

  // =====================================================
  // 🔹 SEND VIA MAIL
  // =====================================================
  Future<void> sendMail(Map<String, dynamic> q) async {
    final quotation = MaintenanceQuotation(
      srNo: q['srNo'],
      // ✅ ADD STATUS
      status: q['status'] ?? 'Pending',

      offerDate: q['offerDate'] != null
          ? DateTime.parse(q['offerDate'])
          : DateTime.now(),
      customerName: q['customer'],
      area: q['area'],
      startDate: DateTime.parse(q['startDate']),
      endDate: DateTime.parse(q['endDate']),
      liftQty: q['liftQty'],
      months: q['months'],
      liftAmount: q['liftAmount'],
      monthlyAmount: q['monthlyAmount'],
      totalAmount: q['totalAmount'],
    );

    final pdfBytes = await buildMaintenancePdfBytes(quotation);

    // 🔹 BUILD FILE NAME
    final fileName = buildPdfFileName(quotation.srNo, quotation.customerName);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf'),
        ],
        text: 'Please find attached maintenance quotation.',
      ),
    );
  }

  // =====================================================
  // 🔹 SEND VIA WHATSAPP
  // =====================================================
  Future<void> sendWhatsapp(Map<String, dynamic> q) async {
    final quotation = MaintenanceQuotation(
      srNo: q['srNo'],

      // ✅ ADD STATUS
      status: q['status'] ?? 'Pending',
      offerDate: q['offerDate'] != null
          ? DateTime.parse(q['offerDate'])
          : DateTime.now(),
      customerName: q['customer'],
      area: q['area'],
      startDate: DateTime.parse(q['startDate']),
      endDate: DateTime.parse(q['endDate']),
      liftQty: q['liftQty'],
      months: q['months'],
      liftAmount: q['liftAmount'],
      monthlyAmount: q['monthlyAmount'],
      totalAmount: q['totalAmount'],
    );

    final pdfBytes = await buildMaintenancePdfBytes(quotation);

    // 🔹 BUILD FILE NAME
    final fileName = buildPdfFileName(quotation.srNo, quotation.customerName);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf'),
        ],
        text: 'Maintenance quotation attached.',
      ),
    );
  }

  Future<void> confirmDelete(int srNo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this quotation?'),
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

    if (ok == true) {
      deleteQuotation(srNo);
    }
  }
}
