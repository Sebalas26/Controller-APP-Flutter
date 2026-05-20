import 'package:flutter/material.dart';

import '../../models/vender_models.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

class VenderPaymentView extends StatelessWidget {
  const VenderPaymentView({super.key, required this.controller});

  final VenderFlowController controller;

  @override
  Widget build(BuildContext context) {
    final collection = controller.collectionState;
    if (collection == null) {
      return const VenderEmptyState(
        icon: Icons.payments_outlined,
        title: 'Sin cobro pendiente',
        message: 'No hay guias sincronizadas listas para cobrar.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VenderSectionTitle(
          icon: Icons.payments_outlined,
          title: 'Cobrar venta',
          subtitle: collection.confirmed
              ? 'Cobro finalizado'
              : 'Guias sincronizadas listas para recaudo',
        ),
        const SizedBox(height: 16),
        _TotalsBlock(collection: collection),
        const SizedBox(height: 16),
        _PaymentMethodSelector(
          collection: collection,
          onSelected: controller.selectCollectionPaymentMethod,
        ),
        const SizedBox(height: 16),
        ...collection.guides.map((guide) => _GuideChargeTile(guide: guide)),
      ],
    );
  }
}

class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({required this.collection});

  final VenderCollectionState collection;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _SummaryLine('Guias admitidas', collection.guideCount.toString()),
            _SummaryLine(
              'Prefactura',
              collection.idPreInvoice <= 0
                  ? '-'
                  : collection.idPreInvoice.toString(),
            ),
            _SummaryLine('Valor guias', _money(collection.totalGuidesValue)),
            _SummaryLine('Valor recogida', _money(collection.pickupValue)),
            _SummaryLine('Empaques', _money(collection.packageValue)),
            const Divider(height: 24),
            _SummaryLine(
              'Total a cobrar',
              _money(collection.totalToCharge),
              prominent: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.collection,
    required this.onSelected,
  });

  final VenderCollectionState collection;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final method in VenderPaymentMethods.chargeable)
          ChoiceChip(
            label: Text(VenderPaymentMethods.nameFor(method)),
            selected: collection.selectedPaymentMethodId == method,
            onSelected: collection.confirmed ? null : (_) => onSelected(method),
            avatar: Icon(_iconFor(method), size: 18),
          ),
      ],
    );
  }

  IconData _iconFor(int method) {
    return switch (method) {
      VenderPaymentMethods.nequi => Icons.phone_android,
      VenderPaymentMethods.linkPayment => Icons.link,
      VenderPaymentMethods.interPay => Icons.account_balance_wallet_outlined,
      _ => Icons.payments_outlined,
    };
  }
}

class _GuideChargeTile extends StatelessWidget {
  const _GuideChargeTile({required this.guide});

  final VenderCollectionGuide guide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E6EF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      guide.guideNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    _money(guide.shouldChargeNow ? guide.totalValue : 0),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SummaryLine('Forma pago', guide.paymentMethodLabel),
              _SummaryLine('Remitente', guide.senderName),
              _SummaryLine('Documento', guide.senderDocument),
              _SummaryLine('Telefono', guide.senderPhone),
              _SummaryLine('Destinatario', guide.recipientName),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value, {this.prominent = false});

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF696F79),
                fontWeight: prominent ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: prominent ? 18 : 14,
                fontWeight: prominent ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double value) {
  final normalized = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < normalized.length; i++) {
    final remaining = normalized.length - i;
    buffer.write(normalized[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return '\$ ${buffer.toString()}';
}
