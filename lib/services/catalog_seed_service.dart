import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../widgets/dbHelper.dart';

const String _prefCatalogSeedVersion = 'catalogSeedVersion';
const String _catalogAssetPath = 'assets/seed/catalog.json';

class CatalogSeedService {
  CatalogSeedService._();
  static final CatalogSeedService instance = CatalogSeedService._();

  final DbHelper _db = DbHelper();

  Future<void> seedIfNeeded() async {
    final db = await _db.database;
    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ??
            0;
    if (count > 0) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString(_catalogAssetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final catalogVersion = data['version'] as int? ?? 1;
    final applied = prefs.getInt(_prefCatalogSeedVersion);
    if (applied != null && applied >= catalogVersion) return;

    await _seedFromJson(db, data);
    await prefs.setInt(_prefCatalogSeedVersion, catalogVersion);
  }

  Future<void> _seedFromJson(Database db, Map<String, dynamic> data) async {
    final categories = (data['categories'] as List<dynamic>?) ?? [];
    final products = (data['products'] as List<dynamic>?) ?? [];

    final categoryIdByKey = <String, int>{};
    final categoryImageByKey = <String, String?>{};

    for (final raw in categories) {
      final map = Map<String, dynamic>.from(raw as Map);
      final key = map['key'] as String;
      final name = map['name'] as String;
      final id = await db.insert(
        'categories',
        Category(name: name).toMap(),
      );
      categoryIdByKey[key] = id;

      final imageAsset = map['imageAsset'] as String?;
      if (imageAsset != null && imageAsset.isNotEmpty) {
        final stored = await _storeAssetImage(imageAsset, 'categories', id);
        if (stored != null) {
          await db.update(
            'categories',
            {'imagePath': stored},
            where: 'id = ?',
            whereArgs: [id],
          );
          categoryImageByKey[key] = stored;
        }
      }
    }

    final productIdByKey = <String, int>{};
    final productsByCategoryKey = <String, List<int>>{};

    final productMaps =
        products.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final nonDeals =
        productMaps.where((m) => m['isDeal'] != true).toList(growable: false);
    final deals =
        productMaps.where((m) => m['isDeal'] == true).toList(growable: false);

    Future<int?> insertProductRow(Map<String, dynamic> map) async {
      final categoryKey = map['categoryKey'] as String;
      final categoryId = categoryIdByKey[categoryKey];
      if (categoryId == null) return null;

      final isDeal = map['isDeal'] == true;
      final product = Product(
        name: map['name'] as String,
        categoryId: categoryId,
        price: (map['price'] as num).toDouble(),
        info: map['info'] as String? ?? '',
        isDeal: isDeal,
        productList: isDeal
            ? _resolveDealComponents(
                map['components'] as List<dynamic>?,
                productIdByKey,
              )
            : null,
      );
      final id = await db.insert('products', product.toMap());

      final productKey = map['key'] as String?;
      if (productKey != null && productKey.isNotEmpty) {
        productIdByKey[productKey] = id;
      }

      productsByCategoryKey.putIfAbsent(categoryKey, () => []).add(id);

      final imageAsset = map['imageAsset'] as String?;
      if (imageAsset != null && imageAsset.isNotEmpty) {
        final imagePath = await _storeAssetImage(imageAsset, 'products', id);
        if (imagePath != null) {
          await db.update(
            'products',
            {'imagePath': imagePath},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      return id;
    }

    for (final map in nonDeals) {
      await insertProductRow(map);
    }
    for (final map in deals) {
      await insertProductRow(map);
    }

    // Products without imageAsset get a copy of their category menu image.
    for (final entry in productsByCategoryKey.entries) {
      final catImage = categoryImageByKey[entry.key];
      if (catImage == null) continue;
      for (final productId in entry.value) {
        final row = await db.query(
          'products',
          columns: ['imagePath'],
          where: 'id = ?',
          whereArgs: [productId],
        );
        if (row.isEmpty) continue;
        final existing = row.first['imagePath'] as String?;
        if (existing != null && existing.isNotEmpty) continue;
        final copied = await _copyFileToEntityImage(catImage, 'products', productId);
        if (copied != null) {
          await db.update(
            'products',
            {'imagePath': copied},
            where: 'id = ?',
            whereArgs: [productId],
          );
        }
      }
    }
  }

  List<int>? _resolveDealComponents(
    List<dynamic>? components,
    Map<String, int> productIdByKey,
  ) {
    if (components == null || components.isEmpty) return null;
    final ids = <int>[];
    for (final raw in components) {
      final map = Map<String, dynamic>.from(raw as Map);
      final key = map['key'] as String;
      final qty = (map['qty'] as num?)?.toInt() ?? 1;
      final id = productIdByKey[key];
      if (id == null) continue;
      for (var i = 0; i < qty; i++) {
        ids.add(id);
      }
    }
    return ids.isEmpty ? null : ids;
  }

  Future<String?> _storeAssetImage(String assetPath, String folder, int id) async {
    try {
      final data = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      var ext = p.extension(assetPath).toLowerCase();
      if (ext.isEmpty) ext = '.jpeg';
      final tempFile = File(p.join(tempDir.path, 'seed_${folder}_$id$ext'));
      await tempFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      return _db.storeEntityImage(tempFile.path, folder, id);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _copyFileToEntityImage(
    String sourcePath,
    String folder,
    int id,
  ) async {
    final src = File(sourcePath);
    if (!await src.exists()) return null;
    return _db.storeEntityImage(sourcePath, folder, id);
  }
}
