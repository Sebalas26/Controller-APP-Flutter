import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/home_module.dart';

const _surface = Color(0xFFFEFEFE);
const _cardShadow = [
  BoxShadow(color: Color(0x26575757), offset: Offset(-2, 4), blurRadius: 12),
];

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.black, size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 12,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            TextButton(
              onPressed: onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(actionLabel!),
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
    if (modules.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 100,
        child: modules.length <= 3
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < modules.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _PrimaryModuleCard(
                        module: modules[index],
                        onTap: modules[index].enabled
                            ? () => onSelected(modules[index])
                            : null,
                      ),
                    ),
                  ],
                ],
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: modules.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return SizedBox(
                    width: 105,
                    child: _PrimaryModuleCard(
                      module: module,
                      onTap: module.enabled ? () => onSelected(module) : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PrimaryModuleCard extends StatelessWidget {
  const _PrimaryModuleCard({required this.module, required this.onTap});

  final AppModule module;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: module.enabled ? 1 : 0.3,
      child: _HomeCardShell(
        borderColor: AppColors.accent,
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 13, 8, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(module.icon, size: 28, color: AppColors.black),
                  const SizedBox(height: 9),
                  Text(
                    module.homeLabel,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.08,
                    ),
                  ),
                ],
              ),
            ),
            if (module.showNew) const _NewBadge(),
          ],
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
    return Opacity(
      opacity: module.enabled ? 1 : 0.3,
      child: _HomeCardShell(
        onTap: module.enabled ? onTap : null,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 11, 7, 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(module.icon, size: 24, color: AppColors.black),
                  const SizedBox(height: 8),
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
                          height: 1.08,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (module.showNew) const _NewBadge(),
          ],
        ),
      ),
    );
  }
}

class _HomeCardShell extends StatelessWidget {
  const _HomeCardShell({required this.child, this.onTap, this.borderColor});

  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: _cardShadow),
      child: Material(
        color: _surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor ?? _surface),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(8),
            topRight: Radius.circular(16),
          ),
        ),
        child: const Text(
          'Nuevo',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.white,
            fontFamily: 'Montserrat',
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
