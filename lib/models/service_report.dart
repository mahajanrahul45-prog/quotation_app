import 'service_checklist.dart';

class ServiceReport {
  int srNo;
  String date;
  String buildingName;
  String location;
  int liftQty; // ✅ NEW FIELD
  String serviceMonth;
  String liftServiceDate;
  String customerPersonName;
  String customerSignaturePath;
  String servicePersonName;
  String customerSignatureBase64; // ✅ NEW

  ServiceReport({
    this.languageCode = 'en_hi',
    this.heading = 'LIFT SERVICE REPORT',
    this.checklist = const [],
    this.workDone = '',
    this.liftStatus = 'Not assessed',
    this.nextServiceMonth = '',
    required this.srNo,
    required this.date,
    required this.buildingName,
    required this.location,
    required this.liftQty, // ✅ ADD HERE
    required this.serviceMonth,
    required this.liftServiceDate,
    required this.customerPersonName,
    required this.customerSignaturePath,
    required this.customerSignatureBase64, // ✅ ADD
    required this.servicePersonName,
  });

  String languageCode;
  String heading, workDone, liftStatus, nextServiceMonth;
  List<ServiceInspection> checklist;

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'heading': heading,
    'checklist': checklist.map((p) => p.toJson()).toList(),
    'workDone': workDone,
    'liftStatus': liftStatus,
    'nextServiceMonth': nextServiceMonth,
    'srNo': srNo,
    'date': date,
    'buildingName': buildingName,
    'location': location,
    'liftQty': liftQty, // ✅ ADD
    'serviceMonth': serviceMonth,
    'liftServiceDate': liftServiceDate,
    'customerPersonName': customerPersonName,
    'customerSignaturePath': customerSignaturePath,
    'customerSignatureBase64': customerSignatureBase64,

    'servicePersonName': servicePersonName,
  };

  factory ServiceReport.fromJson(Map<String, dynamic> json) {
    return ServiceReport(
      languageCode: const ['en', 'hi', 'en_hi'].contains(json['languageCode'])
          ? json['languageCode'] as String
          : 'en_hi',
      heading: json['heading'] ?? 'LIFT SERVICE REPORT',
      checklist: (json['checklist'] as List? ?? [])
          .map((p) => ServiceInspection.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      workDone: json['workDone'] ?? '',
      liftStatus: json['liftStatus'] ?? 'Not assessed',
      nextServiceMonth: json['nextServiceMonth'] ?? '',
      srNo: json['srNo'] ?? 0,
      date: json['date'] ?? '',
      buildingName: json['buildingName'] ?? '',
      location: json['location'] ?? '',
      liftQty: json['liftQty'] ?? 0, // ✅ SAFE DEFAULT
      serviceMonth: json['serviceMonth'] ?? '',
      liftServiceDate: json['liftServiceDate'] ?? '',
      customerPersonName: json['customerPersonName'] ?? '',
      customerSignaturePath: json['customerSignaturePath'] ?? '',
      customerSignatureBase64: json['customerSignatureBase64'] ?? '',

      servicePersonName: json['servicePersonName'] ?? '',
    );
  }
}
