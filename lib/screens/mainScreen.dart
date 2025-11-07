import 'package:flutter/material.dart';

import '../screens/orderListScreen.dart';
import '../screens/productListScreen.dart';
import '../screens/categoryListScreen.dart';
import '../screens/printerSettingsScreen.dart';
import '../screens/salesReportScreen.dart';
import '../screens/BackupScreen.dart';
import '../screens/settingsScreen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    OrderListScreen(),
    ProductListScreen(),
    CategoryListScreen(),
    SalesReportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.secondary,
          unselectedItemColor: Colors.grey[500],
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long, size: 22),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2, size: 22),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category, size: 22),
              label: 'Category',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics, size: 22),
              label: 'Reporting',
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Orders';
      case 1:
        return 'Products';
      case 2:
        return 'Categories';
      case 3:
        return 'Sales Reports';
      default:
        return 'King Burger POS';
    }
  }
}
