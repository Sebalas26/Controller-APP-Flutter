import 'package:flutter/material.dart';

import '../../../../main.dart';
import '../../../login/login.dart';

class HomeFooter extends StatelessWidget {
  const HomeFooter({
    super.key,
    required this.userName,
    required this.environment,
    required this.syncStatus,
    required this.offline,
  });

  final String userName;
  final AppEnvironment environment;
  final LocalSyncStatus? syncStatus;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(color: AppColors.black),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: AppColors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            offline
                ? 'Offline'
                : syncStatus?.completed == true
                ? 'Sync OK'
                : environment.label,
            style: const TextStyle(color: AppColors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
