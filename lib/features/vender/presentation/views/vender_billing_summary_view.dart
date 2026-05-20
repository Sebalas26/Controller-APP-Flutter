import 'package:flutter/material.dart';

import '../../models/vender_models.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

class VenderBillingSummaryView extends StatelessWidget {
  const VenderBillingSummaryView({super.key, required this.controller});

  final VenderFlowController controller;

  @override
  Widget build(BuildContext context) {
    final collection = controller.collectionState;
    if (collection == null || collection.guides.isEmpty) {
      return const VenderEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Sin guias admitidas',
        message: 'No hay guias listas para facturar.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VenderSectionTitle(
          icon: Icons.receipt_long_outlined,
          title: 'Resumen venta',
          subtitle: 'Verifica las guias admitidas antes de facturar',
        ),
        const SizedBox(height: 16),
        _TotalsBlock(collection: collection),
        const SizedBox(height: 16),
        _PaymentBlock(collection: collection),
        const SizedBox(height: 16),
        ...collection.guides.map((guide) => _GuideSummaryTile(guide: guide)),
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
            _SummaryLine('Total envios', collection.guideCount.toString()),
            _SummaryLine('Contado', collection.cashGuideCount.toString()),
            _SummaryLine('Credito', collection.creditGuideCount.toString()),
            _SummaryLine('Al cobro', collection.collectGuideCount.toString()),
            _SummaryLine(
              'Prefactura',
              collection.idPreInvoice <= 0
                  ? '-'
                  : collection.idPreInvoice.toString(),
            ),
            const Divider(height: 24),
            _SummaryLine(
              'Valor guia contado',
              _money(collection.totalGuidesValue),
            ),
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

class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({required this.collection});

  final VenderCollectionState collection;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        Chip(
          label: Text(collection.selectedPaymentMethodName),
          avatar: const Icon(Icons.payments_outlined, size: 18),
        ),
        const _UnavailableChip(icon: Icons.phone_android, label: 'Nequi'),
        const _UnavailableChip(icon: Icons.link, label: 'Link de pago'),
        const _UnavailableChip(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Inter Pay',
        ),
      ],
    );
  }
}

class _UnavailableChip extends StatelessWidget {
  const _UnavailableChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: const Color(0xFF696F79)),
      label: Text('$label no disponible'),
      backgroundColor: const Color(0xFFF4F5F7),
      side: const BorderSide(color: Color(0xFFE1E6EF)),
    );
  }
}

class _GuideSummaryTile extends StatelessWidget {
  const _GuideSummaryTile({required this.guide});

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
            width: 138,
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
