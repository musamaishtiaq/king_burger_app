import 'package:flutter/material.dart';

import '../screens/orderListScreen.dart';
import '../screens/productListScreen.dart';
import '../screens/categoryListScreen.dart';
import '../screens/salesReportScreen.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme_extensions.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/main_tab_index.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    OrderListScreen(),
    ProductListScreen(),
    CategoryListScreen(),
    SalesReportScreen(),
  ];

  void _onItemTapped(int index) {
    mainTabIndex.value = index;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = useNavigationRailLayout(context);
    final railExtended =
        MediaQuery.sizeOf(context).width >= 900;

    final body = IndexedStack(
      index: _selectedIndex,
      children: _screens,
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: railExtended
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.selected,
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              unselectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: AppColors.primary.withValues(alpha: 0.12),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('Orders'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Products'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: Text('Category'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Reporting'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: context.extras.shadow,
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
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
      ),
    );
  }
}
