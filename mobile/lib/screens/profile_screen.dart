// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient('http://localhost:3000');

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: const [
            CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://placehold.co/128x128')),
            SizedBox(width: 12),
            Expanded(child: Text('Имя Фамилия', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: const Text('Управление событиями'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/my-events'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () async {
              await api.clearToken();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
