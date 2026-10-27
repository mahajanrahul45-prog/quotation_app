import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../storage/cloud_preferences.dart';
import '../models/print_body_template.dart';
import 'package:file_picker/file_picker.dart';

const String kPrintTemplatesKey = 'print_body_templates';
const String kSelectedPrintTemplateKey = 'selected_print_body';

class PrintBodySettingsPage extends StatefulWidget {
  const PrintBodySettingsPage({super.key});

  @override
  State<PrintBodySettingsPage> createState() => _PrintBodySettingsPageState();
}

// 🔹 Signature Text 1 offsets
double signTextX = 0;
double signTextY = 0;

// 🔹 Signature Image offsets
double signImageX = 0;
double signImageY = 0;

// 🔹 Signature Text 2 offsets
double signText2X = 0;
double signText2Y = 0;

double signImageScale = 1.0; // 🔹 Signature image size (default)

class _PrintBodySettingsPageState extends State<PrintBodySettingsPage> {
  final TextEditingController subjectCtrl = TextEditingController(); // 🔹 NEW
  final TextEditingController bodyCtrl = TextEditingController();
  final TextEditingController signCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController sign2Ctrl = TextEditingController();
  String? signatureImageBase64;

  bool alignRight = true;

  List<PrintBodyTemplate> templates = [];
  String? selectedTemplate;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> savePrintBodyTemplate(Map<String, dynamic> data) async {
    final prefs = await CloudPreferences.getInstance();

    final list = prefs.getStringList(kPrintTemplatesKey) ?? [];

    // Remove old template with same name
    list.removeWhere((e) {
      final map = jsonDecode(e);
      return map['name'] == data['name'];
    });

    list.add(jsonEncode(data));

    await prefs.setStringList(kPrintTemplatesKey, list);

    // ✅ mark selected template
    await prefs.setString(kSelectedPrintTemplateKey, data['name']);
  }

  Future<void> _loadTemplates() async {
    final prefs = await CloudPreferences.getInstance();
    final raw = prefs.getStringList(kPrintTemplatesKey) ?? [];

    setState(() {
      templates = raw
          .map((e) => PrintBodyTemplate.fromJson(jsonDecode(e)))
          .toList();
    });

    // Auto-load selected template
    final selected = prefs.getString(kSelectedPrintTemplateKey);
    if (selected != null) {
      final match = templates.where((t) => t.name == selected);
      if (match.isNotEmpty) {
        _loadTemplate(match.first);
      }
    }
  }

  Future<void> _saveTemplate() async {
    if (nameCtrl.text.trim().isEmpty) return;

    final template = PrintBodyTemplate(
      name: nameCtrl.text.trim(),
      subject: subjectCtrl.text, // 🔹 NEW
      body: bodyCtrl.text,
      signature: signCtrl.text,
      signatureText2: sign2Ctrl.text,
      alignRight: alignRight,
      signatureImage: signatureImageBase64,

      // 🔹 NEW
      signImageScale: signImageScale,

      // 🔹 NEW offsets
      signTextX: signTextX,
      signTextY: signTextY,
      signImageX: signImageX,
      signImageY: signImageY,
      signText2X: signText2X,
      signText2Y: signText2Y,
    );

    await savePrintBodyTemplate(template.toJson());

    await _loadTemplates();

    if (!mounted) return;

    setState(() {
      selectedTemplate = template.name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template saved successfully')),
    );
  }

  void _loadTemplate(PrintBodyTemplate t) {
    setState(() {
      selectedTemplate = t.name;
      subjectCtrl.text = t.subject;
      bodyCtrl.text = t.body;
      signCtrl.text = t.signature;
      sign2Ctrl.text = t.signatureText2;
      alignRight = t.alignRight;
      nameCtrl.text = t.name;
      signatureImageBase64 = t.signatureImage;

      signImageScale = t.signImageScale;

      signTextX = t.signTextX;
      signTextY = t.signTextY;

      signImageX = t.signImageX;
      signImageY = t.signImageY;

      signText2X = t.signText2X;
      signText2Y = t.signText2Y;
    });
  }

  Future<Map<String, dynamic>?> loadSelectedPrintBodyTemplate() async {
    final prefs = await CloudPreferences.getInstance();

    final selected = prefs.getString(kSelectedPrintTemplateKey);
    if (selected == null) return null;

    final list = prefs.getStringList(kPrintTemplatesKey) ?? [];

    for (final item in list) {
      final map = jsonDecode(item);
      if (map['name'] == selected) return map;
    }

    return null;
  }

  Future<void> _deleteTemplate(String name) async {
    final prefs = await CloudPreferences.getInstance();

    templates.removeWhere((t) => t.name == name);

    await prefs.setStringList(
      kPrintTemplatesKey,
      templates.map((e) => jsonEncode(e.toJson())).toList(),
    );

    final selected = prefs.getString(kSelectedPrintTemplateKey);

    if (selected == name) {
      await prefs.remove(kSelectedPrintTemplateKey);
    }

    if (!mounted) return;

    setState(() {
      if (selectedTemplate == name) {
        selectedTemplate = null;
        bodyCtrl.clear();
        signCtrl.clear();
        sign2Ctrl.clear();
        nameCtrl.clear();
        signatureImageBase64 = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('settings')) return const AccessDenied();
    return AppScaffold(
      appBar: AppBar(title: const Text("Print Page Body")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            /// TEMPLATE SELECT
            DropdownButtonFormField<String>(
              initialValue: selectedTemplate,
              hint: const Text("Select Template"),
              items: templates
                  .map(
                    (t) => DropdownMenuItem(value: t.name, child: Text(t.name)),
                  )
                  .toList(),
              onChanged: (val) {
                final t = templates.firstWhere((e) => e.name == val);
                _loadTemplate(t);
              },
            ),

            const SizedBox(height: 10),

            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Template Name"),
            ),

            const SizedBox(height: 10),

            // 🔹 SUBJECT FIELD
            TextField(
              controller: subjectCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Subject (shown above body text)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            // 🔹 BODY FIELD
            TextField(
              controller: bodyCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Body Text (shown above table)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: signCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Signature Text"),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text("Upload Signature Image"),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,

                      // 🔥 REQUIRED to get bytes on Android / iOS
                      withData: true,
                    );

                    if (result != null) {
                      final file = result.files.single;

                      if (file.bytes != null) {
                        setState(() {
                          signatureImageBase64 = base64Encode(file.bytes!);
                        });

                        // Optional debug
                        debugPrint(
                          'Signature image loaded (${file.bytes!.length} bytes)',
                        );
                      } else {
                        debugPrint('❌ File bytes are null');
                      }
                    }
                  },
                ),
                const SizedBox(width: 12),
                if (signatureImageBase64 != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Signature Preview:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Image.memory(
                        base64Decode(signatureImageBase64!),
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                      // ✅ CLEAR IMAGE BUTTON
                      TextButton.icon(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Remove Image",
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () {
                          setState(() {
                            signatureImageBase64 = null;
                          });
                        },
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              "Signature Image Size",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            Slider(
              value: signImageScale,
              min: 0.5,
              max: 3.0,
              divisions: 10,
              label: signImageScale.toStringAsFixed(1),
              onChanged: (v) {
                setState(() {
                  signImageScale = v;
                });
              },
            ),

            const SizedBox(height: 10),

            TextField(
              controller: sign2Ctrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Signature Text 2 (below image)",
              ),
            ),

            // ======================================================
            // 🔹 SIGNATURE TEXT POSITION CONTROLS (Text-1)
            // ======================================================
            const SizedBox(height: 12),

            const Text(
              "Signature Text Position",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            // 🔹 Left / Right slider
            Row(
              children: [
                const SizedBox(width: 90, child: Text("Left / Right")),
                Expanded(
                  child: Slider(
                    value: signTextX,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: signTextX.toStringAsFixed(0),
                    onChanged: (v) => setState(() => signTextX = v),
                  ),
                ),
              ],
            ),

            // 🔹 Up / Down slider
            Row(
              children: [
                const SizedBox(width: 90, child: Text("Up / Down")),
                Expanded(
                  child: Slider(
                    value: signTextY,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: signTextY.toStringAsFixed(0),
                    onChanged: (v) => setState(() => signTextY = v),
                  ),
                ),
              ],
            ),

            // ======================================================
            // 🔹 SIGNATURE IMAGE POSITION CONTROLS
            // ======================================================
            const SizedBox(height: 16),

            const Text(
              "Signature Image Position",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            // 🔹 Left / Right slider
            Row(
              children: [
                const SizedBox(width: 90, child: Text("Left / Right")),
                Expanded(
                  child: Slider(
                    value: signImageX,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: signImageX.toStringAsFixed(0),
                    onChanged: (v) => setState(() => signImageX = v),
                  ),
                ),
              ],
            ),

            // 🔹 Up / Down slider
            Row(
              children: [
                const SizedBox(width: 90, child: Text("Up / Down")),
                Expanded(
                  child: Slider(
                    value: signImageY,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: signImageY.toStringAsFixed(0),
                    onChanged: (v) => setState(() => signImageY = v),
                  ),
                ),
              ],
            ),

            // ======================================================
            // 🔹 SIGNATURE TEXT-2 POSITION CONTROLS
            // ======================================================
            const SizedBox(height: 16),

            const Text(
              "Signature Text 2 Position",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            // 🔹 Left / Right slider
            Row(
              children: [
                const SizedBox(width: 90, child: Text("Left / Right")),
                Expanded(
                  child: Slider(
                    value: signText2X,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: signText2X.toStringAsFixed(0),
                    onChanged: (v) => setState(() => signText2X = v),
                  ),
                ),
              ],
            ),

            // 🔹 Up / Down slider
            Row(
              children: [
                const SizedBox(width: 90, child: Text("Up / Down")),
                Expanded(
                  child: Slider(
                    value: signText2Y,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: signText2Y.toStringAsFixed(0),
                    onChanged: (v) => setState(() => signText2Y = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            SwitchListTile(
              value: alignRight,
              title: const Text("Signature on Right Side"),
              onChanged: (v) => setState(() => alignRight = v),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _saveTemplate,
              icon: const Icon(Icons.save),
              label: const Text("Save Template"),
            ),

            const Divider(height: 30),

            const Text(
              "Saved Templates",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            ...templates.map(
              (t) => ListTile(
                title: Text(t.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _loadTemplate(t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTemplate(t.name),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
