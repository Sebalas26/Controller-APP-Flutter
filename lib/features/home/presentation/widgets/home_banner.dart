import 'package:flutter/material.dart';

import '../../../../shared/config/app_environment.dart';
import '../../../../shared/constants/app_assets.dart';
import '../../../../shared/theme/app_colors.dart';

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        height: 145,
        child: PageView(
          controller: PageController(viewportFraction: 1),
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
      child: Material(
        elevation: 10,
        shadowColor: AppColors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  AppAssets.droneFlyingWithPackage,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.9),
                      color.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
              Padding(
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
                              fontFamily: 'Montserrat',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.gray700,
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(icon, size: 34, color: AppColors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
