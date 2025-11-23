import 'package:delivery_app/screens/admin_dashboard_page.dart';
import 'package:delivery_app/screens/order_management_page.dart';
import 'package:delivery_app/screens/plat_form_page.dart';
import 'package:delivery_app/screens/plat_list_page.dart';
import 'package:delivery_app/screens/user_management_page.dart';
import 'package:flutter/material.dart';

// ----------------------------------------------------
// 1. Pages/Screens (Widgets à importer)
// ----------------------------------------------------
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/menu_page.dart';
import 'screens/cart_page.dart';
import 'screens/details_page.dart';
import 'screens/history_page.dart';

void main() {
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Cache la bannière de debug
      title: 'App de Livraison',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        // Style de bouton élevé (utilisé dans login_page.dart)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),

      // ----------------------------------------------------
      // 2. Définition des Routes Nommées (Exigence Projet)
      // ----------------------------------------------------
      initialRoute: '/home',
      routes: {
        // --- Authentification ---
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),

        '/admin_dashboard': (context) => const AdminDashboardPage(),
        '/orders_management': (context) => const OrdersManagementPage(),
        '/user_management': (context) => const UserManagementPage(),
        '/plat_form': (context) => const PlatFormPage(),
        '/plat_list': (context) => const PlatListPage(),

        '/menu': (context) => const MenuPage(), // Catalogue
        '/cart': (context) => const CartPage(), // Panier
        '/history': (context) => const HistoryPage(), // Historique
        '/details': (context) => const DetailsPage(), // Détails Plat
      },
    );
  }
}
