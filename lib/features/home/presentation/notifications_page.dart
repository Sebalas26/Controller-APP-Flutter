import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unread = true;

  @override
  Widget build(BuildContext context) {
    final status = _unread ? 'Sin leer' : 'Leida';

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  selected: _unread,
                  label: const Text('Sin leer'),
                  onSelected: (_) => setState(() => _unread = true),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  selected: !_unread,
                  label: const Text('Leidos'),
                  onSelected: (_) => setState(() => _unread = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gray300),
                  ),
                  child: ListTile(
                    leading: Icon(
                      _unread
                          ? Icons.mark_email_unread_outlined
                          : Icons.drafts_outlined,
                    ),
                    title: Text('Actualizacion guia ${1000 + index}'),
                    subtitle: Text(status),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
