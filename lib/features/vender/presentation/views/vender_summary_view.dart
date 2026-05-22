import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _NativeSummaryBlock(
          title: 'Datos del envio',
          rows: [
            _SummaryData('Origen', controller.appInformation.nombreCiudad),
            _SummaryData('Destino', controller.destinationCity?.label ?? ''),
            _SummaryData('Entrega', controller.deliveryType?.label ?? ''),
            _SummaryData(
              'Peso final',
              controller.finalWeight.toStringAsFixed(2),
            ),
            _SummaryData(
              'Valor comercial',
              controller.commercialValue.toStringAsFixed(0),
            ),
            _SummaryData('Servicio', quote?.name ?? ''),
            _SummaryData('Total', quote?.totalValue.toStringAsFixed(0) ?? ''),
          ],
        ),
        _NativeSummaryBlock(
          title: 'Remitente',
          rows: [
            _SummaryData('Nombre', _person(controller, true)),
            _SummaryData('Direccion', controller.senderAddress.text),
          ],
        ),
        _NativeSummaryBlock(
          title: 'Destinatario',
          rows: [
            _SummaryData('Nombre', _person(controller, false)),
            _SummaryData('Direccion', controller.recipientAddress.text),
          ],
        ),
        if (catalogs != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gray200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suministros offline',
                      style: TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SupplyLine('Disponibles', catalogs.availableSupplies),
                    _SupplyLine('Usados', catalogs.usedSupplies),
                    _SupplyLine(
                      'Admisiones pendientes',
                      catalogs.pendingOfflineAdmissions,
                    ),
                    const SizedBox(height: 12),
                    VenderNativeButton(
                      label: 'Recargar suministros',
                      fullWidth: true,
                      icon: const Icon(Icons.sync),
                      onPressed: controller.busyRemote
                          ? null
                          : () => runAction(controller.refreshSupplies),
                    ),
                    const SizedBox(height: 8),
                    VenderNativeButton(
                      label: 'Sincronizar admisiones',
                      fullWidth: true,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      enabled:
                          !controller.busyRemote &&
                          catalogs.pendingOfflineAdmissions > 0,
                      onPressed: () =>
                          runAction(controller.synchronizeOfflineAdmissions),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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

class _NativeSummaryBlock extends StatelessWidget {
  const _NativeSummaryBlock({required this.title, required this.rows});

  final String title;
  final List<_SummaryData> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.black),
                bottom: BorderSide(color: AppColors.black),
              ),
            ),
            child: Column(
              children: [
                for (final row in rows) _SummaryRow(row.label, row.value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData(this.label, this.value);

  final String label;
  final String value;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Prospero',
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Prospero',
                fontSize: 16,
              ),
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
