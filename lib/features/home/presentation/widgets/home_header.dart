import 'package:flutter/material.dart';

import '../../../../shared/constants/app_assets.dart';
import '../../../../shared/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
    required this.offline,
    this.notificationCount = 0,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;
  final bool offline;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.white2,
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Menu',
              padding: const EdgeInsets.all(12),
              onPressed: onMenuPressed,
              icon: const Icon(Icons.menu, color: AppColors.black, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Image.asset(
                AppAssets.logoInterrapidisimo,
                width: 160,
                height: 29,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notificaciones',
                onPressed: onNotificationsPressed,
                icon: const Icon(
                  Icons.notifications_none,
                  color: AppColors.black,
                ),
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.nativeBadgeRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      notificationCount > 99 ? '99' : '$notificationCount',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: offline ? 'Usuario offline' : 'Usuario activo',
            onPressed: () {},
            icon: SizedBox(
              width: 25,
              height: 25,
              child: Stack(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.black,
                      size: 25,
                    ),
                  ),
                  Positioned(
                    right: 1,
                    top: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: offline
                            ? AppColors.nativeBadgeRed
                            : AppColors.onlineGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 6, height: 6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class SearchGuideField extends StatelessWidget {
  const SearchGuideField({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 20,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'Ingresa numero guia',
                fillColor: AppColors.white,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                hintStyle: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Buscar guia',
            onPressed: onSubmit,
            padding: const EdgeInsets.all(11),
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.black),
          ),
        ],
      ),
    );
  }
}
