import 'package:flutter/material.dart';

// Modelo de producto
class Producto {
  final String nombre;
  double precioCompra;
  double precioVenta;
  int miStock;
  int stockNildo;

  Producto({
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    required this.miStock,
    required this.stockNildo,
  });

  int get stockTotal => miStock + stockNildo;
}

// Pantalla principal de gestión de stock
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Producto> productos = [
    Producto(
      nombre: 'Powerbank',
      precioCompra: 10.0,
      precioVenta: 15.0,
      miStock: 30,
      stockNildo: 20,
    ),
    Producto(
      nombre: 'Cable USB',
      precioCompra: 1.0,
      precioVenta: 2.0,
      miStock: 70,
      stockNildo: 30,
    ),
  ];

  void _showAddStockDialog() {
    String nombreProducto = '';
    String propietario = "Yo";
    int cantidad = 0;
    double precioCompra = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Añadir Stock',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                  ),
                  onChanged: (v) => nombreProducto = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => cantidad = int.tryParse(v) ?? 0,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Precio de compra',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => precioCompra = double.tryParse(v) ?? 0.0,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: propietario,
                  items: const [
                    DropdownMenuItem(value: "Yo", child: Text("Yo")),
                    DropdownMenuItem(value: "Nildo", child: Text("Nildo")),
                  ],
                  onChanged: (v) => propietario = v ?? "Yo",
                  decoration: const InputDecoration(
                    labelText: 'Propietario del stock',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final productoExistente = productos.firstWhere(
                    (p) =>
                        p.nombre.toLowerCase() == nombreProducto.toLowerCase(),
                    orElse:
                        () => Producto(
                          nombre: nombreProducto,
                          precioCompra: precioCompra,
                          precioVenta: 0.0,
                          miStock: 0,
                          stockNildo: 0,
                        ),
                  );
                  if (!productos.contains(productoExistente)) {
                    if (propietario == "Yo") {
                      productoExistente.miStock = cantidad;
                    } else {
                      productoExistente.stockNildo = cantidad;
                    }
                    productos.add(productoExistente);
                  } else {
                    if (propietario == "Yo") {
                      productoExistente.miStock += cantidad;
                    } else {
                      productoExistente.stockNildo += cantidad;
                    }
                    productoExistente.precioCompra = precioCompra;
                  }
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _goToDetalleProducto(Producto producto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleProductoScreen(producto: producto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Gestión de Stock',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: ElevatedButton.icon(
              onPressed: _showAddStockDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                '+ Añadir Stock',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF3F4F6)),
            columns: const [
              DataColumn(
                label: Text(
                  'Producto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Stock total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Tu stock',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Stock de Nildo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Precio compra',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Precio venta',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows:
                productos.map((p) {
                  return DataRow(
                    cells: [
                      DataCell(
                        GestureDetector(
                          onTap: () => _goToDetalleProducto(p),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text('${p.stockTotal}')),
                      DataCell(Text('${p.miStock}')),
                      DataCell(Text('${p.stockNildo}')),
                      DataCell(Text('\$${p.precioCompra}')),
                      DataCell(Text('\$${p.precioVenta}')),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }
}

// Pantalla de detalle de producto (placeholder)
class DetalleProductoScreen extends StatelessWidget {
  final Producto producto;
  const DetalleProductoScreen({super.key, required this.producto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalle: ${producto.nombre}')),
      body: Center(
        child: Text('Aquí irá el historial y acciones para ${producto.nombre}'),
      ),
    );
  }
}
