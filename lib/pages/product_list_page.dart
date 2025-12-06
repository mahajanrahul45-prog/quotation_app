import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io'; // 👈 NEW
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as excel;      // 👈 NEW
import 'package:file_picker/file_picker.dart';   // 👈 NEW
//import 'package:path_provider/path_provider.dart'; // 👈 NEW
import '../pages/dashboard_page.dart';
//import '../data/product_catalog.dart';


class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<Map<String, dynamic>> _models = [];

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('models') ?? <String>[];
    setState(() {
      _models = stored.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _saveModels() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _models.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList('models', encoded);
  }

  /// 📥 IMPORT models from an Excel file.
  ///
  /// Expected Excel format:
  /// Row 1 (header):  Model No | Description
  /// From Row 2:      Actual data
  Future<void> _importFromExcel() async {
    try {
      // 1) Open file picker to choose an .xlsx file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        // user canceled
        return;
      }

      final filePath = result.files.single.path!;
      final fileBytes = File(filePath).readAsBytesSync();

      // 2) Decode Excel
      final excelFile = excel.Excel.decodeBytes(fileBytes);

      // 3) Use the first sheet
      if (excelFile.tables.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sheet found in Excel file')),
        );
        return;
      }

      final firstSheetName = excelFile.tables.keys.first;
      final sheet = excelFile.tables[firstSheetName]!;

      // 4) Clear existing list OR merge
      // If you want to CLEAR old models before importing, uncomment next line:
      // _models.clear();

      // 5) Loop through rows (skip header = row 0)
for (int i = 1; i < sheet.rows.length; i++) {
  final row = sheet.rows[i];

  if (row.isEmpty) continue;

  final cellNo   = row.isNotEmpty ? row[0] : null;
  final cellDesc = row.length > 1 ? row[1] : null;

  final no   = (cellNo?.value?.toString() ?? '').trim();
  final desc = (cellDesc?.value?.toString() ?? '').trim();

  if (no.isEmpty && desc.isEmpty) continue;

        // Check if model with same "no" already exists
        final index = _models.indexWhere((m) => m['no'] == no);
        final newModel = {'no': no, 'desc': desc};

        if (index >= 0) {
          // update existing
          _models[index] = newModel;
        } else {
          // add new
          _models.add(newModel);
        }
      }

      // 6) Save to SharedPreferences
      await _saveModels();

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Models imported from Excel successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing Excel: $e')),
      );
    }
  }

  /// 📤 EXPORT current models to an Excel file.
  ///
  /// File will be saved in app documents folder as: product_list.xlsx
  Future<void> _exportToExcel() async {
  try {
    if (_models.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No models to export')),
      );
      return;
    }

    // 1) Create Excel
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Products'];

    sheet.appendRow([
      excel.TextCellValue('Model No'),
      excel.TextCellValue('Description'),
    ]);

    for (final m in _models) {
      sheet.appendRow([
        excel.TextCellValue(m['no'] ?? ''),
        excel.TextCellValue(m['desc'] ?? ''),
      ]);
    }

    final bytes = excelFile.encode();
    if (bytes == null) return;

    // 2) SHOW SAVE FILE DIALOG (Windows / Android / iOS / Web)
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Product List Excel File',
      fileName: 'product_list.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputPath == null) {
      // User cancelled
      return;
    }

    // 3) Save the file
    final file = File(outputPath);
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported Successfully: $outputPath')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error exporting Excel: $e')),
    );
  }
}




  void _showAddEditDialog({String? initialNo, String? initialDesc}) {
    final noController = TextEditingController(text: initialNo ?? '');
    final descController = TextEditingController(text: initialDesc ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialNo == null ? 'Add Model' : 'Edit Model'),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final existingIndex =
                    _models.indexWhere((m) => m['no'] == noController.text);
                final newModel = {
                  'no': noController.text.trim(),
                  'desc': descController.text.trim(),
                };

                if (existingIndex >= 0) {
                  _models[existingIndex] = newModel;
                } else {
                  _models.add(newModel);
                }
// save button code
                await _saveModels();
if (!mounted) return;

if (!context.mounted) return; // 👈 New safety check

setState(() {});
Navigator.pop(context);

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Model "${noController.text}" saved permanently')),
);

              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Model',
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔹 Row with Import / Export buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _importFromExcel,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Import from Excel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export to Excel'),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 🔹 The existing list
          Expanded(
            child: _models.isEmpty
                ? const Center(child: Text('No models found.'))
                : ListView.separated(
                    itemCount: _models.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = _models[i];
                      final no = m['no'] ?? '';
                      final desc = m['desc'] ?? '';
                      return ListTile(
                        title: Text(no),
                        subtitle: Text(desc),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddEditDialog(
                                initialNo: no,
                                initialDesc: desc,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm'),
                                    content: Text('Delete "$no"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          _models.removeAt(i);
                                          await _saveModels();
if (!mounted || !context.mounted) {
  return;
}

setState(() {});
Navigator.pop(ctx);
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Model "$no" deleted'),
  ),
);
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardPage(toggleTheme: () {}),
              ),
              (route) => false,
            );
          },
          icon: const Icon(Icons.close),
          label: const Text('Close'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}