import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/order.dart';
import '../models/orderItem.dart';
import '../models/product.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static Database? _database;

  factory DbHelper() {
    return _instance;
  }

  DbHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'fast_food.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE categories ADD COLUMN imagePath TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN imagePath TEXT');
    }
    if (oldVersion < 3) {
      // order_items.price was line total; now unit price (quantity * price = subtotal).
      await db.rawUpdate(
          'UPDATE order_items SET price = price / quantity WHERE quantity > 0');
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE categories ADD COLUMN isVisible INTEGER NOT NULL DEFAULT 1');
      await db.execute(
          'ALTER TABLE products ADD COLUMN isVisible INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE order_items ADD COLUMN productName TEXT NOT NULL DEFAULT ''",
      );
      await db.rawUpdate('''
        UPDATE order_items
        SET productName = (
          SELECT COALESCE(p.name, '')
          FROM products p
          WHERE p.id = order_items.productId
        )
        WHERE EXISTS (
          SELECT 1 FROM products p WHERE p.id = order_items.productId
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE orders ADD COLUMN dateTimeEpoch INTEGER',
      );
      final rows = await db.query('orders', columns: ['id', 'dateTime']);
      for (final row in rows) {
        final id = row['id'] as int;
        final s = row['dateTime'] as String?;
        if (s == null || s.trim().isEmpty) continue;
        final dt = Order.parseStoredDateTime(s);
        if (dt == null) continue;
        await db.update(
          'orders',
          {
            'dateTimeEpoch': dt.millisecondsSinceEpoch,
            'dateTime': Order.formatStoredDateTime(dt),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        imagePath TEXT,
        isVisible INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        categoryId INTEGER,
        price REAL,
        info TEXT,
        isDeal INTEGER,
        productList TEXT,
        imagePath TEXT,
        isVisible INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(categoryId) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderNumber TEXT,
        customerDetails TEXT,
        dateTime TEXT,
        dateTimeEpoch INTEGER,
        totalPrice REAL,
        isProcessed INTEGER,
        isCashOnDelivery INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER,
        productId INTEGER,
        quantity INTEGER,
        price REAL,
        productName TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(orderId) REFERENCES orders(id),
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    '''    );
  }

  /// Copies [sourcePath] into app documents and returns the new path, or null on failure.
  Future<String?> storeEntityImage(String sourcePath, String folder, int id) async {
    final src = File(sourcePath);
    if (!await src.exists()) return null;
    final root = await getApplicationDocumentsDirectory();
    final destDir = Directory(join(root.path, 'entity_images', folder));
    await destDir.create(recursive: true);
    var ext = extension(sourcePath).toLowerCase();
    if (ext.isEmpty || ext.length > 8) ext = '.jpg';
    final destPath = join(destDir.path, '$id$ext');
    await src.copy(destPath);
    return destPath;
  }

  // Category operations
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<Category?> getCategory(int id) async {
    final db = await database;
    var result = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? Category.fromMap(result.first) : null;
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    var result = await db.query('categories');
    return result.isNotEmpty
        ? result.map((p) => Category.fromMap(p)).toList()
        : [];
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Product operations
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<Product?> getProduct(int id) async {
    final db = await database;
    var result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? Product.fromMap(result.first) : null;
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    var result = await db.query('products', orderBy: 'id DESC');
    return result.isNotEmpty
        ? result.map((p) => Product.fromMap(p)).toList()
        : [];
  }

  /// Products in visible categories only — includes hidden products (`p.isVisible = 0`)
  /// so the Products tab can show them and toggle visibility. Catalog / orders use
  /// [getVisibleCatalogProducts] instead.
  Future<List<Product>> getProductsInVisibleCategories() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.* FROM products p
      INNER JOIN categories c ON c.id = p.categoryId
      WHERE c.isVisible = 1
      ORDER BY p.id DESC
    ''');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Category>> getVisibleCategories() async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'isVisible = ?',
      whereArgs: [1],
    );
    return result.isNotEmpty
        ? result.map((p) => Category.fromMap(p)).toList()
        : [];
  }

  Future<List<Product>> getVisibleCatalogProducts() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.* FROM products p
      INNER JOIN categories c ON c.id = p.categoryId
      WHERE p.isVisible = 1 AND c.isVisible = 1
      ORDER BY p.id DESC
    ''');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> getNonDealProducts() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.* FROM products p
      INNER JOIN categories c ON c.id = p.categoryId
      WHERE p.isDeal = 0 AND p.isVisible = 1 AND c.isVisible = 1
      ORDER BY p.id DESC
    ''');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  // Order operations
  Future<TimeOfDay> getSavedShiftStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('timeLimit') ?? '09:00 AM'; // default 9 AM
    // saved format: HH:MM AM/PM  (e.g. "09:15 PM")

    final parts = saved.split(RegExp(r'[: ]')); // ['09','15','PM']
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final ampm = parts[2];

    // Convert to 24-hour
    int hour24 = hour % 12;
    if (ampm == 'PM') hour24 += 12;

    return TimeOfDay(hour: hour24, minute: minute);
  }

  Future<DateTime> getShiftStart() async {
    final now = DateTime.now();
    final savedTime = await getSavedShiftStartTime();

    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      savedTime.hour,
      savedTime.minute,
    );

    // If current time is *before* today’s shift start,
    // we belong to yesterday’s shift.
    return now.isBefore(todayStart)
        ? todayStart.subtract(const Duration(days: 1))
        : todayStart;
  }

  Future<DateTime> getShiftEnd() async {
    final start = await getShiftStart();
    return start.add(const Duration(hours: 24));
  }

  Future<List<Order>> getShiftOrders() async {
    final db = await database;
    final start = await getShiftStart();
    final end = await getShiftEnd();

    final result = await db.query(
      'orders',
      where: 'dateTimeEpoch >= ? AND dateTimeEpoch < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );

    return result.isNotEmpty
        ? result.map((o) => Order.fromMap(o)).toList()
        : [];
  }

  Future<String> getNextOrderNo() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await database;
    final start = await getShiftStart();
    final end = await getShiftEnd();

    final appLetter = prefs.getString('appLetter') ?? 'A';
    final orderNoMaxLength = prefs.getInt('orderNoMaxLength') ?? 4;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM orders WHERE dateTimeEpoch >= ? AND dateTimeEpoch < ?',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;
    return "${appLetter}_${(count + 1).toString().padLeft(orderNoMaxLength, '0')}";
  }

  static const String _kOrderDedupAnchorMs = 'orderDedupAnchorEpochMs';

  /// Rolling 24h window anchored in prefs; resets when expired. Used to cap
  /// duplicate rows with the same [orderNumber] (e.g. repeated Save taps).
  Future<DateTimeRange> _orderNumberDedupWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final existing = prefs.getInt(_kOrderDedupAnchorMs);
    DateTime anchor;
    if (existing == null) {
      anchor = DateTime(now.year, now.month, now.day);
      await prefs.setInt(_kOrderDedupAnchorMs, anchor.millisecondsSinceEpoch);
    } else {
      anchor = DateTime.fromMillisecondsSinceEpoch(existing);
      final end = anchor.add(const Duration(hours: 24));
      if (now.isAfter(end)) {
        anchor = DateTime(now.year, now.month, now.day);
        await prefs.setInt(_kOrderDedupAnchorMs, anchor.millisecondsSinceEpoch);
      }
    }
    final windowEnd = anchor.add(const Duration(hours: 24));
    return DateTimeRange(start: anchor, end: windowEnd);
  }

  /// How many orders already use [orderNumber] inside the current dedup window.
  Future<int> countOrdersWithSameNumberInDedupWindow(String orderNumber) async {
    final range = await _orderNumberDedupWindow();
    final db = await database;
    final startMs = range.start.millisecondsSinceEpoch;
    final endMs = range.end.millisecondsSinceEpoch;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt FROM orders
      WHERE orderNumber = ? AND dateTimeEpoch >= ? AND dateTimeEpoch < ?
      ''',
      [orderNumber, startMs, endMs],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// At most two rows with the same order number per 24h window (blocks a 3rd).
  Future<bool> canInsertOrderWithNumber(String orderNumber) async {
    final n = await countOrdersWithSameNumberInDedupWindow(orderNumber);
    return n < 2;
  }

  Future<List<Map<String, dynamic>>> getSalesReport(
      DateTime start, DateTime end) async {
    final db = await database;

    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    // Label: latest order line's snapshot [productName] in range, then catalog, then placeholder.
    // Revenue still sums all lines (unit price × qty on each row).
    return await db.rawQuery('''
    SELECT 
      oi.productId AS productId,
      COALESCE(
        NULLIF(
          (
            SELECT TRIM(COALESCE(oi2.productName, ''))
            FROM order_items oi2
            INNER JOIN orders o2 ON o2.id = oi2.orderId
            WHERE oi2.productId = oi.productId
              AND o2.dateTimeEpoch BETWEEN ? AND ?
            ORDER BY oi2.id DESC
            LIMIT 1
          ),
          ''
        ),
        (SELECT p.name FROM products p WHERE p.id = oi.productId LIMIT 1),
        '(removed)'
      ) AS productName,
      SUM(oi.quantity) AS totalQty,
      SUM(oi.quantity * oi.price) AS totalPrice
    FROM order_items oi
    INNER JOIN orders o ON o.id = oi.orderId
    WHERE o.dateTimeEpoch BETWEEN ? AND ?
    GROUP BY oi.productId
    ORDER BY totalQty DESC
  ''', [startMs, endMs, startMs, endMs]);
  }

  /// Orders whose [dateTime] falls in the same inclusive range as [getSalesReport].
  Future<List<Order>> getOrdersForSalesReport(
      DateTime start, DateTime end) async {
    final db = await database;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final result = await db.query(
      'orders',
      where: 'dateTimeEpoch BETWEEN ? AND ?',
      whereArgs: [startMs, endMs],
      orderBy: 'dateTimeEpoch DESC',
    );
    return result.isNotEmpty
        ? result.map((m) => Order.fromMap(m)).toList()
        : [];
  }

  Future<void> insertOrder(Order order, List<OrderItem> orderItems) async {
    print("-----Db Add Order-----");
    print(order);
    print(orderItems);

    final db = await database;
    int orderId = await db.insert('orders', order.toMap());
    for (var item in orderItems) {
      item.orderId = orderId;
      await db.insert('order_items', item.toMap());
    }
  }

  Future<void> updateOrder(Order order, List<OrderItem> orderItems) async {
    final db = await database;
    await db.update('orders', order.toMap(),
        where: 'id = ?', whereArgs: [order.id]);
    await db.delete('order_items', where: 'orderId = ?', whereArgs: [order.id]);
    for (var item in orderItems) {
      item.orderId = order.id!;
      await db.insert('order_items', item.toMap());
    }
  }

  Future<void> updateOrderStatus(Order order) async {
    final db = await database;
    await db.update('orders', order.toMap(),
        where: 'id = ?', whereArgs: [order.id]);
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final db = await database;
    var result = await db
        .query('order_items', where: 'orderId = ?', whereArgs: [orderId]);
    return result.isNotEmpty
        ? result.map((item) => OrderItem.fromMap(item)).toList()
        : [];
  }

  Future<void> deleteOrder(int orderId) async {
    final db = await database;
    await db.delete('order_items', where: 'orderId = ?', whereArgs: [orderId]);
    await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
  }

  Future<Order?> getOrder(int id) async {
    final db = await database;
    var result = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? Order.fromMap(result.first) : null;
  }

  Future<List<Order>> getOrders() async {
    final db = await database;
    var result = await db.query('orders');
    return result.isNotEmpty
        ? result.map((o) => Order.fromMap(o)).toList()
        : [];
  }

  Future<List<Order>> getUnprocessedOrders(int limit) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'isProcessed = ?',
      whereArgs: [0],
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return Order.fromMap(maps[i]);
    });
  }

  // OrderItem operations
  Future<int> insertOrderItem(OrderItem orderItem) async {
    final db = await database;
    return await db.insert('order_items', orderItem.toMap());
  }

  Future<List<OrderItem>> getAllOrderItems() async {
    final db = await database;
    var result = await db.query('order_items');
    return result.isNotEmpty
        ? result.map((o) => OrderItem.fromMap(o)).toList()
        : [];
  }

  Future<List<OrderItem>> getOrderAllItems(int orderId) async {
    final db = await database;
    var result = await db
        .query('order_items', where: 'orderId = ?', whereArgs: [orderId]);
    return result.isNotEmpty
        ? result.map((o) => OrderItem.fromMap(o)).toList()
        : [];
  }

  Future<int> updateOrderItem(OrderItem orderItem) async {
    final db = await database;
    return await db.update('order_items', orderItem.toMap(),
        where: 'id = ?', whereArgs: [orderItem.id]);
  }

  Future<int> deleteOrderItem(int id) async {
    final db = await database;
    return await db.delete('order_items', where: 'id = ?', whereArgs: [id]);
  }

  // Backup & Restore operations
  Future<void> exportBackup() async {
    final db = await database;
    final categories = await db.query('categories');
    final exportData = {
      'categories': await Future.wait(categories.map((cat) async {
        final products = await db.query(
          'products',
          where: 'categoryId = ?',
          whereArgs: [cat['id']],
        );
        return {
          'id': cat['id'],
          'name': cat['name'],
          'imagePath': cat['imagePath'],
          'isVisible': cat['isVisible'] ?? 1,
          'products': products
              .map((p) => {
                    'id': p['id'],
                    'name': p['name'],
                    'price': p['price'],
                    'info': p['info'] ?? '',
                    'isDeal': p['isDeal'],
                    'productList': p['productList'] ?? '[]',
                    'imagePath': p['imagePath'],
                    'isVisible': p['isVisible'] ?? 1,
                  })
              .toList()
        };
      }))
    };

    final backupData = jsonEncode({'Export Data': exportData});

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pos_backup.txt');
    await file.writeAsString(backupData);

    print('Backup saved to: ${file.path}');
  }

  Future<void> importBackup() async {
    final db = await database;
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'json']);
    if (result == null) return;

    final file = File(result.files.single.path!);
    final jsonData = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final exportBlock =
        (jsonData['Export Data'] as Map<String, dynamic>?) ?? jsonData;
    final categoriesList =
        (exportBlock['categories'] as List<dynamic>?) ?? const [];

    final batch = db.batch();

    for (var cat in categoriesList) {
      // Insert category
      final catMap = Map<String, dynamic>.from(cat as Map);
      int catId = await db.insert(
          'categories',
          {
            'id': catMap['id'],
            'name': catMap['name'],
            'imagePath': catMap['imagePath'],
            'isVisible': catMap['isVisible'] ?? 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      for (var prod in (catMap['products'] as List<dynamic>?) ?? const []) {
        final p = Map<String, dynamic>.from(prod as Map);
        await db.insert(
            'products',
            {
              'id': p['id'],
              'name': p['name'],
              'categoryId': catId,
              'price': p['price'],
              'info': p['info'],
              'isDeal': (p['isDeal'] == true || p['isDeal'] == 1) ? 1 : 0,
              'productList': p['productList'],
              'imagePath': p['imagePath'],
              'isVisible': p['isVisible'] ?? 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
    print('Backup restored successfully');
  }
}
