class EmailTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;
  final String signature;

  EmailTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'body': body,
        'signature': signature,
      };

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    return EmailTemplate(
      id: json['id'],
      name: json['name'],
      subject: json['subject'],
      body: json['body'],
      signature: json['signature'],
    );
  }
}
