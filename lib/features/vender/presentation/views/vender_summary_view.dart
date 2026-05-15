import 'package:flutter/material.dart';

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
        const VenderSectionTitle(
          icon: Icons.fact_check_outlined,
          title: 'Resumen admision',
          subtitle: 'Registro local listo para sincronizacion offline',
        ),
        const SizedBox(height: 16),
        _SummaryRow('Origen', controller.appInformation.nombreCiudad),
        _SummaryRow('Destino', controller.destinationCity?.label ?? ''),
        _SummaryRow('Entrega', controller.deliveryType?.label ?? ''),
        _SummaryRow('Peso final', controller.finalWeight.toStringAsFixed(2)),
        _SummaryRow(
          'Valor comercial',
          controller.commercialValue.toStringAsFixed(0),
        ),
        _SummaryRow('Servicio', quote?.name ?? ''),
        _SummaryRow('Total', quote?.totalValue.toStringAsFixed(0) ?? ''),
        const Divider(height: 28),
        _SummaryRow('Remitente', _person(controller, true)),
        _SummaryRow('Direccion remitente', controller.senderAddress.text),
        _SummaryRow('Destinatario', _person(controller, false)),
        _SummaryRow('Direccion destinatario', controller.recipientAddress.text),
        const SizedBox(height: 16),
        if (catalogs != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suministros offline',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text('Disponibles: ${catalogs.availableSupplies}'),
                  Text('Usados: ${catalogs.usedSupplies}'),
                  Text(
                    'Admisiones pendientes: ${catalogs.pendingOfflineAdmissions}',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: controller.busyRemote
                            ? null
                            : () => runAction(controller.refreshSupplies),
                        icon: const Icon(Icons.sync),
                        label: const Text('Recargar suministros'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            controller.busyRemote ||
                                catalogs.pendingOfflineAdmissions == 0
                            ? null
                            : () => runAction(
                                controller.synchronizeOfflineAdmissions,
                              ),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Sincronizar admisiones'),
                      ),
                    ],
                  ),
                ],
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF696F79),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
