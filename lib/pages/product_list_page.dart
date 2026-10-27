import '../auth/account_session.dart';
import '../widgets/access_denied.dart';
import '../widgets/app_scaffold.dart';
// lib/pages/product_list_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../storage/cloud_preferences.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import '../pages/dashboard_page.dart';
import 'dart:typed_data';

/// =====================================================
/// 🔐 SHARED PREFERENCES STORAGE KEYS
/// =====================================================
/// Keep all keys in ONE place to avoid spelling mistakes
/// and data corruption.
/// =====================================================

// Product master list (all models)
const String kProductsKey = 'models';

// Category master list
const String kCategoriesKey = 'product_categories';

// Make list per category (Map<String, List<String>>)
const String kCategoryMakesKey = 'category_makes';

/// =====================================================
/// 📦 PRODUCT MODEL CLASS (ADD HERE)
/// =====================================================
class Product {
  String no;
  String desc;
  double lp;
  double sp;
  double bp;
  double moqQty;
  double moqPrice;
  String category;
  String make;

  Product({
    required this.no,
    required this.desc,
    required this.lp,
    required this.sp,
    required this.bp,
    required this.moqQty,
    required this.moqPrice,
    required this.category,
    required this.make,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      no: json['no'] ?? '',
      desc: json['desc'] ?? '',
      lp: (json['lp'] ?? 0).toDouble(),
      sp: (json['sp'] ?? 0).toDouble(),
      bp: (json['bp'] ?? 0).toDouble(),
      moqQty: (json['moqQty'] ?? 0).toDouble(),
      moqPrice: (json['moqPrice'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      make: json['make'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'no': no,
      'desc': desc,
      'lp': lp,
      'sp': sp,
      'bp': bp,
      'moqQty': moqQty,
      'moqPrice': moqPrice,
      'category': category,
      'make': make,
    };
  }
}

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  /// ----------------------------------------------------
  /// PRODUCT MASTER LIST (7 COLUMNS)
  /// ----------------------------------------------------
  /// Each product map structure:
  /// {
  ///   'no'       : Model No
  ///   'desc'     : Model Description
  ///   'lp'       : List Price
  ///   'sp'       : Special Price
  ///   'bp'       : Basic / Purchase Price
  ///   'category' : Category Name (backend filter)
  ///   'make'     : Make Name (backend filter)
  /// }
  ///
  /// NOTE:
  /// - Category & Make are NOT shown in quotation table
  /// - Used ONLY for filtering in Edit Product popup
  /// - Stored permanently in CloudPreferences
  /// ----------------------------------------------------
  /// =====================================================
  /// 📦 PRODUCT MASTER LIST (7 FIELDS)
  /// =====================================================
  List<Map<String, dynamic>> _models = [];

  /*
Each model structure:
{
  'no'       : String,   // Model No
  'desc'     : String,   // Description
  'lp'       : double,   // List Price
  'sp'       : double,   // Special Price
  'bp'       : double,   // Basic / Purchase Price
  'category' : String,   // Category
  'make'     : String,   // Make
}
*/

  /// =====================================================
  /// 📦 CATEGORY & MAKE DATA (IN MEMORY)
  /// =====================================================
  /// These are used ONLY for filtering & selection logic.
  /// They are NOT shown directly on quotation page UI.
  /// =====================================================

  // Category list
  List<String> _categories = [];

  // Category → Makes mapping
  // Example:
  // {
  //   "Motor": ["ABB", "Siemens"],
  //   "VFD": ["Delta", "INVT"]
  // }
  Map<String, List<String>> _categoryMakes = {};

  // search text + controller for the small search box
  final TextEditingController searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _loadModels(); // existing product list
    _loadCategories(); // ✅ NEW
    _loadCategoryMakes(); // ✅ NEW
  }

  void _showMoqDialog(Map<String, dynamic> model) {
    final qtyCtrl = TextEditingController(
      text: (model['moqQty'] ?? 0).toString(),
    );
    final priceCtrl = TextEditingController(
      text: (model['moqPrice'] ?? 0).toString(),
    );
    final marginCtrl = TextEditingController();

    bool applyMargin = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSB) {
            return AlertDialog(
              title: const Text('MOQ Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'MOQ Quantity',
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'MOQ Price'),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: marginCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Margin % (optional)',
                    ),
                  ),

                  CheckboxListTile(
                    value: applyMargin,
                    title: const Text('Apply Margin'),
                    onChanged: (v) => setSB(() => applyMargin = v ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  child: const Text('Apply'),
                  onPressed: () async {
                    double qty = double.tryParse(qtyCtrl.text) ?? 0;
                    double price = double.tryParse(priceCtrl.text) ?? 0;
                    double margin = double.tryParse(marginCtrl.text) ?? 0;

                    if (applyMargin && margin > 0) {
                      price = price + (price * margin / 100);
                    }

                    model['moqQty'] = qty;
                    model['moqPrice'] = price;

                    final navigator = Navigator.of(ctx);

                    await _saveModels();

                    if (!mounted) return;
                    setState(() {});

                    navigator.pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// =====================================================
  /// ➕ ADD CATEGORY + MAKES POPUP
  /// =====================================================
  void _showAddCategoryDialog() {
    final categoryCtrl = TextEditingController();
    final makeCtrl = TextEditingController();
    final List<String> tempMakes = [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSB) {
            return AlertDialog(
              title: const Text('Add Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // CATEGORY NAME
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // MAKE INPUT
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: makeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Add Make',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final make = makeCtrl.text.trim();
                            if (make.isEmpty) return;

                            tempMakes.add(make);
                            makeCtrl.clear();

                            // force rebuild dialog UI
                            setSB(() {});
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // SHOW ADDED MAKES
                    Wrap(
                      spacing: 6,
                      children: tempMakes
                          .map(
                            (m) => Chip(
                              label: Text(m),
                              onDeleted: () {
                                tempMakes.remove(m);
                                setSB(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final category = categoryCtrl.text.trim();
                    if (category.isEmpty) return;

                    if (!_categories.contains(category)) {
                      _categories.add(category);
                    }

                    _categoryMakes.putIfAbsent(category, () => []);
                    for (final m in tempMakes) {
                      if (!_categoryMakes[category]!.contains(m)) {
                        _categoryMakes[category]!.add(m);
                      }
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(ctx);

                    await _saveCategories(); // saves category list
                    await _saveCategoryMakes(); // saves category → makes mapping

                    if (!mounted) return;

                    setState(() {});
                    navigator.pop();

                    messenger.showSnackBar(
                      SnackBar(content: Text('Category "$category" saved')),
                    );
                  },

                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showViewCategoriesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Categories & Makes'),
          content: SizedBox(
            width: double.maxFinite,
            child: _categories.isEmpty
                ? const Text('No categories added yet.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final makes = _categoryMakes[category] ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ExpansionTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              // ✏️ EDIT CATEGORY BUTTON
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Edit Category',
                                onPressed: () {
                                  showEditCategoryOrMakeDialog(
                                    context: context,
                                    title: 'Category',
                                    oldValue: category,
                                    isCategory: true,
                                    onUpdated: () async {
                                      await _loadCategories();
                                      await _loadCategoryMakes();
                                      setState(() {});
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          children: [
                            if (makes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('No makes added'),
                              ),

                            ...makes.map(
                              (m) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.factory),
                                title: Text(m),

                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ✏️ EDIT MAKE
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      tooltip: 'Edit Make',
                                      onPressed: () {
                                        showEditCategoryOrMakeDialog(
                                          context: context,
                                          title: 'Make',
                                          oldValue: m,
                                          isCategory: false,
                                          onUpdated: () async {
                                            await _loadCategoryMakes();
                                            setState(() {});
                                          },
                                        );
                                      },
                                    ),

                                    // 🗑 DELETE MAKE
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Color.fromARGB(90, 244, 67, 54),
                                      ),
                                      onPressed: () async {
                                        _categoryMakes[category]!.remove(m);
                                        await _saveCategoryMakes();

                                        if (!mounted) return;
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const Divider(),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Color.fromARGB(105, 244, 67, 54),
                                  ),
                                  label: const Text("Delete Category"),
                                  onPressed: () async {
                                    _categories.remove(category);
                                    _categoryMakes.remove(category);

                                    final navigator = Navigator.of(ctx);
                                    await _saveCategories();
                                    await _saveCategoryMakes();

                                    if (!mounted) return;
                                    setState(() {});
                                    navigator.pop();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> showSearchablePicker({
    required BuildContext context,
    required String title,
    required List<String> items,
  }) async {
    String search = '';
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = items
                .where((e) => e.toLowerCase().contains(search.toLowerCase()))
                .toList();

            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Text(title, style: const TextStyle(fontSize: 18)),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => search = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(filtered[i]),
                        onTap: () => Navigator.pop(context, filtered[i]),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------
  // Storage helpers
  // -------------------------
  Future<void> _loadModels() async {
    final prefs = await CloudPreferences.getInstance();
    if (!mounted) return;

    final stored = prefs.getStringList(kProductsKey) ?? <String>[];

    setState(() {
      _models = stored.map((s) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          return {
            // ✅ VERY IMPORTANT FIX
            'id': m['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),

            'no': (m['no'] ?? '').toString(),
            'desc': (m['desc'] ?? '').toString(),
            'lp': (m['lp'] is num)
                ? (m['lp'] as num).toDouble()
                : double.tryParse((m['lp'] ?? '').toString()) ?? 0.0,

            'sp': (m['sp'] is num)
                ? (m['sp'] as num).toDouble()
                : double.tryParse((m['sp'] ?? '').toString()) ?? 0.0,

            // 🔹 ADD BELOW (NEW FIELDS)
            'bp': (m['bp'] is num)
                ? (m['bp'] as num).toDouble()
                : double.tryParse((m['bp'] ?? '').toString()) ?? 0.0,
            'category': (m['category'] ?? '').toString(),
            'make': (m['make'] ?? '').toString(),

            'moqQty': (m['moqQty'] is num)
                ? (m['moqQty'] as num).toDouble()
                : double.tryParse((m['moqQty'] ?? '').toString()) ?? 0.0,

            'moqPrice': (m['moqPrice'] is num)
                ? (m['moqPrice'] as num).toDouble()
                : double.tryParse((m['moqPrice'] ?? '').toString()) ?? 0.0,
          };
        } catch (_) {
          return {
            'no': '',
            'desc': '',
            'lp': 0.0,
            'sp': 0.0,
            'bp': 0.0,
            'category': '',
            'make': '',
          };
        }
      }).toList();
    });
  }

  /// =====================================================
  /// 📂 LOAD CATEGORY LIST
  /// =====================================================
  Future<void> _loadCategories() async {
    final prefs = await CloudPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _categories = prefs.getStringList(kCategoriesKey) ?? [];
    });
  }

  /// =====================================================
  /// 📂 LOAD CATEGORY → MAKE MAP
  /// =====================================================
  Future<void> _loadCategoryMakes() async {
    final prefs = await CloudPreferences.getInstance();

    if (!mounted) return;

    final raw = prefs.getString(kCategoryMakesKey);

    if (raw == null) {
      _categoryMakes = {};
      return;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    setState(() {
      _categoryMakes = decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    });
  }

  /// =====================================================
  /// 💾 SAVE CATEGORY LIST
  /// =====================================================
  /// Save category list permanently
  Future<void> _saveCategories() async {
    final prefs = await CloudPreferences.getInstance();
    await prefs.setStringList(kCategoriesKey, _categories);
  }

  /// =====================================================
  /// 💾 SAVE CATEGORY → MAKE MAP
  /// =====================================================
  Future<void> _saveCategoryMakes() async {
    final prefs = await CloudPreferences.getInstance();
    await prefs.setString(kCategoryMakesKey, jsonEncode(_categoryMakes));
  }

  /// =====================================================
  /// ✏️ UPDATE CATEGORY / MAKE (used by edit button)
  /// =====================================================
  Future<void> updateCategoryOrMake({
    required String oldValue,
    required String newValue,
    required bool isCategory,
  }) async {
    final prefs = await CloudPreferences.getInstance();

    // 🔹 update category list
    if (isCategory) {
      final index = _categories.indexOf(oldValue);
      if (index != -1) {
        _categories[index] = newValue;
      }

      if (_categoryMakes.containsKey(oldValue)) {
        _categoryMakes[newValue] = _categoryMakes.remove(oldValue)!;
      }
    }

    // 🔹 update product references
    final stored = prefs.getStringList(kProductsKey) ?? [];
    final updated = stored.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;

      if (isCategory && map['category'] == oldValue) {
        map['category'] = newValue;
      }

      if (!isCategory && map['make'] == oldValue) {
        map['make'] = newValue;
      }

      return jsonEncode(map);
    }).toList();

    await prefs.setStringList(kProductsKey, updated);
    await _saveCategories();
    await _saveCategoryMakes();
  }

  /// =====================================================
  /// ✏️ EDIT DIALOG FOR CATEGORY / MAKE
  /// =====================================================
  Future<void> showEditCategoryOrMakeDialog({
    required BuildContext context,
    required String title,
    required String oldValue,
    required bool isCategory,
    required VoidCallback onUpdated,
  }) async {
    final controller = TextEditingController(text: oldValue);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'New $title name',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isEmpty) return;

              await updateCategoryOrMake(
                oldValue: oldValue,
                newValue: newValue,
                isCategory: isCategory,
              );

              if (!context.mounted) return;

              Navigator.pop(ctx);
              onUpdated();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // -------------------------
  // Delete ALL models permanently
  // -------------------------
  Future<void> _deleteAllModels() async {
    final prefs = await CloudPreferences.getInstance();

    // Safety guard after await
    if (!mounted) return;

    // Clear local list
    _models.clear();

    // Remove from CloudPreferences
    await prefs.remove(kProductsKey);

    // Guard again
    if (!mounted) return;

    setState(() {}); // refresh UI

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All products deleted successfully')),
    );
  }

  // -------------------------
  // Confirm before deleting all models
  // -------------------------
  Future<void> _confirmDeleteAllModels() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Products'),
        content: const Text(
          'This will permanently delete ALL products.\n\nThis action cannot be undone.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(135, 244, 139, 54),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    // User cancelled
    if (confirmed != true) return;

    // Proceed with delete
    await _deleteAllModels();
  }

  Future<void> _saveModels() async {
    final prefs = await CloudPreferences.getInstance();

    // Immediately guard after await
    if (!mounted) return;

    final encoded = _models
        .map(
          (m) => jsonEncode({
            // ✅ ADD THIS LINE
            'id': m['id'],
            'no': m['no'],
            'desc': m['desc'],
            'lp': m['lp'],
            'sp': m['sp'],
            'bp': m['bp'],
            'moqQty': m['moqQty'],
            'moqPrice': m['moqPrice'],
            'category': m['category'],
            'make': m['make'],
          }),
        )
        .toList();

    await prefs.setStringList(kProductsKey, encoded);

    // immediately guard after the await which might unmount
    if (!mounted) return;
  }

  // -------------------------
  // Public helper getters (call from other pages)
  // -------------------------
  double getListPrice(String modelNo) {
    final found = _models.indexWhere(
      (m) => (m['no'] ?? '').toString() == modelNo,
    );
    if (found >= 0) return (_models[found]['lp'] as double?) ?? 0.0;
    return 0.0;
  }

  double getSpecialPrice(String modelNo) {
    final found = _models.indexWhere(
      (m) => (m['no'] ?? '').toString() == modelNo,
    );
    if (found >= 0) return (_models[found]['sp'] as double?) ?? 0.0;
    return 0.0;
  }

  // -------------------------
  // Import from Excel
  // Expected columns: Model No | Description | List Price | Special Price
  // -------------------------
  Future<void> _importFromExcel() async {
    try {
      // 1) Open file picker to choose an .xlsx file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      // >>> SAFETY: Immediately guard after await
      if (!mounted) return;

      // If user cancelled
      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      final fileBytes = File(filePath).readAsBytesSync();

      // 2) Decode Excel
      final excelFile = excel.Excel.decodeBytes(fileBytes);

      // 3) Use the first sheet
      if (excelFile.tables.isEmpty) {
        // Guard again and use a local messenger (prevents analyzer warning)
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('No sheet found in Excel file')),
        );
        return;
      }

      final firstSheetName = excelFile.tables.keys.first;
      final sheet = excelFile.tables[firstSheetName]!;

      // 4) (optionally) clear old models
      // _models.clear();

      // 5) Loop through rows (skip header = row 0)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final cellNo = row.isNotEmpty ? row[0] : null;
        final cellDesc = row.length > 1 ? row[1] : null;
        final cellLp = row.length > 2 ? row[2] : null;
        final cellSp = row.length > 3 ? row[3] : null;
        final cellBp = row.length > 4 ? row[4] : null;
        final cellCat = row.length > 5 ? row[5] : null;
        final cellMk = row.length > 6 ? row[6] : null;

        final no = (cellNo?.value?.toString() ?? '').trim();
        final desc = (cellDesc?.value?.toString() ?? '').trim();

        final lp = double.tryParse(cellLp?.value?.toString() ?? '') ?? 0.0;
        final sp = double.tryParse(cellSp?.value?.toString() ?? '') ?? 0.0;
        final bp = double.tryParse(cellBp?.value?.toString() ?? '') ?? 0.0;

        final moqQty =
            double.tryParse(
              row.length > 7 ? row[7]?.value?.toString() ?? '' : '',
            ) ??
            0;

        final moqPrice =
            double.tryParse(
              row.length > 8 ? row[8]?.value?.toString() ?? '' : '',
            ) ??
            0;

        final category = (cellCat?.value?.toString() ?? '').trim();
        final make = (cellMk?.value?.toString() ?? '').trim();

        if (no.isEmpty && desc.isEmpty) continue;

        final newModel = {
          // ✅ ADD UNIQUE ID
          'id': '${DateTime.now().millisecondsSinceEpoch}_$i',
          'no': no,
          'desc': desc,
          'lp': lp,
          'sp': sp,
          'bp': bp,
          'moqQty': moqQty,
          'moqPrice': moqPrice,
          'category': category,
          'make': make,
        };

        _models.add(newModel);
      }

      // 6) Save to CloudPreferences
      await _saveModels();

      // >>> SAFETY: immediate guard after await that can unmount (saveModels)
      if (!mounted) return;

      // Update UI and show confirmation (safe now) using a local messenger
      setState(() {});
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Models imported from Excel successfully'),
        ),
      );
    } catch (e) {
      // catch may run after an await; guard before using context
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Error importing Excel: $e')),
      );
    }
  }

  // -------------------------
  // Export to Excel
  // Columns: Model No | Description | List Price | Special Price
  // -------------------------
  Future<void> _exportToExcel() async {
    try {
      if (_models.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No models to export')));
        return;
      }

      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Products'];

      sheet.appendRow([
        excel.TextCellValue('Model No'),
        excel.TextCellValue('Description'),
        excel.TextCellValue('List Price'),
        excel.TextCellValue('Special Price'),
        excel.TextCellValue('Basic Price'),
        excel.TextCellValue('MOQ Qty'),
        excel.TextCellValue('MOQ Price'),
        excel.TextCellValue('Category'),
        excel.TextCellValue('Make'),
      ]);

      for (final m in _models) {
        sheet.appendRow([
          excel.TextCellValue(m['no'] ?? ''),
          excel.TextCellValue(m['desc'] ?? ''),
          excel.TextCellValue((m['lp'] ?? 0).toString()),
          excel.TextCellValue((m['sp'] ?? 0).toString()),
          excel.TextCellValue((m['bp'] ?? 0).toString()),
          excel.TextCellValue('${m['moqQty']}'),
          excel.TextCellValue('${m['moqPrice']}'),
          excel.TextCellValue(m['category'] ?? ''),
          excel.TextCellValue(m['make'] ?? ''),
        ]);
      }

      final bytes = excelFile.encode();
      if (bytes == null) return;

      // ✅ FIX: convert List<int> → Uint8List
      final Uint8List uint8Bytes = Uint8List.fromList(bytes);

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Product List Excel File',
        fileName: 'product_list.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: uint8Bytes, // ✅ correct type
      );

      if (!mounted || savedPath == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel exported successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting Excel: $e')));
    }
  }

  // -------------------------
  // Add / Edit dialog (includes LP and SP)
  // -------------------------
  void _showAddEditDialog({Map<String, dynamic>? model}) {
    final formKey = GlobalKey<FormState>();

    final noController = TextEditingController(
      text: model?['no']?.toString() ?? '',
    );

    final descController = TextEditingController(
      text: model?['desc']?.toString() ?? '',
    );

    final lpController = TextEditingController(
      text: (model?['lp'] ?? 0).toString(),
    );

    final spController = TextEditingController(
      text: (model?['sp'] ?? 0).toString(),
    );

    final bpController = TextEditingController(
      text: (model?['bp'] ?? 0).toString(),
    );

    final moqQtyController = TextEditingController(
      text: (model?['moqQty'] ?? 0).toString(),
    );

    final moqPriceController = TextEditingController(
      text: (model?['moqPrice'] ?? 0).toString(),
    );

    String selectedCategory = model?['category'] ?? '';
    String selectedMake = model?['make'] ?? '';

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text(model == null ? 'Add Model' : 'Edit Model'),

              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// CATEGORY
                      InkWell(
                        onTap: () async {
                          final selected = await showSearchablePicker(
                            context: context,
                            title: 'Select Category',
                            items: _categories,
                          );

                          if (selected != null) {
                            setStateSB(() {
                              selectedCategory = selected;
                              selectedMake = '';
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            selectedCategory.isEmpty
                                ? 'Select Category'
                                : selectedCategory,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      /// MAKE
                      InkWell(
                        onTap: selectedCategory.isEmpty
                            ? null
                            : () async {
                                final makes =
                                    _categoryMakes[selectedCategory] ?? [];

                                final selected = await showSearchablePicker(
                                  context: context,
                                  title: 'Select Make',
                                  items: makes,
                                );

                                if (selected != null) {
                                  setStateSB(() {
                                    selectedMake = selected;
                                  });
                                }
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Make',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            selectedMake.isEmpty
                                ? (selectedCategory.isEmpty
                                      ? 'Select Category First'
                                      : 'Select Make')
                                : selectedMake,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: noController,
                        decoration: const InputDecoration(
                          labelText: 'Model No',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter model no'
                            : null,
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter description'
                            : null,
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: lpController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'List Price',
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: spController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Special Price',
                        ),
                      ),

                      const SizedBox(height: 8),

                      // MOQ QTY
                      TextFormField(
                        controller: moqQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'MOQ Quantity',
                        ),
                      ),

                      const SizedBox(height: 8),

                      // MOQ PRICE
                      TextFormField(
                        controller: moqPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'MOQ Price',
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: bpController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Basic / Purchase Price',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;

                    final no = noController.text.trim();
                    final desc = descController.text.trim();
                    final lp = double.tryParse(lpController.text) ?? 0;
                    final sp = double.tryParse(spController.text) ?? 0;
                    final bp = double.tryParse(bpController.text) ?? 0;

                    double moqQty = double.tryParse(moqQtyController.text) ?? 0;
                    double moqPrice =
                        double.tryParse(moqPriceController.text) ?? 0;

                    final newModel = {
                      'id':
                          model?['id'] ??
                          DateTime.now().millisecondsSinceEpoch.toString(),

                      'no': no,
                      'desc': desc,
                      'lp': lp,
                      'sp': sp,
                      'bp': bp,
                      'moqQty': moqQty,
                      'moqPrice': moqPrice,
                      'category': selectedCategory,
                      'make': selectedMake,
                    };

                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    final index = _models.indexWhere(
                      (m) => m['id'] == newModel['id'],
                    );

                    // ❗ If adding NEW model and already exists
                    if (model == null && index >= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Model "$no" already exists')),
                      );
                      return;
                    }

                    // ✅ If editing → update
                    if (index >= 0) {
                      _models[index] = newModel;
                    } else {
                      _models.add(newModel);
                    }

                    await _saveModels();

                    if (!mounted) return;

                    setState(() {});
                    navigator.pop();

                    messenger.showSnackBar(
                      SnackBar(content: Text('Model "$no" saved successfully')),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------
  // Widget / UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    if (!AccountSession.instance.can('products')) return const AccessDenied();
    // compute filtered list for search (must be outside the widget children list)
    final List<Map<String, dynamic>> displayedModels = _search.isEmpty
        ? _models
        : _models.where((m) {
            final no = (m['no'] ?? '').toString().toLowerCase();
            final desc = (m['desc'] ?? '').toString().toLowerCase();
            return no.contains(_search) || desc.contains(_search);
          }).toList();

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Product List'),
        actions: [
          // ➕ Add Product Model
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Model',
            onPressed: () => _showAddEditDialog(),
          ),

          // 🗂 Add Category + Make
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Add Category',
            onPressed: _showAddCategoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.view_list),
            tooltip: 'View Categories',
            onPressed: _showViewCategoriesDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Import / Export buttons (unchanged)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _importFromExcel,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Import from Excel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export to Excel'),
                  ),
                ),
              ],
            ),
          ),

          // ===== search box (inserted directly after Import/Export row) =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search model no or description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                isDense: true,
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            _search = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() {
                  _search = v.trim().toLowerCase();
                });
              },
            ),
          ),

          const Divider(height: 1),

          // Use the filtered list in the UI
          Expanded(
            child: displayedModels.isEmpty
                ? Center(
                    child: Text(
                      _models.isEmpty
                          ? 'No products added yet'
                          : 'No search results',
                    ),
                  )
                : ListView.separated(
                    itemCount: displayedModels.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = displayedModels[i];
                      final no = m['no'] ?? '';
                      final desc = m['desc'] ?? '';
                      final lp = (m['lp'] as num?)?.toDouble() ?? 0.0;
                      final sp = (m['sp'] as num?)?.toDouble() ?? 0.0;
                      return ListTile(
                        title: Text(no),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(desc),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'LP: ₹${lp.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'SP: ₹${sp.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddEditDialog(model: m),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.inventory_2,
                                color: ((m['moqQty'] ?? 0) > 0)
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              tooltip: 'MOQ Settings',
                              onPressed: () => _showMoqDialog(m),
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm'),
                                    content: Text('Delete "$no"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          // Close dialog first (use dialog-local ctx)
                                          Navigator.of(ctx).pop();

                                          // Capture messenger and navigator before performing async
                                          final messenger =
                                              ScaffoldMessenger.of(context);

                                          // Remove and persist
                                          _models.removeWhere(
                                            (mm) => mm['id'] == m['id'],
                                          );
                                          await _saveModels();

                                          // Guard against unmounted state before using State.context
                                          if (!mounted) return;

                                          setState(() {}); // update UI

                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Model "$no" deleted',
                                              ),
                                            ),
                                          );
                                        },

                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // 🗑 DELETE ALL PRODUCTS
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _models.isEmpty ? null : _confirmDeleteAllModels,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(93, 244, 67, 54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ❌ CLOSE BUTTON
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DashboardPage(toggleTheme: () {}),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
