import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/home_module.dart';

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
          Icon(icon, color: AppColors.black, size: 12),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 12,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryModulesLayout extends StatelessWidget {
  const PrimaryModulesLayout({
    super.key,
    required this.modules,
    required this.onSelected,
  });

  final List<AppModule> modules;
  final ValueChanged<AppModule> onSelected;

  @override
  Widget build(BuildContext context) {
    final admit = _moduleById('vender', 0);
    final deliver = _moduleById('entregar', 1);
    final pickup = _moduleById('recoger', 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 0, 5, 10),
        child: SizedBox(
          height: 157,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PrimaryModuleCard(
                  module: admit,
                  large: true,
                  onTap: () => onSelected(admit),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 68,
                      child: _PrimaryModuleCard(
                        module: deliver,
                        onTap: () => onSelected(deliver),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 68,
                      child: _PrimaryModuleCard(
                        module: pickup,
                        onTap: () => onSelected(pickup),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppModule _moduleById(String id, int fallbackIndex) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    final index = fallbackIndex.clamp(0, modules.length - 1);
    return modules[index];
  }
}

class _PrimaryModuleCard extends StatelessWidget {
  const _PrimaryModuleCard({
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
      color: AppColors.gray200,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(module.icon, size: large ? 42 : 24, color: AppColors.black),
              SizedBox(height: large ? 10 : 4),
              Text(
                module.homeLabel,
                textAlign: TextAlign.center,
                maxLines: large ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleCard extends StatelessWidget {
  const ModuleCard({super.key, required this.module, required this.onTap});

  final AppModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Opacity(
        opacity: module.enabled ? 1 : 0.3,
        child: Material(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: module.enabled ? onTap : null,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 10, 7, 15),
                  child: Column(
                    children: [
                      Icon(module.icon, size: 20, color: AppColors.black),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Center(
                          child: Text(
                            module.homeLabel,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (module.showNew)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Nuevo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontFamily: 'Montserrat',
                          fontSize: 8,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
