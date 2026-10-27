import '../widgets/service_language_scope.dart';
import '../utils/service_report_language.dart';
import '../widgets/remarks_field.dart';
import 'package:flutter/material.dart';
import '../auth/account_session.dart';
import '../models/service_checklist.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';

class ServiceReportBodyPage extends StatefulWidget {
  const ServiceReportBodyPage({super.key, this.languageCode = 'en'});
  final String languageCode;
  @override
  State<ServiceReportBodyPage> createState() => _ServiceReportBodyPageState();
}

class _ServiceReportBodyPageState extends State<ServiceReportBodyPage> {
  String _t(String text) =>
      ServiceReportLanguage(widget.languageCode).text(text);
  ServiceBodyTemplate? _template;
  final _heading = TextEditingController(), _work = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final template = await ServiceBodyTemplate.load();
      if (!mounted) return;
      setState(() {
        _template = template;
        _heading.text = _t(template.heading);
        _work.text = template.workDone == defaultServiceWork
            ? _t(template.workDone)
            : template.workDone;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _point({ServiceChecklistPoint? point}) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => ServiceLanguageScope(
        code: widget.languageCode,
        child: _PointDialog(
          initial: point?.text ?? '',
          languageCode: widget.languageCode,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (point != null) {
        point.text = result;
      } else {
        _template!.points.add(
          ServiceChecklistPoint(
            id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
            text: result,
          ),
        );
      }
    });
  }

  Future<void> _save() async {
    if (_heading.text.trim().isEmpty ||
        _template!.points.any((p) => p.text.trim().isEmpty)) {
      setState(
        () => _error =
            'Enter a report heading and names for all inspection points.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _template!
        ..heading = _heading.text.trim()
        ..workDone = _work.text.trim();
      await _template!.save();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _heading.dispose();
    _work.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('service')) return const AccessDenied();
    return ServiceLanguageScope(
      code: widget.languageCode,
      child: Builder(
        builder: (context) => AppScaffold(
          appBar: AppBar(title: Text(_t('Service report body'))),
          body: _template == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Text(_error!),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _heading,
                        decoration: InputDecoration(
                          labelText: _t('Report heading'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _t('Basic service checklist'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _t(
                          'Activate the inspection points you want on new reports. Add or edit points as needed. Saved reports keep their original checklist.',
                        ),
                      ),
                      for (final point in _template!.points)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: point.active,
                            onChanged: _saving
                                ? null
                                : (v) =>
                                      setState(() => point.active = v ?? false),
                          ),
                          title: Text(_t(point.text)),
                          trailing: IconButton(
                            tooltip: _t('Edit inspection point'),
                            onPressed: _saving
                                ? null
                                : () => _point(point: point),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _saving ? null : _point,
                        icon: const Icon(Icons.add),
                        label: Text(_t('Add inspection point')),
                      ),
                      const SizedBox(height: 16),
                      RemarksField(
                        controller: _work,
                        label: _t('Default work done / remarks'),
                        languageCode: widget.languageCode,
                        minLines: 3,
                        maxLines: 6,
                        enabled: !_saving,
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          _saving ? _t('Saving...') : _t('Save body settings'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PointDialog extends StatefulWidget {
  const _PointDialog({required this.initial, required this.languageCode});
  final String languageCode;
  final String initial;
  @override
  State<_PointDialog> createState() => _PointDialogState();
}

class _PointDialogState extends State<_PointDialog> {
  String _t(String text) =>
      ServiceReportLanguage(widget.languageCode).text(text);
  late final _text = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_t('Inspection point')),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(labelText: _t('Inspection point')),
        validator: (v) =>
            v == null || v.trim().isEmpty ? _t('Enter inspection point') : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_t('Cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _text.text.trim());
          }
        },
        child: Text(_t('Done')),
      ),
    ],
  );
}
