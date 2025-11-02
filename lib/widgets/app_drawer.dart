import 'package:flutter/material.dart';

Drawer appDrawer(BuildContext context, {required String currentRoute}) {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Colors.teal),
          child: Text(
            'Menú Principal',
            style: TextStyle(color: Colors.white, fontSize: 22),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Dashboard'),
          selected: currentRoute == '/',
          selectedTileColor: Colors.teal.shade100,
          onTap: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Historial'),
          selected: currentRoute == '/historial',
          selectedTileColor: Colors.teal.shade100,
          onTap: () => Navigator.pushReplacementNamed(context, '/historial'),
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Notificaciones'),
          selected: currentRoute == '/notificaciones',
          selectedTileColor: Colors.teal.shade100,
          onTap: () =>
              Navigator.pushReplacementNamed(context, '/notificaciones'),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Configuración'),
          selected: currentRoute == '/configuracion',
          selectedTileColor: Colors.teal.shade100,
          onTap: () =>
              Navigator.pushReplacementNamed(context, '/configuracion'),
        ),
      ],
    ),
  );
}
