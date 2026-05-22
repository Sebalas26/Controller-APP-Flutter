import 'package:flutter/material.dart';

import '../../../../shared/constants/app_assets.dart';
import '../../../../shared/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.white2,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            onPressed: onMenuPressed,
            icon: const Icon(Icons.menu, color: AppColors.black),
          ),
          Expanded(
            child: Center(
              child: Text(
                AppStrings.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'Prospero',
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
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
            tooltip: 'Usuario activo',
            onPressed: () {},
            icon: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.green,
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
              ),
            ),
          ),
          IconButton(
            tooltip: 'Buscar guia',
            onPressed: onSubmit,
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.black),
          ),
        ],
      ),
    );
  }
}
