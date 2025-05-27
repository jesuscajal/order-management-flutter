import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'screens/clients_screen.dart';
import 'screens/capital_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/pedidos_screen.dart';
import 'screens/precio_btc_widget.dart';
import 'screens/deudores_screen.dart';
import 'data/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar la base de datos
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = LazyDatabase(() async {
    final dbPath = p.join(dbFolder.path, 'db.sqlite');
    final dbFile = File(dbPath);
    return NativeDatabase(dbFile);
  });

  final database = AppDatabase(file);

  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final AppDatabase database;

  const MyApp({
    super.key,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      cardColor: const Color(0xFF161B22),
      primaryColor: const Color(0xFF1E88E5),
      dividerColor: const Color(0xFF2C3A4A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1117),
        foregroundColor: Color(0xFFE6EDF3),
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E2530),
        selectedItemColor: Color(0xFF67C3F3),
        unselectedItemColor: Color(0xFF9BAEC8),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFE6EDF3)),
        bodyMedium: TextStyle(color: Color(0xFF9BAEC8)),
        titleLarge:
            TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF67C3F3)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        cardColor: Colors.white,
        primaryColor: const Color(0xFF1976D2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9FB),
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFF3F1F8),
          selectedItemColor: Color(0xFF1976D2),
          unselectedItemColor: Colors.black54,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black54),
          titleLarge:
              TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1976D2)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: MyHomePage(title: 'Novaceltecc', database: database),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.database,
  });

  final String title;
  final AppDatabase database;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoCard(
                          icon: Icons.assignment,
                          iconColor:
                              Theme.of(context).iconTheme.color ?? Colors.blue,
                          title: 'Pedidos pendientes',
                          mainContent: Text(
                            '3',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: 'total: 5',
                          onTap: () {
                            setState(() => _selectedIndex = 1);
                          },
                        ),
                        const SizedBox(height: 16),
                        _InfoCard(
                          icon: Icons.inventory,
                          iconColor:
                              Theme.of(context).iconTheme.color ?? Colors.blue,
                          title: 'Resumen del stock',
                          mainContent: Text(
                            '12',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: 'productos\nValor total: US\$ 840',
                          onTap: () {
                            setState(() => _selectedIndex = 2);
                          },
                        ),
                        const SizedBox(height: 16),
                        _InfoCard(
                          icon: Icons.attach_money,
                          iconColor:
                              Theme.of(context).iconTheme.color ?? Colors.blue,
                          title: 'Cotización USDT/ARG',
                          mainContent: PrecioBTCWidget(label: 'USDT/ARG'),
                          subtitle: '',
                          onTap: () {},
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen del capital',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Kevin',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                  Text('500 USDT',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Nildo',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                  Text('275 USDT',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      case 1:
        return const PedidosScreen();
      case 2:
        return const StockScreen();
      case 3:
        return const CapitalScreen();
      case 4:
        return ClientsScreen(database: widget.database);
      case 5:
        return const DeudoresScreen();
      default:
        return const Center(child: Text('Pantalla no encontrada'));
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sistema de Gestión',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Pedidos, stock y capital',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        toolbarHeight: 80,
      ),
      body: _buildScreen(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.attach_money_outlined),
            selectedIcon: Icon(Icons.attach_money),
            label: 'Capital',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Deudores',
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget mainContent;
  final String subtitle;
  final VoidCallback onTap;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.mainContent,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).iconTheme.color?.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: Theme.of(context).iconTheme.color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      mainContent,
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color),
          ],
        ),
      ),
    );
  }
}
