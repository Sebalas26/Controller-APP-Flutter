import 'package:flutter/material.dart';

import '../../models/vender_models.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

class VenderSettlementView extends StatelessWidget {
  const VenderSettlementView({
    super.key,
    required this.controller,
    required this.runAction,
  });

  final VenderFlowController controller;
  final Future<void> Function(Future<void> Function()) runAction;

  @override
  Widget build(BuildContext context) {
    final catalogs = controller.catalogs;
    if (catalogs == null) {
      return const VenderEmptyState(
        icon: Icons.request_quote_outlined,
        title: 'Liquidacion no disponible',
        message: 'Primero carga los catalogos locales.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VenderSectionTitle(
          icon: Icons.request_quote_outlined,
          title: 'Confirmar liquidacion',
          subtitle: 'Servicios y valores calculados con tarifas offline',
        ),
        const SizedBox(height: 16),
        VenderResponsiveRow(
          children: [
            VenderCatalogDropdown(
              label: 'Tipo de envio',
              options: controller.shippingTypes,
              value: controller.shippingType,
              onChanged: controller.selectShippingType,
            ),
            OutlinedButton.icon(
              onPressed: () => runAction(controller.quoteServices),
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Consultar servicios'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (controller.serviceQuotes.isEmpty)
          const VenderEmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'Sin servicios liquidados',
            message: 'Calcula la liquidacion para ver servicios habilitados.',
          )
        else
          Column(
            children: [
              for (final quote in controller.serviceQuotes) ...[
                _QuoteTile(
                  quote: quote,
                  selected: controller.selectedQuote?.id == quote.id,
                  onTap: () => controller.selectQuote(quote),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        const SizedBox(height: 14),
        VenderResponsiveRow(
          children: [
            VenderTextInput(label: 'Contenido', controller: controller.content),
            VenderTextInput(
              label: 'Bolsa de seguridad',
              controller: controller.securityBag,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        const SizedBox(height: 14),
        VenderCatalogDropdown(
          label: 'Agregar empaque',
          options: catalogs.packages,
          value: controller.selectedPackage,
          onChanged: controller.setSelectedPackage,
        ),
        const SizedBox(height: 14),
        VenderTextInput(
          label: 'Observaciones',
          controller: controller.observations,
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: controller.contentChecked,
          onChanged: controller.setContentChecked,
          title: const Text('Verificacion de contenido'),
        ),
        if (controller.selectedQuote != null) ...[
          const SizedBox(height: 10),
          _Totals(quote: controller.selectedQuote!),
        ],
      ],
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({
    required this.quote,
    required this.selected,
    required this.onTap,
  });

  final VenderServiceQuote quote;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8EFF7) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF2569B3) : const Color(0xFFE1E6EF),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: const Color(0xFF2569B3),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Base ${_money(quote.baseValue)} + prima ${_money(quote.insuranceValue)}',
                      style: const TextStyle(color: Color(0xFF696F79)),
                    ),
                  ],
                ),
              ),
              Text(
                _money(quote.totalValue),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.quote});

  final VenderServiceQuote quote;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _TotalRow('Valor flete', quote.baseValue),
            _TotalRow('Prima seguro', quote.insuranceValue),
            const Divider(),
            _TotalRow('Total', quote.totalValue, strong: true),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.strong = false});

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double value) => '\$${value.toStringAsFixed(0)}';
