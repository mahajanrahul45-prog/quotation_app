import 'dart:convert';
import 'cloud_preferences.dart';
import '../models/email_template.dart';

class EmailTemplateStorage {
  static const _key = 'email_templates';

  static Future<List<EmailTemplate>> loadTemplates() async {
    final prefs = await CloudPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];

    return stored
        .map((e) => EmailTemplate.fromJson(jsonDecode(e)))
        .toList();
  }

  static Future<void> saveTemplate(EmailTemplate template) async {
    final prefs = await CloudPreferences.getInstance();
    final list = await loadTemplates();

    final index = list.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      list[index] = template;
    } else {
      list.add(template);
    }

    await prefs.setStringList(
      _key,
      list.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
