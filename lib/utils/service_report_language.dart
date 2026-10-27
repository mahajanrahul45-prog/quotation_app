import '../models/service_checklist.dart';

/// Translate standard report wording, never rewrite a customer's free text.
class ServiceReportLanguage {
  const ServiceReportLanguage(this.code);
  final String code;
  bool get isHindi => code == 'hi';
  bool get isBilingual => code == 'en_hi';
  String text(String original) {
    if (isBilingual) {
      for (final entry in hindi.entries) {
        if (original == '${entry.key} / ${entry.value}') return original;
        if (original == entry.key || original == entry.value) {
          return '${entry.key} / ${entry.value}';
        }
      }
      return original;
    }
    for (final entry in hindi.entries) {
      if (original == '${entry.key} / ${entry.value}') {
        return isHindi ? entry.value : entry.key;
      }
    }
    if (isHindi) return hindi[original] ?? original;
    for (final entry in hindi.entries) {
      if (entry.value == original) return entry.key;
    }
    return original;
  }

  String month(String original) {
    const english = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const translated = [
      'जनवरी',
      'फ़रवरी',
      'मार्च',
      'अप्रैल',
      'मई',
      'जून',
      'जुलाई',
      'अगस्त',
      'सितंबर',
      'अक्टूबर',
      'नवंबर',
      'दिसंबर',
    ];
    final words = original.split(' ');
    if (words.length != 2 || int.tryParse(words.last) == null) return original;
    var index = english.indexOf(words.first);
    if (index < 0) index = translated.indexOf(words.first);
    return index < 0
        ? original
        : '${isHindi ? translated[index] : english[index]} ${words.last}';
  }

  static const hindi = <String, String>{
    'Add photo': 'फ़ोटो जोड़ें',
    'Replace photo': 'फ़ोटो बदलें',
    'Remove photo': 'फ़ोटो हटाएँ',
    'View photo': 'फ़ोटो देखें',
    'Inspection photo': 'जाँच की फ़ोटो',
    'Choose from gallery': 'गैलरी से चुनें',
    'Take photo': 'फ़ोटो लें',
    'Choose from library': 'गैलरी से चुनें',
    'Capture photo': 'फ़ोटो खींचें',
    'Opening camera...': 'कैमरा खुल रहा है...',
    'Could not open the camera. Allow camera access in your browser, or choose a photo from your library.':
        'कैमरा नहीं खुल सका। ब्राउज़र में कैमरे की अनुमति दें या गैलरी से फ़ोटो चुनें।',
    'Close': 'बंद करें',
    'Could not attach photo': 'फ़ोटो जोड़ी नहीं जा सकी',
    'Could not load photo': 'फ़ोटो लोड नहीं हो सकी',
    'Photo is too large. Choose a smaller image.':
        'फ़ोटो बहुत बड़ी है। छोटी फ़ोटो चुनें।',
    'Service Report': 'सेवा रिपोर्ट',
    'Edit Service Report': 'सेवा रिपोर्ट संपादित करें',
    'LIFT SERVICE REPORT': 'लिफ्ट सेवा रिपोर्ट',
    'REPORT & BUILDING DETAILS': 'रिपोर्ट और भवन का विवरण',
    'BASIC SERVICE CHECKLIST': 'बुनियादी सेवा जाँच सूची',
    'WORK DONE / REMARKS': 'किया गया कार्य / टिप्पणियाँ',
    'LIFT STATUS & NEXT VISIT': 'लिफ्ट की स्थिति और अगली सेवा',
    'ACKNOWLEDGEMENT': 'पावती',
    'Sr No (Auto)': 'क्रमांक (स्वचालित)',
    'Report No.': 'रिपोर्ट क्रमांक',
    'DRAFT': 'प्रारूप',
    'Date': 'तारीख',
    'Customer / Building Name':
        '\u0917\u094d\u0930\u093e\u0939\u0915 / \u092d\u0935\u0928 \u0915\u093e \u0928\u093e\u092e',
    'Building Name': 'भवन का नाम',
    'Building name': 'भवन का नाम',
    'Building': 'भवन',
    'Location': 'स्थान',
    'Location / area': 'स्थान / क्षेत्र',
    'Service Month (MMM YYYY)': 'सेवा का माह और वर्ष',
    'Service month': 'सेवा का माह',
    'Lift Quantity': 'लिफ्ट की संख्या',
    'Lift quantity': 'लिफ्ट की संख्या',
    'Date Of Lift Serviced': 'लिफ्ट की सेवा की तारीख',
    'Lift serviced': 'लिफ्ट की सेवा की तारीख',
    'Door operation': 'दरवाजे का संचालन',
    'Lift running / leveling': 'लिफ्ट का संचालन / स्तर मिलान',
    'Machine / motor': 'मशीन / मोटर',
    'Safety devices': 'सुरक्षा उपकरण',
    'Car lighting / fan': 'लिफ्ट केबिन की रोशनी / पंखा',
    'Emergency alarm': 'आपातकालीन अलार्म',
    'Intercom': 'इंटरकॉम',
    'Overload device': 'अधिक भार सुरक्षा उपकरण',
    'Machine room cleanliness': 'मशीन कक्ष की साफ-सफाई',
    'Guide rails / lubrication': 'गाइड रेल / स्नेहन',
    'Control panel': 'नियंत्रण पैनल',
    'OK': 'ठीक',
    'Mark all OK': 'सभी को ठीक चिह्नित करें',
    'Not marked OK': 'ठीक चिह्नित नहीं',
    'Remarks (optional)': 'टिप्पणी (वैकल्पिक)',
    'Remarks': 'टिप्पणियाँ',
    'Inspection point': 'जाँच बिंदु',
    'Status': 'स्थिति',
    'Lift status': 'लिफ्ट की स्थिति',
    'Not assessed': 'जाँच नहीं की गई',
    'Working Satisfactorily': 'संतोषजनक रूप से चालू',
    'Working - attention required': 'चालू - ध्यान देना आवश्यक',
    'Out of service': 'सेवा में नहीं',
    'Next service month': 'अगली सेवा का माह',
    'Select month and year': 'माह और वर्ष चुनें',
    'Select Service Month': 'सेवा का माह चुनें',
    'Select next service month': 'अगली सेवा का माह चुनें',
    'Clear next service month': 'अगली सेवा का माह हटाएँ',
    'Customer / representative name': 'ग्राहक / प्रतिनिधि का नाम',
    'Customer Signature': 'ग्राहक के हस्ताक्षर',
    'Draw Signature': 'हस्ताक्षर बनाएँ',
    'Upload Signature': 'हस्ताक्षर अपलोड करें',
    'Service person name': 'सेवा कर्मचारी का नाम',
    'Service person': 'सेवा कर्मचारी',
    'SERVICE PERSON': 'सेवा कर्मचारी',
    'CUSTOMER / REPRESENTATIVE': 'ग्राहक / प्रतिनिधि',
    'Name': 'नाम',
    'Signature': 'हस्ताक्षर',
    'SAVE': 'सहेजें',
    'UPDATE': 'अपडेट करें',
    'Cancel': 'रद्द करें',
    'Save': 'सहेजें',
    'Clear': 'हटाएँ',
    'Done': 'पूर्ण',
    'Add building': 'भवन जोड़ें',
    'Save building': 'भवन सहेजें',
    'Saving building...': 'भवन सहेजा जा रहा है...',
    'Enter building name': 'भवन का नाम दर्ज करें',
    'Enter location': 'स्थान दर्ज करें',
    'Configure service checklist': 'सेवा जाँच सूची की सेटिंग',
    'Print Preview': 'प्रिंट पूर्वावलोकन',
    'Saved Service Reports': 'सहेजी गई सेवा रिपोर्ट',
    'Basic service checklist': 'बुनियादी सेवा जाँच सूची',
    'Activate the inspection points you want on new reports. Add or edit points as needed. Saved reports keep their original checklist.':
        'नई रिपोर्ट में दिखाने के लिए जाँच बिंदु सक्रिय करें। आवश्यकता अनुसार बिंदु जोड़ें या संपादित करें। सहेजी गई रिपोर्ट की जाँच सूची नहीं बदलेगी।',
    'Service report body': 'सेवा रिपोर्ट की सामग्री',
    'Report heading': 'रिपोर्ट का शीर्षक',
    'Default work done / remarks': 'कार्य / टिप्पणियों का डिफ़ॉल्ट विवरण',
    'Add inspection point': 'जाँच बिंदु जोड़ें',
    'Edit inspection point': 'जाँच बिंदु संपादित करें',
    'Enter inspection point': 'जाँच बिंदु दर्ज करें',
    'Save body settings': 'रिपोर्ट सामग्री की सेटिंग सहेजें',
    'Saving...': 'सहेजा जा रहा है...',
    'No active inspection points. Add points in Service report body.':
        'कोई सक्रिय जाँच बिंदु नहीं है। रिपोर्ट सामग्री में बिंदु जोड़ें।',
    'No checklist recorded for this report.':
        'इस रिपोर्ट में जाँच सूची दर्ज नहीं है।',
    'No work remarks recorded.': 'कार्य की टिप्पणियाँ दर्ज नहीं हैं।',
    'Service Report Preview': 'सेवा रिपोर्ट पूर्वावलोकन',
    'Download PDF': 'पीडीएफ डाउनलोड करें',
    'LIFT SERVICE REPORT | SERVICE RECORD': 'लिफ्ट सेवा रिपोर्ट | सेवा अभिलेख',
    defaultServiceWork:
        'नियमित रखरखाव पूरा किया गया। दरवाजे का संचालन जाँचा गया, चलने वाले पुर्जों का निरीक्षण किया गया और लिफ्ट के संचालन का परीक्षण किया गया।',
  };
}
