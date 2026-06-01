import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/vender_models.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

const _surface = Color(0xFFFEFEFE);
const _border = Color(0xFFE0E0E0);
const _muted = Color(0xFF727272);
const _darkMuted = Color(0xFF575757);

class VenderBillingSummaryView extends StatelessWidget {
  const VenderBillingSummaryView({
    super.key,
    required this.controller,
    required this.runAction,
    required this.onBack,
  });

  final VenderFlowController controller;
  final Future<void> Function(Future<void> Function()) runAction;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final collection = controller.collectionState;
    if (collection == null || collection.guides.isEmpty) {
      return const Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          child: VenderEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Sin guias admitidas',
            message: 'No hay guias listas para facturar.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            _SummaryHeader(onBack: onBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CustomerCard(guide: collection.guides.first),
                    const SizedBox(height: 24),
                    _ShippingCountCard(collection: collection),
                    const SizedBox(height: 24),
                    _LiquidationCard(collection: collection),
                    const SizedBox(height: 24),
                    _PaymentMethodField(
                      collection: collection,
                      enabled: !controller.busyRemote,
                      onSelected: controller.selectCollectionPaymentMethod,
                    ),
                    if (collection.paymentMessage.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PaymentStatusCard(collection: collection),
                    ],
                    const SizedBox(height: 32),
                    _ContinueButton(
                      loading: controller.busyRemote,
                      label:
                          collection.paymentTransactionId > 0 &&
                              !collection.confirmed
                          ? 'Consultar pago'
                          : 'Continuar',
                      onPressed: () =>
                          runAction(controller.invoiceAdmittedGuides),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.black),
              tooltip: 'Atras',
            ),
            const Expanded(
              child: Text(
                'Resumen de venta',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.guide});

  final VenderCollectionGuide guide;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      title: 'Cliente',
      rowSpacing: 8,
      rows: [
        _SummaryRowData('Identificación:', guide.senderDocument),
        _SummaryRowData('Celular:', guide.senderPhone),
        _SummaryRowData('Nombre:', guide.senderName),
      ],
    );
  }
}

class _ShippingCountCard extends StatelessWidget {
  const _ShippingCountCard({required this.collection});

  final VenderCollectionState collection;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      title: 'Cantidad de envíos',
      rows: [
        _SummaryRowData('Al cobro', collection.collectGuideCount.toString()),
        _SummaryRowData('Contado:', collection.cashGuideCount.toString()),
        _SummaryRowData('Crédito:', collection.creditGuideCount.toString()),
      ],
    );
  }
}

class _LiquidationCard extends StatelessWidget {
  const _LiquidationCard({required this.collection});

  final VenderCollectionState collection;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      title: 'Liquidación',
      rows: [
        _SummaryRowData('Valor recogida:', _money(collection.pickupValue)),
        _SummaryRowData('Empaque', _money(collection.packageValue)),
        _SummaryRowData(
          'Valor guías contado',
          _money(collection.totalGuidesValue),
        ),
        _SummaryRowData(
          'Total a cobrar',
          _money(collection.totalToCharge),
          prominent: true,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.rows,
    this.rowSpacing = 4,
  });

  final String title;
  final List<_SummaryRowData> rows;
  final double rowSpacing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _darkMuted.withValues(alpha: 0.15),
            offset: const Offset(-2, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0 || rowSpacing > 0) SizedBox(height: rowSpacing),
              _SummaryRow(row: rows[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.row});

  final _SummaryRowData row;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: row.prominent ? AppColors.black : _darkMuted,
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: row.prominent ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              row.value.trim().isEmpty ? '-' : row.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: row.prominent ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRowData {
  const _SummaryRowData(this.label, this.value, {this.prominent = false});

  final String label;
  final String value;
  final bool prominent;
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({required this.collection});

  final VenderCollectionState collection;

  @override
  Widget build(BuildContext context) {
    final approved = collection.confirmed;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: approved ? const Color(0xFFEFF8F1) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: approved ? AppColors.green : const Color(0xFFF2A900),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              approved ? Icons.check_circle_outline : Icons.info_outline,
              color: AppColors.black,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                collection.paymentMessage,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodField extends StatelessWidget {
  const _PaymentMethodField({
    required this.collection,
    required this.enabled,
    required this.onSelected,
  });

  final VenderCollectionState collection;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final methods = VenderPaymentMethods.chargeable;
    final selected = methods.contains(collection.selectedPaymentMethodId)
        ? collection.selectedPaymentMethodId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Método de pago',
          style: TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: DropdownButtonFormField<int>(
            initialValue: selected,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.black),
            hint: const Text(
              'Seleccionar',
              style: TextStyle(
                color: _muted,
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            items: [
              for (final method in methods)
                DropdownMenuItem<int>(
                  value: method,
                  child: Text(VenderPaymentMethods.nameFor(method)),
                ),
            ],
            onChanged: enabled
                ? (value) {
                    if (value != null) onSelected(value);
                  }
                : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.black),
              ),
            ),
            style: const TextStyle(
              color: _muted,
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: loading ? AppColors.gray500 : AppColors.black,
      elevation: 8,
      shadowColor: _darkMuted.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              loading ? 'Procesando...' : label,
              style: const TextStyle(
                color: _surface,
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
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
  return '\$${buffer.toString()}';
}
