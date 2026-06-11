import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/vender_models.dart';

const _venderSurface = Color(0xFFFEFEFE);
const _venderBorder = Color(0xFFE0E0E0);
const _venderMuted = Color(0xFF727272);
const _venderSoftPurple = Color(0xFFF0EDFB);
const _venderPurple = Color(0xFF6E52E1);

class VenderPanel extends StatelessWidget {
  const VenderPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _venderSurface,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class VenderSectionTitle extends StatelessWidget {
  const VenderSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.black, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: _venderMuted,
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VenderTextInput extends StatelessWidget {
  const VenderTextInput({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.requiredField = false,
    this.center = false,
    this.tooltip,
    this.textCapitalization = TextCapitalization.none,
    this.onFocusLost,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final bool requiredField;
  final bool center;
  final String? tooltip;
  final TextCapitalization textCapitalization;
  final VoidCallback? onFocusLost;

  @override
  Widget build(BuildContext context) {
    return _NativeFieldShell(
      label: label,
      requiredField: requiredField,
      tooltip: tooltip,
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) onFocusLost?.call();
        },
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          textCapitalization: textCapitalization,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          decoration: _underlineDecoration(),
        ),
      ),
    );
  }
}

class VenderReadOnlyValue extends StatelessWidget {
  const VenderReadOnlyValue({
    super.key,
    required this.label,
    required this.value,
    this.requiredField = false,
    this.center = false,
  });

  final String label;
  final String value;
  final bool requiredField;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return _NativeFieldShell(
      label: label,
      requiredField: requiredField,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: center ? Alignment.center : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: _venderSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _venderBorder),
        ),
        child: Text(
          value.trim().isEmpty ? '0' : value,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class VenderCatalogDropdown extends StatelessWidget {
  const VenderCatalogDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.requiredField = false,
  });

  final String label;
  final List<CatalogOption> options;
  final CatalogOption? value;
  final ValueChanged<CatalogOption?> onChanged;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final selectedValue = _matchingValue();
    return _NativeFieldShell(
      label: label,
      requiredField: requiredField,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: options.isEmpty ? null : () => _openSelector(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _venderSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _venderBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedValue?.label ?? 'Seleccione',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedValue == null || options.isEmpty
                        ? _venderMuted
                        : AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const Icon(Icons.expand_more, color: AppColors.black, size: 21),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSelector(BuildContext context) async {
    final selected = await showDialog<CatalogOption>(
      context: context,
      builder: (context) =>
          _CatalogSearchDialog(label: label, options: options, value: value),
    );
    if (selected != null) onChanged(selected);
  }

  CatalogOption? _matchingValue() {
    for (final option in options) {
      if (option.id == value?.id) return option;
    }
    return null;
  }
}

class VenderNativeButton extends StatelessWidget {
  const VenderNativeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.white,
      disabledBackgroundColor: AppColors.gray100,
      disabledForegroundColor: _venderMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    final effectiveOnPressed = enabled ? onPressed : null;
    final button = icon == null
        ? FilledButton(
            onPressed: effectiveOnPressed,
            style: style,
            child: Text(label, textAlign: TextAlign.center),
          )
        : FilledButton.icon(
            onPressed: effectiveOnPressed,
            style: style,
            icon: icon!,
            label: Text(label, textAlign: TextAlign.center),
          );
    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class VenderYesNoSelector extends StatelessWidget {
  const VenderYesNoSelector({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _NativeRadio(
                label: 'Si',
                selected: value,
                onTap: () => onChanged(true),
              ),
              const SizedBox(width: 8),
              _NativeRadio(
                label: 'No',
                selected: !value,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VenderResponsiveRow extends StatelessWidget {
  const VenderResponsiveRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final child in children) ...[
          child,
          if (child != children.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class VenderStatusBanner extends StatelessWidget {
  const VenderStatusBanner({
    super.key,
    this.message,
    this.error,
    this.loading = false,
  });

  final String? message;
  final String? error;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isError = error != null && error!.trim().isNotEmpty;
    final text = isError ? error! : message;
    if (!loading && (text == null || text.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFFFF6AE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isError ? AppColors.red : const Color(0xFF8F7E01),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  isError ? Icons.error_outline : Icons.warning_amber_rounded,
                  color: isError ? AppColors.red : const Color(0xFF8F7E01),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loading ? 'Procesando solicitud...' : text!,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VenderEmptyState extends StatelessWidget {
  const VenderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 42, color: _venderMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: _venderMuted,
              fontFamily: 'Montserrat',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class VenderStepRail extends StatelessWidget {
  const VenderStepRail({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.highestStep,
    required this.onTap,
  });

  final List<VenderStepItem> steps;
  final int currentStep;
  final int highestStep;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final step = steps[index];
          final selected = index == currentStep;
          final enabled = index <= highestStep;
          return InkWell(
            onTap: enabled ? () => onTap(index) : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 118,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.black : AppColors.gray200,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                step.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.white : AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VenderStepItem {
  const VenderStepItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _NativeFieldShell extends StatelessWidget {
  const _NativeFieldShell({
    required this.label,
    required this.child,
    this.requiredField = false,
    this.tooltip,
  });

  final String label;
  final Widget child;
  final bool requiredField;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (tooltip != null) ...[
                const SizedBox(width: 5),
                Tooltip(
                  message: tooltip!,
                  child: const Icon(
                    Icons.info_outline,
                    color: AppColors.black,
                    size: 16,
                  ),
                ),
              ],
              if (requiredField) ...[
                const SizedBox(width: 5),
                const Text(
                  '*',
                  style: TextStyle(
                    color: AppColors.nativeBadgeRed,
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _NativeRadio extends StatelessWidget {
  const _NativeRadio({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 72, minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _venderSoftPurple : _venderSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _venderPurple : _venderBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _venderPurple : AppColors.black,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? _venderPurple : AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _underlineDecoration() {
  return const InputDecoration(
    isDense: true,
    filled: true,
    fillColor: _venderSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _venderBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _venderBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.accent, width: 1.2),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );
}

class _CatalogSearchDialog extends StatefulWidget {
  const _CatalogSearchDialog({
    required this.label,
    required this.options,
    required this.value,
  });

  final String label;
  final List<CatalogOption> options;
  final CatalogOption? value;

  @override
  State<_CatalogSearchDialog> createState() => _CatalogSearchDialogState();
}

class _CatalogSearchDialogState extends State<_CatalogSearchDialog> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _filteredOptions();
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.black),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.black),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const Divider(color: AppColors.gray200, thickness: 2),
              TextField(
                controller: _query,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Prospero'),
                decoration: const InputDecoration(
                  labelText: 'Filtrar por nombre',
                  prefixIcon: Icon(Icons.search, color: AppColors.black),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: options.isEmpty
                    ? const VenderEmptyState(
                        icon: Icons.search_off,
                        title: 'Sin resultados',
                        message: 'No hay coincidencias para el filtro.',
                      )
                    : ListView.separated(
                        itemCount: options.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final selected = option.id == widget.value?.id;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: AppColors.black,
                            ),
                            title: Text(
                              option.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Prospero'),
                            ),
                            subtitle: option.id.trim().isEmpty
                                ? null
                                : Text(option.id),
                            onTap: () => Navigator.of(context).pop(option),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<CatalogOption> _filteredOptions() {
    final query = _query.text.trim().toLowerCase();
    final source = query.isEmpty
        ? widget.options
        : widget.options.where((option) {
            return option.label.toLowerCase().contains(query) ||
                option.id.toLowerCase().contains(query);
          });
    return source.take(100).toList();
  }
}
