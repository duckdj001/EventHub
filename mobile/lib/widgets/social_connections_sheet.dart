import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/social_connection.dart';

class SocialConnectionsSheet extends StatefulWidget {
  const SocialConnectionsSheet({super.key, required this.title, required this.loader});

  final String title;
  final Future<List<SocialConnection>> Function() loader;

  @override
  State<SocialConnectionsSheet> createState() => _SocialConnectionsSheetState();
}

class _SocialConnectionsSheetState extends State<SocialConnectionsSheet> {
  late Future<List<SocialConnection>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.loader();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    final dateFmt = DateFormat('dd.MM.yyyy');

    return SafeArea(
      top: false,
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<SocialConnection>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text('Ошибка загрузки: ${snapshot.error}'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Повторить'),
                          ),
                        ],
                      );
                    }

                    final data = snapshot.data ?? const [];
                    if (data.isEmpty) {
                      return const Center(child: Text('Список пуст'));
                    }

                    return RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: data.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = data[index];
                          final name = item.fullName.isNotEmpty ? item.fullName : 'Без имени';
                          final subtitle = item.followedAt != null
                              ? 'с ${dateFmt.format(item.followedAt!)}'
                              : null;
                          final trimmed = name.trim();
                          final initial = trimmed.isNotEmpty
                              ? trimmed.characters.first.toUpperCase()
                              : 'U';
                          final router = GoRouter.of(context);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEFF2F7),
                              backgroundImage: (item.avatarUrl != null && item.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(item.avatarUrl!)
                                  : null,
                              child: (item.avatarUrl == null || item.avatarUrl!.isEmpty)
                                  ? Text(initial)
                                  : null,
                            ),
                            title: Text(name),
                            subtitle: subtitle != null ? Text(subtitle) : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).pop();
                              router.push('/users/${item.id}');
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
