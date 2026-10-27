import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../storage/cloud_preferences.dart';

/// =======================================================
/// MODEL: EMAIL TEMPLATE
/// =======================================================
class EmailTemplate {
  final String name;
  final String cc;
  final String subject;
  final String body;
  final String signature;
  final String? signatureImagePath;

  EmailTemplate({
    required this.name,
    required this.cc,
    required this.subject,
    required this.body,
    required this.signature,
    this.signatureImagePath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'cc': cc,
    'subject': subject,
    'body': body,
    'signature': signature,
    'signatureImagePath': signatureImagePath,
  };

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    return EmailTemplate(
      name: json['name'] ?? '',
      cc: json['cc'] ?? '',
      subject: json['subject'] ?? '',
      body: json['body'] ?? '',
      signature: json['signature'] ?? '',
      signatureImagePath: json['signatureImagePath'],
    );
  }
}

/// =======================================================
/// PAGE: MAIL SETTINGS
/// =======================================================
class MailSettingsPage extends StatefulWidget {
  const MailSettingsPage({super.key});

  @override
  State<MailSettingsPage> createState() => _MailSettingsPageState();
}

class _MailSettingsPageState extends State<MailSettingsPage> {
  // Controllers
  final templateNameCtrl = TextEditingController();
  final ccCtrl = TextEditingController();
  final subjectCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  final signatureCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  List<EmailTemplate> templates = [];
  EmailTemplate? selectedTemplate;
  File? signatureImage;

  // ✔ Active template
  String? activeTemplateName;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  /// ===================================================
  /// LOAD TEMPLATES
  /// ===================================================
  Future<void> _loadTemplates() async {
    final prefs = await CloudPreferences.getInstance();
    final list = prefs.getStringList('email_templates') ?? [];
    activeTemplateName = prefs.getString('selected_email_template');

    templates = list.map((e) => EmailTemplate.fromJson(jsonDecode(e))).toList();

    if (templates.isNotEmpty) {
      final selected = templates.firstWhere(
        (t) => t.name == activeTemplateName,
        orElse: () => templates.first,
      );
      await _selectTemplate(selected);
    }

    if (!mounted) return;
    setState(() {});
  }

  /// ===================================================
  /// SELECT + ACTIVATE TEMPLATE
  /// ===================================================
  Future<void> _selectTemplate(EmailTemplate t) async {
    setState(() {
      selectedTemplate = t;
      activeTemplateName = t.name;

      templateNameCtrl.text = t.name;
      ccCtrl.text = t.cc;
      subjectCtrl.text = t.subject;
      bodyCtrl.text = t.body;
      signatureCtrl.text = t.signature;
      signatureImage = t.signatureImagePath != null
          ? File(t.signatureImagePath!)
          : null;
    });

    final prefs = await CloudPreferences.getInstance();
    await prefs.setString('selected_email_template', t.name);
  }

  /// ===================================================
  /// SAVE TEMPLATE
  /// ===================================================
  Future<void> _saveTemplate() async {
    if (templateNameCtrl.text.trim().isEmpty) return;

    final template = EmailTemplate(
      name: templateNameCtrl.text.trim(),
      cc: ccCtrl.text.trim(),
      subject: subjectCtrl.text.trim(),
      body: bodyCtrl.text.trim(),
      signature: signatureCtrl.text.trim(),
      signatureImagePath: signatureImage?.path,
    );

    templates.removeWhere((t) => t.name == template.name);
    templates.add(template);

    final prefs = await CloudPreferences.getInstance();
    await prefs.setStringList(
      'email_templates',
      templates.map((e) => jsonEncode(e.toJson())).toList(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Template saved & activated')));

    await _selectTemplate(template);
  }

  /// ===================================================
  /// DELETE TEMPLATE
  /// ===================================================
  Future<void> _deleteTemplate(EmailTemplate t) async {
    templates.removeWhere((e) => e.name == t.name);

    final prefs = await CloudPreferences.getInstance();
    await prefs.setStringList(
      'email_templates',
      templates.map((e) => jsonEncode(e.toJson())).toList(),
    );

    if (!mounted) return;

    if (templates.isNotEmpty) {
      await _selectTemplate(templates.first);
    } else {
      templateNameCtrl.clear();
      ccCtrl.clear();
      subjectCtrl.clear();
      bodyCtrl.clear();
      signatureCtrl.clear();
      signatureImage = null;
      activeTemplateName = null;
      selectedTemplate = null;
    }

    setState(() {});
  }

  /// ===================================================
  /// PICK SIGNATURE IMAGE
  /// ===================================================
  Future<void> _pickSignatureImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      signatureImage = File(picked.path);
    });
  }

  /// ===================================================
  /// VIEW TEMPLATES (✔ SAFE)
  /// ===================================================
  void _showTemplatesDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Saved Templates'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: templates.length,
            itemBuilder: (_, i) {
              final t = templates[i];
              return ListTile(
                leading: Icon(
                  t.name == activeTemplateName
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: t.name == activeTemplateName
                      ? Colors.green
                      : Colors.grey,
                ),
                title: Text(t.name),

                // ✅ CLOSE FIRST → THEN ASYNC
                onTap: () {
                  Navigator.pop(dialogCtx);
                  _selectTemplate(t);
                },

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        _selectTemplate(t);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        await _deleteTemplate(t);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// ===================================================
  /// UI
  /// ===================================================
  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('settings')) return const AccessDenied();
    return AppScaffold(
      appBar: AppBar(title: const Text('Mail Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔽 TEMPLATE DROPDOWN
            DropdownButtonFormField<EmailTemplate>(
              initialValue: selectedTemplate,
              decoration: const InputDecoration(
                labelText: 'Select Template',
                border: OutlineInputBorder(),
              ),
              items: templates
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (t) {
                if (t != null) _selectTemplate(t);
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: templateNameCtrl,
              decoration: const InputDecoration(labelText: 'Template Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ccCtrl,
              decoration: const InputDecoration(labelText: 'CC'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Body'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: signatureCtrl,
              decoration: const InputDecoration(labelText: 'Signature'),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('Add Signature Image'),
                  onPressed: _pickSignatureImage,
                ),
                if (signatureImage != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(Icons.check_circle, color: Colors.green),
                  ),
              ],
            ),

            if (signatureImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Image.file(signatureImage!, height: 80),
              ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _saveTemplate,
                  child: const Text('Save'),
                ),
                ElevatedButton(
                  onPressed: _showTemplatesDialog,
                  child: const Text('View Templates'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
