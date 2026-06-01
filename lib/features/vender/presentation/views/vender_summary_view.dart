import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

const _surface = Color(0xFFFEFEFE);
const _muted = Color(0xFF727272);
const _darkMuted = Color(0xFF575757);

class VenderSummaryView extends StatelessWidget {
  const VenderSummaryView({
    super.key,
    required this.controller,
    required this.runAction,
  });

  final VenderFlowController controller;
  final Future<void> Function(Future<void> Function()) runAction;

  @override
  Widget build(BuildContext context) {
    final catalogs = controller.catalogs;
    final quote = controller.selectedQuote;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(
            title: 'Datos del envío',
            rows: [
              _SummaryRowData('Origen', controller.appInformation.nombreCiudad),
              _SummaryRowData(
                'Destino',
                controller.destinationCity?.label ?? '',
              ),
              _SummaryRowData('Entrega', controller.deliveryType?.label ?? ''),
              _SummaryRowData(
                'Peso final',
                controller.finalWeight.toStringAsFixed(2),
              ),
              _SummaryRowData(
                'Valor comercial',
                controller.commercialValue.toStringAsFixed(0),
              ),
              _SummaryRowData('Servicio', quote?.name ?? ''),
              _SummaryRowData(
                'Total',
                quote?.totalValue.toStringAsFixed(0) ?? '',
                prominent: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SummaryCard(
            title: 'Remitente',
            rowSpacing: 8,
            rows: [
              _SummaryRowData('Nombre', _person(controller, true)),
              _SummaryRowData('Dirección', controller.senderAddress.text),
            ],
          ),
          const SizedBox(height: 24),
          _SummaryCard(
            title: 'Destinatario',
            rowSpacing: 8,
            rows: [
              _SummaryRowData('Nombre', _person(controller, false)),
              _SummaryRowData('Dirección', controller.recipientAddress.text),
            ],
          ),
          if (catalogs != null) ...[
            const SizedBox(height: 24),
            _SuppliesCard(
              available: catalogs.availableSupplies,
              used: catalogs.usedSupplies,
              pending: catalogs.pendingOfflineAdmissions,
              busy: controller.busyRemote,
              runAction: runAction,
              onRefresh: controller.refreshSupplies,
              onSynchronize: controller.synchronizeOfflineAdmissions,
            ),
          ],
        ],
      ),
    );
  }

  String _person(VenderFlowController controller, bool sender) {
    final name = sender
        ? controller.senderName.text
        : controller.recipientName.text;
    final lastName = sender
        ? controller.senderFirstLastName.text
        : controller.recipientFirstLastName.text;
    final document = sender
        ? controller.senderDocument.text
        : controller.recipientDocument.text;
    return '$name $lastName - $document'.trim();
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
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

class _SuppliesCard extends StatelessWidget {
  const _SuppliesCard({
    required this.available,
    required this.used,
    required this.pending,
    required this.busy,
    required this.runAction,
    required this.onRefresh,
    required this.onSynchronize,
  });

  final int available;
  final int used;
  final int pending;
  final bool busy;
  final Future<void> Function(Future<void> Function()) runAction;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSynchronize;

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
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Suministros offline',
                  style: TextStyle(
                    color: _muted,
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _SupplyLine('Disponibles', available),
            const SizedBox(height: 4),
            _SupplyLine('Usados', used),
            const SizedBox(height: 4),
            _SupplyLine('Admisiones pendientes', pending),
            const SizedBox(height: 12),
            VenderNativeButton(
              label: 'Recargar suministros',
              fullWidth: true,
              icon: const Icon(Icons.sync),
              onPressed: busy ? null : () => runAction(onRefresh),
            ),
            const SizedBox(height: 8),
            VenderNativeButton(
              label: 'Sincronizar admisiones',
              fullWidth: true,
              icon: const Icon(Icons.cloud_upload_outlined),
              enabled: !busy && pending > 0,
              onPressed: () => runAction(onSynchronize),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplyLine extends StatelessWidget {
  const _SupplyLine(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _darkMuted,
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
