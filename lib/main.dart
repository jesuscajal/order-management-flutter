// Importa el paquete principal de Flutter para construir la interfaz de usuario
import 'package:flutter/material.dart';
import 'screens/clients_screen.dart';
import 'screens/capital_screen.dart';

// Punto de entrada principal de la aplicación
void main() {
  runApp(const MyApp());
}

// Widget raíz de la aplicación
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Título de la aplicación
      title: 'Flutter Demo',
      // Definición del tema global de la app
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 25, 3, 103), // Color principal
        ),
      ),
      // Pantalla principal de la app
      home: const MyHomePage(title: 'Novaceltecc'),
    );
  }
}

// Widget principal con estado para la pantalla de inicio
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  // Título recibido desde el widget padre
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// Estado asociado a MyHomePage
class _MyHomePageState extends State<MyHomePage> {
  // Índice de la barra de navegación inferior
  int _selectedIndex = 0;

  // Lista de pantallas para la navegación inferior
  final List<Widget> _screens = [
    // Pantalla principal (dashboard)
    // Se puede extraer a un widget aparte si se desea
    Container(), // Placeholder, se reemplaza en build
    // Placeholder para futuras pantallas
    Center(child: Text('Pedidos')),
    Center(child: Text('Stock')),
    const CapitalScreen(), // Pantalla de control de capital
    const ClientsScreen(), // Nueva pantalla de clientes
  ];

  // Maneja el cambio de pestaña en la barra de navegación
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reemplazamos el primer elemento por el dashboard actual
    _screens[0] = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            icon: Icons.assignment,
            iconColor: Colors.blue[200]!,
            title: 'Pedidos pendientes',
            mainValue: '3',
            subtitle: 'total: 5',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.inventory,
            iconColor: Colors.blue[400]!,
            title: 'Resumen del stock',
            mainValue: '12',
            subtitle: 'productos\nValor total: US\$ 840',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.attach_money,
            iconColor: Colors.blue,
            title: 'Cotización USDT',
            mainValue: '1015,50 ARS',
            subtitle: 'Actualizado ahora',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Resumen del capital',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kevin', style: TextStyle(fontSize: 18)),
                    Text('500 USDT', style: TextStyle(fontSize: 18)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nildo', style: TextStyle(fontSize: 18)),
                    Text('275 USDT', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // Color de fondo general
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Título y subtítulo en la AppBar
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Sistema de Gestión',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Pedidos, stock y capital',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        toolbarHeight: 80,
      ),
      body: _screens[_selectedIndex],
      // Barra de navegación inferior
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Pedidos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stock'),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Capital',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
        ],
      ),
    );
  }
}

// Widget reutilizable para las tarjetas informativas
class _InfoCard extends StatelessWidget {
  final IconData icon; // Icono principal
  final Color iconColor; // Color del icono
  final String title; // Título de la tarjeta
  final String mainValue; // Valor principal
  final String subtitle; // Subtítulo o descripción
  final VoidCallback onTap; // Acción al tocar la tarjeta

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.mainValue,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Icono con fondo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 16),
            // Información textual
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        mainValue,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Flecha de navegación
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
