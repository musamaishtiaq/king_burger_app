import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
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
        FOREIGN KEY(categoryId) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderNumber TEXT,
        customerDetails TEXT,
        dateTime TEXT,
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
        FOREIGN KEY(orderId) REFERENCES orders(id),
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    ''');
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
    var result = await db.query('products');
    return result.isNotEmpty
        ? result.map((p) => Product.fromMap(p)).toList()
        : [];
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

  Future<List<Product>> getNonDealProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('products', where: 'isDeal = ?', whereArgs: [0]);
    return List.generate(maps.length, (i) {
      return Product(
        id: maps[i]['id'],
        name: maps[i]['name'],
        categoryId: maps[i]['categoryId'],
        price: maps[i]['price'],
        info: maps[i]['info'],
        isDeal: false,
        productList: [],
      );
    });
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
      where: 'dateTime >= ? AND dateTime < ?',
      whereArgs: [
        DateFormat('yyyy-MM-dd HH:mm:ss').format(start),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(end)
      ],
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
      'SELECT COUNT(*) as cnt FROM orders WHERE dateTime >= ? AND dateTime < ?',
      [
        DateFormat('yyyy-MM-dd HH:mm:ss').format(start),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(end)
      ],
    );

    final count = Sqflite.firstIntValue(result) ?? 0;
    return "${appLetter}_${(count + 1).toString().padLeft(orderNoMaxLength, '0')}";
  }

  Future<List<Map<String, dynamic>>> getSalesReport(
      DateTime start, DateTime end) async {
    final db = await database;

    final startStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(start); // 2025-09-22T00:00:00
    final endStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(end);

    return await db.rawQuery('''
    SELECT 
      p.id AS productId,
      p.name AS productName,
      SUM(oi.quantity) AS totalQty,
      SUM(oi.quantity * p.price) AS totalPrice
    FROM order_items oi
    JOIN products p ON p.id = oi.productId
    JOIN orders o ON o.id = oi.orderId
    WHERE o.dateTime BETWEEN ? AND ?
    GROUP BY p.id, p.name
    ORDER BY totalQty DESC
  ''', [startStr, endStr]);
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
}
