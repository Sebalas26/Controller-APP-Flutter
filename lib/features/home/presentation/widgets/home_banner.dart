import 'package:flutter/material.dart';

import '../../../../shared/config/app_environment.dart';
import '../../../../shared/theme/app_colors.dart';

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 145,
      child: PageView(
        controller: PageController(viewportFraction: 0.82),
        children: [
          BannerPanel(
            title: 'Sigue tu envio',
            subtitle: environment.label,
            icon: Icons.search,
            color: AppColors.blue8,
          ),
          const BannerPanel(
            title: 'Pagos y recaudos',
            subtitle: 'Nequi, Link de pago, Inter Pay',
            icon: Icons.payments_outlined,
            color: AppColors.accentLight,
          ),
        ],
      ),
    );
  }
}

class BannerPanel extends StatelessWidget {
  const BannerPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 44, color: AppColors.black),
            ],
          ),
        ),
      ),
    );
  }
}
