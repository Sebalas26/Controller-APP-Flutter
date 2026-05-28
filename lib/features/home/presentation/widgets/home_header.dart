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
      height: 56,
      color: const Color(0xFFFEFEFE),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Menú',
                padding: const EdgeInsets.all(16),
                onPressed: onMenuPressed,
                icon: const Icon(Icons.menu, color: AppColors.black, size: 24),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Image.asset(
                AppAssets.logoInterrapidisimo,
                width: 128,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(
            width: 104,
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notificaciones',
                      onPressed: onNotificationsPressed,
                      icon: const Icon(
                        Icons.notifications_none,
                        color: AppColors.black,
                        size: 25,
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
                            notificationCount > 99
                                ? '99'
                                : '$notificationCount',
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
                IconButton(
                  tooltip: offline ? 'Usuario offline' : 'Usuario activo',
                  onPressed: () {},
                  icon: SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            Icons.person_outline,
                            color: AppColors.black,
                            size: 28,
                          ),
                        ),
                        Positioned(
                          right: 1,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: offline
                                  ? AppColors.nativeBadgeRed
                                  : AppColors.onlineGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(width: 7, height: 7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
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
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: SizedBox(
        height: 40,
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
                  hintText: 'Escanea o digita la guía',
                  fillColor: Color(0xFFFEFEFE),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  hintStyle: TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: SizedBox(
                width: 54,
                height: 40,
                child: IconButton(
                  tooltip: 'Buscar guía',
                  onPressed: onSubmit,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.black,
                    size: 23,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
