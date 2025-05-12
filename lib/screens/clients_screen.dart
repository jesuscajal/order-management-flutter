import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clients = [
      {'name': 'Kevin', 'contact': '5551234', 'capital': '200 USDT'},
      {'name': 'Nildo', 'contact': 'nildo@example.com', 'capital': '100 USDT'},
      {'name': 'María', 'contact': 'maria@example.com', 'capital': '300 USDT'},
      {'name': 'Juan', 'contact': '5555678', 'capital': '150 USDT'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 90,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Clientes',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 36,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Acción para agregar cliente
              },
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('+ Nuevo cliente', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            // Barra de búsqueda
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: 'Buscar cliente...',
                  border: InputBorder.none,
                ),
              ),
            ),
            // Encabezado
            Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Capital', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            // Lista
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = clients[index];
                    final isPhone = RegExp(r'^\d{3,}$').hasMatch(c['contact']!);

                    return InkWell(
                      onTap: () {
                        // Navegar al detalle del cliente
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Text(c['contact']!),
                                  const SizedBox(width: 8),
                                  if (isPhone)
                                    IconButton(
                                      icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                                      tooltip: 'WhatsApp',
                                      onPressed: () async {
                                        final phone = c['contact']!.replaceAll(RegExp(r'[^\d]'), '');
                                        final url = Uri.parse('https://wa.me/$phone');
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(c['capital'] ?? ''),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
