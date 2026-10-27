class PrintBodyTemplate {
  final String name;
  final String body;
  final String signature;
  final String signatureText2;
  final String? signatureImage; // base64
  final bool alignRight;
  final String subject; // 🔹 NEW

  final double signTextX;
final double signTextY;

final double signImageX;
final double signImageY;

final double signText2X;
final double signText2Y;

final double signImageScale;


  PrintBodyTemplate({
    required this.name,
    required this.subject,   // 🔹 NEW
    required this.body,
    required this.signature,
    required this.signatureText2,
    required this.alignRight,
    this.signatureImage,


    this.signTextX = 0,
  this.signTextY = 0,
  this.signImageX = 0,
  this.signImageY = 0,
  this.signText2X = 0,
  this.signText2Y = 0,

  // 🔹 NEW
  this.signImageScale = 1.0,
  });

  factory PrintBodyTemplate.fromJson(Map<String, dynamic> json) {
    return PrintBodyTemplate(
      name: json['name'] ?? '',
      subject: json['subject'] ?? '',
      body: json['body'] ?? '',
      signature: json['signature'] ?? '',
      signatureText2: json['signatureText2'] ?? '',
      signatureImage: json['signatureImage'],
      alignRight: json['alignRight'] ?? true,

      signTextX: (json['signTextX'] ?? 0).toDouble(),
signTextY: (json['signTextY'] ?? 0).toDouble(),
signImageX: (json['signImageX'] ?? 0).toDouble(),
signImageY: (json['signImageY'] ?? 0).toDouble(),
signText2X: (json['signText2X'] ?? 0).toDouble(),
signText2Y: (json['signText2Y'] ?? 0).toDouble(),

signImageScale: (json['signImageScale'] ?? 1.0).toDouble(),

    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'subject': subject,
        'body': body,
        'signature': signature,
        'signatureText2': signatureText2,
        'signatureImage': signatureImage,
        'alignRight': alignRight,

        'signTextX': signTextX,
'signTextY': signTextY,
'signImageX': signImageX,
'signImageY': signImageY,
'signText2X': signText2X,
'signText2Y': signText2Y,

'signImageScale': signImageScale,

      };
}
