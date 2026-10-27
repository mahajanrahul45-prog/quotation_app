class Company {
  final String companyName;
  final String address;
  final String phone;
  final String contactPerson;
  final String email;
  final String website;
  final String gstin;

  final String bankCompanyName;
  final String bankName;
  final String accountNumber;
  final String branch;
  final String ifsc;

  // ================= NEW FONT FIELDS =================
  final String fontFamily;        // selected font name
  final bool bold;               // apply bold to all
  final bool italic;             // apply italic to all
  final bool underline;          // underline only company name
  final String anthem;           // company anthem / heading

  Company({
    required this.companyName,
    required this.address,
    required this.phone,
    required this.contactPerson,
    required this.email,
    required this.website,
    required this.gstin,

    required this.bankCompanyName,
    required this.bankName,
    required this.accountNumber,
    required this.branch,
    required this.ifsc,

    // 🔹 NEW REQUIRED PARAMETERS
    this.fontFamily = 'Default',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.anthem = '',
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      companyName: json['companyName'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      contactPerson: json['contactPerson'] ?? '',
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      gstin: json['gstin'] ?? '',

      bankCompanyName: json['bankCompanyName'] ?? '',
      bankName: json['bankName'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      branch: json['branch'] ?? '',
      ifsc: json['ifsc'] ?? '',

      // 🔹 FONT SETTINGS
      fontFamily: json['fontFamily'] ?? 'Default',
      bold: json['bold'] ?? false,
      italic: json['italic'] ?? false,
      underline: json['underline'] ?? false,
      anthem: json['anthem'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'address': address,
      'phone': phone,
      'contactPerson': contactPerson,
      'email': email,
      'website': website,
      'gstin': gstin,
      'bankCompanyName': bankCompanyName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'branch': branch,
      'ifsc': ifsc,

      // 🔹 SAVE FONT SETTINGS ALSO
    'fontFamily': fontFamily,
    'bold': bold,
    'italic': italic,
    'underline': underline,
    'anthem': anthem,
    };
  }
}
