// lib/data/product_catalog.dart
class ProductCatalog {
  // ✅ Single consistent list to hold all product models
  static final List<Map<String, String>> _products = [];

  // ✅ Add or update a model (used in ProductListPage)
  static void addOrUpdateModel(String modelNo, String desc) {
    final existing = _products.indexWhere((p) => p['modelNo'] == modelNo);
    if (existing != -1) {
      _products[existing]['desc'] = desc;
    } else {
      _products.add({'modelNo': modelNo, 'desc': desc});
    }
  }

  // ✅ Get all products as list of maps
  static List<Map<String, String>> getAllProducts() => _products;

  // ✅ Get all model numbers for dropdowns
  static List<String> modelNumbers() {
    return _products.map((p) => p['modelNo']!).toList();
  }

  // ✅ Get description for a given model number
  static String? getDescription(String? modelNo) {
    if (modelNo == null) return null;
    final match = _products.firstWhere(
      (p) => p['modelNo'] == modelNo,
      orElse: () => {'desc': ''},
    );
    return match['desc'];
  }
}
