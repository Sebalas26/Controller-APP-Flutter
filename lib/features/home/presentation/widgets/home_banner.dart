import 'package:flutter/material.dart';

import '../../../../shared/config/app_environment.dart';
import '../../../../shared/constants/app_assets.dart';
import '../../../../shared/theme/app_colors.dart';

const _bannerShadow = [
  BoxShadow(color: Color(0x1A575757), offset: Offset(-2, 4), blurRadius: 12),
];

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          BannerPanel(
            title: 'Sigue tu envío',
            subtitle: environment.label,
            icon: Icons.search,
            color: AppColors.gray100,
          ),
          const SizedBox(width: 12),
          const BannerPanel(
            title: 'Pagos y recaudos',
            subtitle: 'Nequi, link de pago, Inter Pay',
            icon: Icons.payments_outlined,
            color: Color(0xFFF0EDFB),
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
    return Container(
      width: 210,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bannerShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -10,
            child: Opacity(
              opacity: 0.72,
              child: Image.asset(
                AppAssets.droneFlyingWithPackage,
                width: 120,
                height: 92,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 92, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: AppColors.black),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.gray700,
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
