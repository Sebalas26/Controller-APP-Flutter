import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class HomeFooter extends StatelessWidget {
  const HomeFooter({
    super.key,
    required this.userName,
    required this.statusLabel,
  });

  final String userName;
  final String statusLabel;

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
            statusLabel,
            style: const TextStyle(color: AppColors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
