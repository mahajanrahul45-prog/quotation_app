import 'dart:convert';
import '../storage/cloud_preferences.dart';

const defaultServiceWork =
    'Routine maintenance completed. Door operation checked, moving parts inspected, and lift operation tested.';
const serviceLiftStatuses = [
  'Not assessed',
  'Working Satisfactorily',
  'Working - attention required',
  'Out of service',
];

class ServiceInspection {
  ServiceInspection({
    required this.id,
    required this.point,
    this.ok = false,
    this.remarks = '',
    this.photoBase64 = '',
  });
  final String id;
  String point;
  bool ok;
  String remarks;
  String photoBase64;
  Map<String, dynamic> toJson() => {
    'id': id,
    'point': point,
    'ok': ok,
    'remarks': remarks,
    'photoBase64': photoBase64,
  };
  factory ServiceInspection.fromJson(Map<String, dynamic> map) =>
      ServiceInspection(
        id: map['id'] as String? ?? map['point'] as String? ?? '',
        point: map['point'] as String? ?? '',
        ok: map['ok'] == true,
        remarks: map['remarks'] as String? ?? '',
        photoBase64: map['photoBase64'] as String? ?? '',
      );
}

class ServiceChecklistPoint {
  ServiceChecklistPoint({
    required this.id,
    required this.text,
    this.active = true,
  });
  final String id;
  String text;
  bool active;
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'active': active};
  factory ServiceChecklistPoint.fromJson(Map<String, dynamic> map) =>
      ServiceChecklistPoint(
        id: map['id'] as String,
        text: map['text'] as String,
        active: map['active'] == true,
      );
}

class ServiceBodyTemplate {
  ServiceBodyTemplate({
    required this.points,
    this.heading = 'LIFT SERVICE REPORT',
    this.workDone = defaultServiceWork,
  });
  String heading, workDone;
  List<ServiceChecklistPoint> points;
  static const storageKey = 'service_body_template';
  factory ServiceBodyTemplate.defaults() => ServiceBodyTemplate(
    points: [
      ServiceChecklistPoint(id: 'door', text: 'Door operation'),
      ServiceChecklistPoint(id: 'running', text: 'Lift running / leveling'),
      ServiceChecklistPoint(id: 'motor', text: 'Machine / motor'),
      ServiceChecklistPoint(id: 'safety', text: 'Safety devices'),
      ServiceChecklistPoint(id: 'lighting', text: 'Car lighting / fan'),
      ServiceChecklistPoint(
        id: 'alarm',
        text: 'Emergency alarm',
        active: false,
      ),
      ServiceChecklistPoint(id: 'intercom', text: 'Intercom', active: false),
      ServiceChecklistPoint(
        id: 'overload',
        text: 'Overload device',
        active: false,
      ),
      ServiceChecklistPoint(
        id: 'room',
        text: 'Machine room cleanliness',
        active: false,
      ),
      ServiceChecklistPoint(
        id: 'rails',
        text: 'Guide rails / lubrication',
        active: false,
      ),
      ServiceChecklistPoint(id: 'panel', text: 'Control panel', active: false),
    ],
  );
  Map<String, dynamic> toJson() => {
    'heading': heading,
    'workDone': workDone,
    'points': points.map((p) => p.toJson()).toList(),
  };
  static Future<ServiceBodyTemplate> load() async {
    final prefs = await CloudPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return ServiceBodyTemplate.defaults();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return ServiceBodyTemplate(
      heading: map['heading'] as String? ?? 'LIFT SERVICE REPORT',
      workDone: map['workDone'] as String? ?? defaultServiceWork,
      points: (map['points'] as List)
          .map(
            (p) => ServiceChecklistPoint.fromJson(Map<String, dynamic>.from(p)),
          )
          .toList(),
    );
  }

  Future<void> save() async {
    final prefs = await CloudPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(toJson()));
  }

  List<ServiceInspection> newInspections() => points
      .where((p) => p.active)
      .map((p) => ServiceInspection(id: p.id, point: p.text))
      .toList();
}
