import 'package:flutter/material.dart';

import '../../models/vender_models.dart';

class VenderPanel extends StatelessWidget {
  const VenderPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF2569B3)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: Color(0xFF696F79),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(labelText: label),
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
  });

  final String label;
  final List<CatalogOption> options;
  final CatalogOption? value;
  final ValueChanged<CatalogOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue = _matchingValue();
    return DropdownButtonFormField<CatalogOption>(
      initialValue: selectedValue,
      items: options
          .map(
            (option) => DropdownMenuItem<CatalogOption>(
              value: option,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: options.isEmpty ? null : onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }

  CatalogOption? _matchingValue() {
    for (final option in options) {
      if (option.id == value?.id) return option;
    }
    return null;
  }
}

class VenderResponsiveRow extends StatelessWidget {
  const VenderResponsiveRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                if (child != children.last) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final child in children) ...[
              Expanded(child: child),
              if (child != children.last) const SizedBox(width: 14),
            ],
          ],
        );
      },
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8EFF7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFCF1111) : const Color(0xFFBFD2EA),
        ),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError
                  ? const Color(0xFFCF1111)
                  : const Color(0xFF2569B3),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading ? 'Procesando solicitud...' : text!,
              style: TextStyle(
                color: isError
                    ? const Color(0xFF8A0A0A)
                    : const Color(0xFF1F4F82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF696F79)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF696F79)),
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
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final step = steps[index];
          final selected = index == currentStep;
          final enabled = index <= highestStep;
          return SizedBox(
            width: 136,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: enabled ? () => onTap(index) : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF212529) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE1E6EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        step.icon,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF2569B3),
                      ),
                      const Spacer(),
                      Text(
                        step.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF212529),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
