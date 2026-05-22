import 'package:flutter/material.dart';

import '../../../../main.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.black, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.module,
    required this.onTap,
    this.large = false,
  });

  final AppModule module;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: large ? AppColors.gray200 : AppColors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(large ? 16 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(module.icon, size: large ? 46 : 30, color: AppColors.black),
              const SizedBox(height: 12),
              Text(
                module.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: large ? 15 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
