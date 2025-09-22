// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// import '../models/order.dart';
// import '../models/orderItem.dart';
// import '../models/product.dart';
// import '../widgets/dbHelper.dart';

// class AddOrderScreen extends StatefulWidget {
//   final Function onSave;
//   final Order? order;

//   AddOrderScreen({required this.onSave, this.order});

//   @override
//   _AddOrderScreenState createState() => _AddOrderScreenState();
// }

// class _AddOrderScreenState extends State<AddOrderScreen> {
//   final _formKey = GlobalKey<FormState>();
//   String _orderNumber = '';
//   String _dateTime = '';
//   String _customerDetails = '';
//   bool _isCashOnDelivery = false;
//   double _totalPrice = 0.0;
//   int _count = 0;
//   DateTime _currentDateTime = DateTime.now();
//   final DbHelper _dbHelper = DbHelper();
//   List<Product> _products = [];
//   List<OrderItem> _orderItems = [];

//   @override
//   void initState() {
//     super.initState();
//     _fetchProducts();
//     if (widget.order != null) {
//       _orderNumber = widget.order!.orderNumber;
//       _dateTime = widget.order!.dateTime;
//       _customerDetails = widget.order!.customerDetails;
//       _isCashOnDelivery = widget.order!.isCashOnDelivery;
//       // Fetch order items if editing an existing order
//       _fetchOrderItems(widget.order!.id!);
//     } else {
//       _orderNumber = DateFormat('kkmmss').format(_currentDateTime);
//       _dateTime = DateFormat('yyyy-MM-dd hh:mm:ss a').format(_currentDateTime);
//     }
//   }

//   Future<void> _fetchProducts() async {
//     final products = await _dbHelper.getProducts();

//     _products.addAll(
//         products.where((e) => e.isDeal == false).toList().reversed.toList());
//     _products.addAll(
//         products.where((e) => e.isDeal == true).toList().reversed.toList());
//     setState(() {});
//   }

//   Future<void> _fetchOrderItems(int orderId) async {
//     final orderItems = await _dbHelper.getOrderItems(orderId);

//     orderItems.forEach((e) {
//       _count += e.quantity;
//       _totalPrice += e.price;
//     });
//     setState(() {
//       _orderItems = orderItems;
//     });
//   }

//   void _addProductToOrder(Product product) {
//     if (!_orderItems.any((item) => item.productId == product.id)) {
//       _orderItems.add(OrderItem(
//         orderId: widget.order?.id ?? 0,
//         productId: product.id!,
//         quantity: 1,
//         price: product.price,
//       ));
//     } else {
//       var item = _orderItems.firstWhere((item) => item.productId == product.id);
//       item.quantity += 1;
//       item.price += product.price;
//     }

//     _count++;
//     _totalPrice += product.price;
//     setState(() {});
//   }

//   void _removeProductFromOrder(Product product) {
//     var item = _orderItems.firstWhere((item) => item.productId == product.id);
//     if (item.quantity == 1) {
//       _orderItems.remove(item);
//     } else {
//       item.quantity -= 1;
//       item.price -= product.price;
//     }

//     _count--;
//     _totalPrice -= product.price;
//     setState(() {});
//   }

//   void _saveOrder() async {
//     if (_formKey.currentState!.validate()) {
//       final newOrder = Order(
//         orderNumber: _orderNumber,
//         customerDetails: _customerDetails,
//         dateTime: _dateTime,
//         totalPrice: _totalPrice,
//         isProcessed: widget.order?.isProcessed ?? false,
//         isCashOnDelivery: widget.order?.isCashOnDelivery ?? false,
//       );

//       if (widget.order == null) {
//         await _dbHelper.insertOrder(newOrder, _orderItems);
//       } else {
//         newOrder.id = widget.order!.id;
//         await _dbHelper.updateOrder(newOrder, _orderItems);
//       }

//       widget.onSave();
//       Navigator.of(context).pop();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.order == null ? 'Add Order' : 'Edit Order'),
//       ),
//       body: Form(
//         key: _formKey,
//         child: Padding(
//           padding: const EdgeInsets.all(15.0),
//           child: Column(
//             children: [
//               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//                 Text(
//                   'Select Items for Order',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 Row(
//                   children: [
//                     Text(
//                       '${_count} x ',
//                       style:
//                           TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       'Rs. ${_totalPrice.toStringAsFixed(0)}',
//                       style:
//                           TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               ]),
//               Expanded(
//                 child: Container(
//                   color: Colors.grey[200],
//                   child: ListView.builder(
//                     itemCount: _products.length,
//                     itemBuilder: (context, index) {
//                       final product = _products[index];
//                       final existingOrderItem = _orderItems.firstWhere(
//                         (item) => item.productId == product.id,
//                         orElse: () => OrderItem(
//                           orderId: widget.order?.id! ?? 0,
//                           productId: product.id!,
//                           quantity: 0,
//                           price: product.price,
//                         ),
//                       );

//                       return ListTile(
//                         title: Text(product.name),
//                         subtitle:
//                             Text('Price: ${product.price.toStringAsFixed(0)}'),
//                         trailing: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             IconButton(
//                                 icon: Icon(Icons.remove),
//                                 onPressed: () {
//                                   if (existingOrderItem.quantity > 0)
//                                     _removeProductFromOrder(product);
//                                 }),
//                             Text(existingOrderItem.quantity.toString()),
//                             IconButton(
//                               icon: Icon(Icons.add),
//                               onPressed: () => _addProductToOrder(product),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ),
//               TextFormField(
//                 initialValue: _orderNumber,
//                 decoration: InputDecoration(labelText: 'Order Number'),
//                 readOnly: true,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter an order number';
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _orderNumber = value!;
//                 },
//               ),
//               TextFormField(
//                 initialValue: _dateTime,
//                 decoration: InputDecoration(labelText: 'Date Time'),
//                 readOnly: true,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter a date and time';
//                   }
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _dateTime = value!;
//                 },
//               ),
//               TextFormField(
//                 initialValue: _customerDetails,
//                 decoration: InputDecoration(labelText: 'Customer Details'),
//                 validator: (value) {
//                   return null;
//                 },
//                 onSaved: (value) {
//                   _customerDetails = value!;
//                 },
//               ),
//               SwitchListTile(
//                 title: Text('Cash On Delivery'),
//                 value: _isCashOnDelivery,
//                 onChanged: (bool value) {
//                   setState(() {
//                     _isCashOnDelivery = value;
//                   });
//                 },
//               ),
//               SizedBox(height: 15),
//               ElevatedButton(
//                 onPressed: _saveOrder,
//                 child:
//                     Text(widget.order == null ? 'Add Order' : 'Update Order'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
