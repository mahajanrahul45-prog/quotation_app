import 'dart:convert';
import 'package:flutter/material.dart';
import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
import '../storage/cloud_preferences.dart';
import '../models/service_report.dart';
import '../models/service_checklist.dart';
import '../utils/service_report_language.dart';
import 'service_report_page.dart';
import 'service_report_print_page.dart';
import 'service_report_preview_page.dart';
import 'service_report_body_page.dart';

class SavedServiceReportsPage extends StatefulWidget {
  const SavedServiceReportsPage({super.key});
  @override
  State<SavedServiceReportsPage> createState() =>
      _SavedServiceReportsPageState();
}

class _SavedServiceReportsPageState extends State<SavedServiceReportsPage> {
  List<ServiceReport> _reports = [];
  final _search = TextEditingController();
  String _status = 'All statuses', _sort = 'Newest first';
  String? _error, _workspaceUid;
  bool _loading = true, _deleting = false;
  int? _sharing;
  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ServiceReport> _decode(String? stored) => stored == null
      ? []
      : (jsonDecode(stored) as List)
            .map((e) => ServiceReport.fromJson(Map<String, dynamic>.from(e)))
            .toList();
  String _englishStatus(ServiceReport r) =>
      const ServiceReportLanguage('en').text(r.liftStatus);
  Future<void> _loadReports() async {
    if (_deleting) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final prefs = await CloudPreferences.getInstance();
      final data = _decode(prefs.getString('service_reports'));
      if (!mounted) return;
      setState(() {
        _reports = data;
        _workspaceUid = prefs.uid;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Could not load online reports. Please retry.\n$e',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([ServiceReport? report]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ServiceReportPage(editReport: report)),
    );
    if (mounted) await _loadReports();
  }

  Future<void> _deleteReport(ServiceReport report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete service report?'),
        content: Text(
          'Report #${report.srNo}\n${report.buildingName}\n\nThis removes only this service report from your online workspace. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete report'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final prefs = await CloudPreferences.getInstance();
      if (prefs.uid != _workspaceUid) {
        throw StateError('Workspace changed. Reopen this page.');
      }
      final current = _decode(prefs.getString('service_reports'));
      final matches = current.where((r) => r.srNo == report.srNo).toList();
      if (matches.length != 1 ||
          jsonEncode(matches.single.toJson()) != jsonEncode(report.toJson())) {
        throw StateError(
          'This report changed. Refresh the list before deleting.',
        );
      }
      final remaining = current.where((r) => r.srNo != report.srNo).toList();
      await prefs.setString(
        'service_reports',
        jsonEncode(remaining.map((r) => r.toJson()).toList()),
      );
      if (!mounted) return;
      setState(() => _reports = remaining);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service report deleted.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete report: $e')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _shareReport(ServiceReport report) async {
    if (_sharing != null) return;
    setState(() => _sharing = report.srNo);
    try {
      await ServiceReportPrintPage.sharePdf(context, report);
    } finally {
      if (mounted) setState(() => _sharing = null);
    }
  }

  List<ServiceReport> get _visible {
    final query = _search.text.trim().toLowerCase();
    final result = _reports
        .where(
          (r) =>
              (_status == 'All statuses' || _englishStatus(r) == _status) &&
              (query.isEmpty ||
                  '${r.srNo} ${r.buildingName} ${r.location} ${r.serviceMonth} ${r.liftServiceDate} ${r.servicePersonName} ${r.nextServiceMonth}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    result.sort(
      (a, b) => _sort == 'Building A–Z'
          ? a.buildingName.toLowerCase().compareTo(b.buildingName.toLowerCase())
          : _sort == 'Oldest first'
          ? a.srNo.compareTo(b.srNo)
          : b.srNo.compareTo(a.srNo),
    );
    return result;
  }

  void _reset() {
    _search.clear();
    setState(() {
      _status = 'All statuses';
      _sort = 'Newest first';
    });
  }

  Widget _detail(IconData icon, String label, String value) => SizedBox(
    width: 210,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                value.trim().isEmpty ? 'Not recorded' : value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _card(ServiceReport r) {
    final scheme = Theme.of(context).colorScheme;
    final status = _englishStatus(r);
    final needsAttention =
        status == 'Out of service' || status == 'Working - attention required';
    return Card(
      key: ValueKey('saved_service_${r.srNo}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.apartment_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.buildingName.trim().isEmpty
                            ? 'Unnamed building'
                            : r.buildingName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Report #${r.srNo}  •  ${r.date.isEmpty ? "Date not recorded" : r.date}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (r.location.isNotEmpty)
                        Text(
                          r.location,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Report actions',
                  enabled: !_deleting,
                  onSelected: (v) {
                    if (v == 'delete') _deleteReport(r);
                    if (v == 'share') _shareReport(r);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Text('Share PDF'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete report',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: needsAttention
                        ? scheme.errorContainer
                        : scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: needsAttention
                          ? scheme.onErrorContainer
                          : scheme.onSecondaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    r.languageCode == 'hi' ? 'Hindi PDF' : 'English PDF',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    '${r.liftQty} ${r.liftQty == 1 ? "lift" : "lifts"}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                _detail(
                  Icons.calendar_month_outlined,
                  'Service month',
                  r.serviceMonth,
                ),
                _detail(
                  Icons.event_available_outlined,
                  'Lift serviced',
                  r.liftServiceDate,
                ),
                _detail(
                  Icons.event_repeat_outlined,
                  'Next service month',
                  r.nextServiceMonth,
                ),
                _detail(
                  Icons.person_outline,
                  'Service person',
                  r.servicePersonName,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceReportPreviewPage(report: r),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('View / print PDF'),
                ),
                TextButton.icon(
                  onPressed: _deleting ? null : () => _openEditor(r),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit report'),
                ),
                TextButton.icon(
                  onPressed: _sharing != null || _deleting
                      ? null
                      : () => _shareReport(r),
                  icon: _sharing == r.srNo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined, size: 18),
                  label: Text(
                    _sharing == r.srNo ? 'Preparing PDF...' : 'Share PDF',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('service')) return const AccessDenied();
    final visible = _visible;
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Saved Service Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh online reports',
            onPressed: _loading || _deleting ? null : _loadReports,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Service Page Body',
            icon: const Icon(Icons.description_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServiceReportBodyPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service records',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review visits, track lift status and open your saved reports.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${_reports.length} reports')),
                Chip(
                  label: Text(
                    '${_reports.where((r) => _englishStatus(r) == "Working - attention required" || _englishStatus(r) == "Out of service").length} need attention',
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading || _deleting ? null : () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('New report'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search reports',
                hintText: 'Building, report number, month or service person',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (_, constraints) {
                final status = DropdownButtonFormField<String>(
                  key: ValueKey('status_$_status'),
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lift status'),
                  items: ['All statuses', ...serviceLiftStatuses]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (s) =>
                      setState(() => _status = s ?? 'All statuses'),
                );
                final sort = DropdownButtonFormField<String>(
                  key: ValueKey('sort_$_sort'),
                  initialValue: _sort,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sort reports'),
                  items: ['Newest first', 'Oldest first', 'Building A–Z']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (s) => setState(() => _sort = s ?? 'Newest first'),
                );
                return constraints.maxWidth < 600
                    ? Column(
                        children: [status, const SizedBox(height: 14), sort],
                      )
                    : Row(
                        children: [
                          Expanded(child: status),
                          const SizedBox(width: 14),
                          Expanded(child: sort),
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 36),
                      const SizedBox(height: 12),
                      Text(_error!),
                      TextButton.icon(
                        onPressed: _loadReports,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (visible.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(Icons.description_outlined, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        _reports.isEmpty
                            ? 'No saved service reports yet'
                            : 'No matching reports',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _reports.isEmpty
                            ? 'Create your first service report to keep a record of the visit.'
                            : 'Try another search or clear the filters.',
                        textAlign: TextAlign.center,
                      ),
                      if (_reports.isNotEmpty)
                        TextButton(
                          onPressed: _reset,
                          child: const Text('Clear filters'),
                        ),
                    ],
                  ),
                ),
              )
            else ...[
              Text(
                'Showing ${visible.length} of ${_reports.length} reports',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              for (final report in visible) _card(report),
            ],
          ],
        ),
      ),
    );
  }
}
