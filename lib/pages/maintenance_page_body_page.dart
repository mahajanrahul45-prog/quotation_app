import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../storage/cloud_preferences.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class MaintenancePageBodyPage extends StatefulWidget {
  const MaintenancePageBodyPage({super.key});

  @override
  State<MaintenancePageBodyPage> createState() =>
      _MaintenancePageBodyPageState();
}

class _MaintenancePageBodyPageState extends State<MaintenancePageBodyPage> {
  static const String _templatesKey = 'maintenance_body_templates';
  static const String _selectedTemplateKey =
      'selected_maintenance_body_template';

  // =====================================================
  // 🔹 TEXT CONTROLLERS
  // =====================================================
  final _textCtrls = List.generate(16, (_) => TextEditingController());
  final templateNameCtrl = TextEditingController();
  final templateSearchCtrl = TextEditingController();

  List<Map<String, dynamic>> templates = [];
  String? selectedTemplateName;

  // =====================================================
  // 🔹 SIGNATURE SETTINGS
  // =====================================================
  bool signAlignRight = true; // Signature position
  bool accAlignRight = true; // Accepted Customer position

  // =====================================================
  // 🔹 TITLE VISIBILITY TOGGLE
  // =====================================================
  bool showTitle = false;

  final signText1Ctrl = TextEditingController();
  final signText2Ctrl = TextEditingController();

  String? signatureBase64;

  double signText1X = 0, signText1Y = 0;
  double signImageX = 0, signImageY = 0;
  double signText2X = 0, signText2Y = 0;

  // 🔹 Accepted Customer block position
  double accBlockX = 0;
  double accBlockY = 0;

  // =====================================================
  // 🔹 INIT
  // =====================================================
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadTemplates();
    await _loadData();
  }

  // =====================================================
  // 🔹 LOAD SAVED DATA
  // =====================================================
  Future<void> _loadData() async {
    final prefs = await CloudPreferences.getInstance();

    // 🔴 TEMP FIX — CLEAN OLD BAD VALUES
    signText1Y = signText1Y.clamp(0, 80);
    signImageY = signImageY.clamp(0, 80);
    signText2Y = signText2Y.clamp(0, 80);
    accBlockY = accBlockY.clamp(0, 80);

    for (int i = 0; i < 16; i++) {
      _textCtrls[i].text = prefs.getString('m_body_text${i + 1}') ?? '';
    }

    signAlignRight = prefs.getBool('m_sign_align_right') ?? true;

    accAlignRight = prefs.getBool('m_acc_align_right') ?? true;

    // 🔹 Load title visibility
    showTitle = prefs.getBool('m_show_title') ?? false;

    signText1Ctrl.text = prefs.getString('m_sign_text1') ?? '';
    signText2Ctrl.text = prefs.getString('m_sign_text2') ?? '';

    signatureBase64 = prefs.getString('m_sign_image');

    signText1X = prefs.getDouble('m_sign_text1_x') ?? 0;
    signText1Y = prefs.getDouble('m_sign_text1_y') ?? 0;
    signImageX = prefs.getDouble('m_sign_image_x') ?? 0;
    signImageY = prefs.getDouble('m_sign_image_y') ?? 0;
    signText2X = prefs.getDouble('m_sign_text2_x') ?? 0;
    signText2Y = prefs.getDouble('m_sign_text2_y') ?? 0;

    accBlockX = prefs.getDouble('m_acc_block_x') ?? 0;
    accBlockY = prefs.getDouble('m_acc_block_y') ?? 0;

    selectedTemplateName = prefs.getString(_selectedTemplateKey);
    templateSearchCtrl.text = selectedTemplateName ?? '';
    templateNameCtrl.text = selectedTemplateName ?? '';

    setState(() {});
  }

  Future<void> _loadTemplates() async {
    final prefs = await CloudPreferences.getInstance();
    final raw = prefs.getStringList(_templatesKey) ?? [];

    templates = raw
        .map((e) {
          try {
            return jsonDecode(e) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((e) => (e['name'] ?? '').toString().trim().isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _currentTemplateData(String name) {
    return {
      'name': name,
      'texts': _textCtrls.map((c) => c.text).toList(),
      'signAlignRight': signAlignRight,
      'accAlignRight': accAlignRight,
      'showTitle': showTitle,
      'signText1': signText1Ctrl.text,
      'signText2': signText2Ctrl.text,
      'signatureImage': signatureBase64,
      'signText1X': signText1X,
      'signText1Y': signText1Y,
      'signImageX': signImageX,
      'signImageY': signImageY,
      'signText2X': signText2X,
      'signText2Y': signText2Y,
      'accBlockX': accBlockX,
      'accBlockY': accBlockY,
    };
  }

  Future<void> _persistCurrentFields(CloudPreferences prefs) async {
    for (int i = 0; i < 16; i++) {
      await prefs.setString('m_body_text${i + 1}', _textCtrls[i].text);
    }

    await prefs.setBool('m_sign_align_right', signAlignRight);
    await prefs.setBool('m_acc_align_right', accAlignRight);
    await prefs.setBool('m_show_title', showTitle);
    await prefs.setString('m_sign_text1', signText1Ctrl.text);
    await prefs.setString('m_sign_text2', signText2Ctrl.text);

    if (signatureBase64 != null) {
      await prefs.setString('m_sign_image', signatureBase64!);
    } else {
      await prefs.remove('m_sign_image');
    }

    await prefs.setDouble('m_sign_text1_x', signText1X);
    await prefs.setDouble('m_sign_text1_y', signText1Y);
    await prefs.setDouble('m_sign_image_x', signImageX);
    await prefs.setDouble('m_sign_image_y', signImageY);
    await prefs.setDouble('m_sign_text2_x', signText2X);
    await prefs.setDouble('m_sign_text2_y', signText2Y);
    await prefs.setDouble('m_acc_block_x', accBlockX);
    await prefs.setDouble('m_acc_block_y', accBlockY);
  }

  void _applyTemplate(Map<String, dynamic> template) {
    final texts = (template['texts'] as List?) ?? const [];

    setState(() {
      for (int i = 0; i < 16; i++) {
        _textCtrls[i].text = i < texts.length ? texts[i].toString() : '';
      }

      signAlignRight = template['signAlignRight'] ?? true;
      accAlignRight = template['accAlignRight'] ?? true;
      showTitle = template['showTitle'] ?? false;
      signText1Ctrl.text = template['signText1'] ?? '';
      signText2Ctrl.text = template['signText2'] ?? '';
      signatureBase64 = template['signatureImage'];
      signText1X = (template['signText1X'] ?? 0).toDouble();
      signText1Y = (template['signText1Y'] ?? 0).toDouble();
      signImageX = (template['signImageX'] ?? 0).toDouble();
      signImageY = (template['signImageY'] ?? 0).toDouble();
      signText2X = (template['signText2X'] ?? 0).toDouble();
      signText2Y = (template['signText2Y'] ?? 0).toDouble();
      accBlockX = (template['accBlockX'] ?? 0).toDouble();
      accBlockY = (template['accBlockY'] ?? 0).toDouble();

      selectedTemplateName = template['name'];
      templateSearchCtrl.text = selectedTemplateName ?? '';
      templateNameCtrl.text = selectedTemplateName ?? '';
    });
  }

  Future<void> _selectTemplate(Map<String, dynamic> template) async {
    _applyTemplate(template);

    final prefs = await CloudPreferences.getInstance();
    await prefs.setString(_selectedTemplateKey, template['name']);
    await _persistCurrentFields(prefs);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template "${template['name']}" selected')),
    );
  }

  Future<void> _showTemplateSearch() async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        var filtered = List<Map<String, dynamic>>.from(templates);
        final searchCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Template'),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search template...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filtered = templates.where((template) {
                            final name = (template['name'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(value.toLowerCase());
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No templates found'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final template = filtered[index];
                                final name = template['name'] ?? '';
                                return ListTile(
                                  title: Text(name),
                                  trailing: selectedTemplateName == name
                                      ? const Icon(Icons.check)
                                      : null,
                                  onTap: () => Navigator.pop(context, template),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      await _selectTemplate(selected);
    }
  }

  Future<void> _clearAll() async {
    setState(() {
      for (final ctrl in _textCtrls) {
        ctrl.clear();
      }

      templateNameCtrl.clear();
      templateSearchCtrl.clear();
      selectedTemplateName = null;
      signAlignRight = true;
      accAlignRight = true;
      showTitle = false;
      signText1Ctrl.clear();
      signText2Ctrl.clear();
      signatureBase64 = null;
      signText1X = 0;
      signText1Y = 0;
      signImageX = 0;
      signImageY = 0;
      signText2X = 0;
      signText2Y = 0;
      accBlockX = 0;
      accBlockY = 0;
    });

    final prefs = await CloudPreferences.getInstance();
    await prefs.remove(_selectedTemplateKey);
    await _persistCurrentFields(prefs);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All fields cleared')));
  }

  // =====================================================
  // 🔹 SAVE DATA
  // =====================================================
  Future<void> _saveData() async {
    final prefs = await CloudPreferences.getInstance();
    await _persistCurrentFields(prefs);

    final templateName = templateNameCtrl.text.trim();
    if (templateName.isNotEmpty) {
      final template = _currentTemplateData(templateName);

      templates.removeWhere((e) => e['name'] == templateName);
      templates.add(template);
      templates.sort(
        (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
          (b['name'] ?? '').toString().toLowerCase(),
        ),
      );

      await prefs.setStringList(
        _templatesKey,
        templates.map((e) => jsonEncode(e)).toList(),
      );
      await prefs.setString(_selectedTemplateKey, templateName);

      selectedTemplateName = templateName;
      templateSearchCtrl.text = templateName;
    }

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          templateName.isEmpty
              ? 'Saved current settings'
              : 'Template "$templateName" saved successfully',
        ),
      ),
    );
  }

  // =====================================================
  // 🔹 PICK SIGNATURE IMAGE
  // =====================================================
  Future<void> _pickSignature() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      final bytes = await File(file.path).readAsBytes();
      setState(() {
        signatureBase64 = base64Encode(bytes);
      });
    }
  }

  // =====================================================
  // 🔹 EXPORT TEXT 1 → 16 TO EXCEL
  // =====================================================
  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Maintenance Body'];

    // 🔹 Header row
    sheet.appendRow([TextCellValue('Field'), TextCellValue('Value')]);

    // 🔹 Write Text 1 → Text 16
    for (int i = 0; i < 16; i++) {
      sheet.appendRow([
        TextCellValue('Text ${i + 1}'),
        TextCellValue(_textCtrls[i].text),
      ]);
    }

    // 🔹 Ask where to save
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Maintenance Body Excel',
      fileName: 'maintenance_body.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (path == null) return;

    final fileBytes = excel.encode();
    if (fileBytes == null) return;

    final file = File(path);
    await file.writeAsBytes(fileBytes);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel exported successfully')),
    );
  }

  // =====================================================
  // 🔹 IMPORT TEXT 1 → 16 FROM EXCEL
  // =====================================================
  Future<void> _importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();

    final excel = Excel.decodeBytes(bytes);

    final sheet = excel.tables.values.first;

    // 🔹 Expect format:
    // Column A = Text 1, Text 2...
    // Column B = value
    for (int i = 1; i <= 16; i++) {
      if (sheet.rows.length > i) {
        final cell = sheet.rows[i][1];
        _textCtrls[i - 1].text = cell?.value?.toString() ?? '';
      }
    }

    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel imported successfully')),
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
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Maintenance Page Body'),
        actions: [
          // 📥 IMPORT FROM EXCEL
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from Excel',
            onPressed: _importFromExcel,
          ),

          // 📤 EXPORT TO EXCEL
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _exportToExcel,
          ),

          // 💾 SAVE TO PREFS
          IconButton(icon: const Icon(Icons.save), onPressed: _saveData),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: templateSearchCtrl,
            readOnly: true,
            onTap: _showTemplateSearch,
            decoration: const InputDecoration(
              labelText: 'Search / Select Template',
              hintText: 'Tap to search saved templates',
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.arrow_drop_down),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: templateNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Template Name',
              hintText: 'Enter name to save this body as template',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          // =====================================================
          // 🔹 TEXT 1 → TEXT 16
          // =====================================================
          for (int i = 0; i < 16; i++) ...[
            TextField(
              controller: _textCtrls[i],

              // ✅ MULTI-LINE RULES
              minLines: (i == 0 || i == 12) ? 3 : 1,
              maxLines: (i == 0 || i == 12) ? 5 : 1,

              keyboardType: (i == 0 || i == 12)
                  ? TextInputType.multiline
                  : TextInputType.text,

              textInputAction: (i == 0 || i == 12)
                  ? TextInputAction.newline
                  : TextInputAction.done,

              decoration: InputDecoration(
                labelText: 'Text ${i + 1} Body',
                border: const OutlineInputBorder(),
                alignLabelWithHint: (i == 0 || i == 12),
              ),
            ),

            const SizedBox(height: 10),
          ],

          const Divider(),

          // =====================================================
          // 🔹 TITLE VISIBILITY
          // =====================================================
          SwitchListTile(
            title: const Text('Show Title in PDF & Print Preview'),
            subtitle: const Text('Show / hide Maintenance title'),
            value: showTitle,
            onChanged: (v) => setState(() => showTitle = v),
          ),

          const Divider(),

          // =====================================================
          // 🔹 SIGNATURE ALIGNMENT
          // =====================================================
          SwitchListTile(
            title: const Text('Signature on Right'),
            value: signAlignRight,
            onChanged: (v) => setState(() => signAlignRight = v),
          ),

          // =====================================================
          // 🔹 ACCEPTED CUSTOMER ALIGNMENT
          // =====================================================
          SwitchListTile(
            title: const Text('Accepted Customer on Right'),
            value: accAlignRight,
            onChanged: (v) => setState(() => accAlignRight = v),
          ),

          const SizedBox(height: 10),

          // =====================================================
          // 🔹 SIGNATURE TEXT 1
          // =====================================================
          TextField(
            controller: signText1Ctrl,

            // ✅ ALLOW MULTI-LINE
            maxLines: 2, // EXACTLY 2 LINES
            minLines: 2,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,

            decoration: const InputDecoration(
              labelText: 'Signature Text 1 (2 lines)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 10),

          // =====================================================
          // 🔹 SIGNATURE IMAGE
          // =====================================================
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickSignature,
                icon: const Icon(Icons.image),
                label: const Text('Upload Signature'),
              ),
              const SizedBox(width: 12),
              if (signatureBase64 != null)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),

          const SizedBox(height: 10),

          // =====================================================
          // 🔹 SIGNATURE TEXT 2
          // =====================================================
          TextField(
            controller: signText2Ctrl,

            // ✅ ALLOW MULTI-LINE
            maxLines: 3, // EXACTLY 3 LINES
            minLines: 3,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,

            decoration: const InputDecoration(
              labelText: 'Signature Text 2 (3 lines)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),

          const Divider(),

          // =====================================================
          // 🔹 POSITION CONTROLS
          // =====================================================
          _posSlider(
            'Text1 X',
            signText1X,
            (v) => setState(() => signText1X = v),
          ),
          _posSlider(
            'Text1 Y',
            signText1Y,
            (v) => setState(() => signText1Y = v),
          ),
          _posSlider(
            'Image X',
            signImageX,
            (v) => setState(() => signImageX = v),
          ),
          _posSlider(
            'Image Y',
            signImageY,
            (v) => setState(() => signImageY = v),
          ),
          _posSlider(
            'Text2 X',
            signText2X,
            (v) => setState(() => signText2X = v),
          ),
          _posSlider(
            'Text2 Y',
            signText2Y,
            (v) => setState(() => signText2Y = v),
          ),

          const Divider(),
          const Text(
            'Accepted Customer Position',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          _posSlider(
            'Accepted X',
            accBlockX,
            (v) => setState(() => accBlockX = v),
          ),
          _posSlider(
            'Accepted Y',
            accBlockY,
            (v) => setState(() => accBlockY = v),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Template'),
            onPressed: _saveData,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear All'),
            onPressed: _clearAll,
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 🔹 POSITION SLIDER WIDGET
  // =====================================================
  Widget _posSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    // 🔹 Y-axis sliders must not enter header
    final bool isY = label.contains('Y');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label : ${value.toStringAsFixed(1)}'),

        Slider(
          // ✅ SAFE LIMITS FOR BODY-FLOW SIGNATURE
          min: 0,
          max: isY ? 80 : 30, // Y = vertical space, X = horizontal padding

          value: value.clamp(0, isY ? 80 : 30),

          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final ctrl in _textCtrls) {
      ctrl.dispose();
    }
    templateNameCtrl.dispose();
    templateSearchCtrl.dispose();
    signText1Ctrl.dispose();
    signText2Ctrl.dispose();
    super.dispose();
  }
}
