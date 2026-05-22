import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
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
        const SizedBox(height: 8),
        _SelectedServiceField(
          selected: controller.selectedQuote?.name ?? 'Clase Servicio',
          onPressed: () => runAction(controller.quoteServices),
        ),
        VenderCatalogDropdown(
          label: 'Tipo de envio',
          options: controller.shippingTypes,
          value: controller.shippingType,
          onChanged: controller.selectShippingType,
          requiredField: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: VenderNativeButton(
            label: 'Consultar servicios',
            fullWidth: true,
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => runAction(controller.quoteServices),
          ),
        ),
        if (controller.serviceQuotes.isEmpty)
          const VenderEmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'Sin servicios liquidados',
            message: 'Calcula la liquidacion para ver servicios habilitados.',
          )
        else
          _QuoteList(
            quotes: controller.serviceQuotes,
            selected: controller.selectedQuote,
            onSelect: controller.selectQuote,
          ),
        VenderTextInput(
          label: 'Contenido',
          controller: controller.content,
          requiredField: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        VenderTextInput(
          label: 'Bolsa de seguridad (Opcional)',
          controller: controller.securityBag,
          keyboardType: TextInputType.text,
        ),
        VenderCatalogDropdown(
          label: 'Agregar empaque',
          options: catalogs.packages,
          value: controller.selectedPackage,
          onChanged: controller.setSelectedPackage,
        ),
        VenderTextInput(
          label: 'Observaciones (Opcional)',
          controller: controller.observations,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        VenderYesNoSelector(
          title: 'Verificacion de contenido',
          value: controller.contentChecked,
          onChanged: controller.setContentChecked,
        ),
        if (controller.selectedQuote != null) ...[
          const SizedBox(height: 6),
          _Totals(quote: controller.selectedQuote!),
        ],
        const SizedBox(height: 44),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Agregar empaque',
            style: TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 21,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SelectedServiceField extends StatelessWidget {
  const _SelectedServiceField({
    required this.selected,
    required this.onPressed,
  });

  final String selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Tipo de servicio',
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Prospero',
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 5),
              Text(
                '*',
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 24,
                  height: 0.8,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 8, right: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.black)),
              ),
              child: Text(
                selected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Prospero',
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteList extends StatelessWidget {
  const _QuoteList({
    required this.quotes,
    required this.selected,
    required this.onSelect,
  });

  final List<VenderServiceQuote> quotes;
  final VenderServiceQuote? selected;
  final ValueChanged<VenderServiceQuote> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.black),
        ),
        child: Column(
          children: [
            for (final quote in quotes.take(6)) ...[
              _QuoteTile(
                quote: quote,
                selected: selected?.id == quote.id,
                onTap: () => onSelect(quote),
              ),
              if (quote != quotes.take(6).last)
                const Divider(height: 1, color: AppColors.gray200),
            ],
          ],
        ),
      ),
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
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        color: selected ? AppColors.gray200 : AppColors.white,
        child: Row(
          children: [
            Expanded(child: _QuoteCell(quote.name)),
            const _QuoteSeparator(),
            Expanded(child: _QuoteCell(_deliveryText(quote.deliveryDays))),
            const _QuoteSeparator(),
            Expanded(child: _QuoteCell(_money(quote.baseValue))),
            const _QuoteSeparator(),
            Expanded(child: _QuoteCell(_money(quote.insuranceValue))),
            const _QuoteSeparator(),
            Expanded(child: _QuoteCell(_money(quote.totalValue), strong: true)),
          ],
        ),
      ),
    );
  }

  String _deliveryText(int days) {
    if (days <= 0) return 'Entrega';
    return '$days dias';
  }
}

class _QuoteCell extends StatelessWidget {
  const _QuoteCell(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.black,
          fontFamily: 'Montserrat',
          fontSize: 10,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuoteSeparator extends StatelessWidget {
  const _QuoteSeparator();

  @override
  Widget build(BuildContext context) {
    return const Text('|', style: TextStyle(color: AppColors.black));
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.quote});

  final VenderServiceQuote quote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 15, 24, 0),
      child: Column(
        children: [
          _TotalRow('Forma pago', 'Contado'),
          _TotalRow('Servicio', quote.name, amount: quote.totalValue),
          _TotalRow('Empaque', 'Sin empaque', amount: 0),
          const SizedBox(height: 5),
          _TotalRow('Total', '', amount: quote.totalValue, strong: true),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.amount, this.strong = false});

  final String label;
  final String value;
  final double? amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: strong ? 158 : 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 16,
              ),
            ),
          ),
          if (amount != null)
            SizedBox(
              width: 112,
              child: Text(
                _money(amount!),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _money(double value) => '\$${value.toStringAsFixed(0)}';
