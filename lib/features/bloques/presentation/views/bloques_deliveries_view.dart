import 'package:flutter/material.dart';

import '../controllers/bloques_flow_controller.dart';
import '../widgets/bloques_widgets.dart';

class BloquesDeliveriesView extends StatelessWidget {
  const BloquesDeliveriesView({
    super.key,
    required this.controller,
    required this.runAction,
  });

  final BloquesFlowController controller;
  final Future<void> Function(Future<void> Function() action) runAction;

  @override
  Widget build(BuildContext context) {
    final deliveries = controller.deliveries;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 96),
      children: [
        if (controller.courier != null) ...[
          BloquesCourierSummary(courier: controller.courier!),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.busyRemote
                    ? null
                    : () => runAction(() => controller.refreshDeliveries()),
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: controller.busyRemote || deliveries.isEmpty
                    ? null
                    : () => runAction(controller.assignCurrentSheet),
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Asignar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (deliveries.isEmpty)
          const BloquesEmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'Sin entregas',
            message: 'Valida un mensajero para consultar sus guias.',
          )
        else
          ...deliveries.map(
            (delivery) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BloquesDeliveryTile(
                delivery: delivery,
                onToggleVerified: () {
                  controller.markDeliveryVerified(delivery.guideNumber);
                },
              ),
            ),
          ),
      ],
    );
  }
}
