import 'package:flutter/material.dart';

import '../controllers/bloques_flow_controller.dart';
import '../widgets/bloques_widgets.dart';

class BloquesPendingBlocksView extends StatelessWidget {
  const BloquesPendingBlocksView({
    super.key,
    required this.controller,
    required this.runAction,
  });

  final BloquesFlowController controller;
  final Future<void> Function(Future<void> Function() action) runAction;

  @override
  Widget build(BuildContext context) {
    final blocks = controller.pendingBlocks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 96),
      children: [
        OutlinedButton.icon(
          onPressed: controller.busyRemote
              ? null
              : () => runAction(() => controller.refreshPendingBlocks()),
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar bloques'),
        ),
        const SizedBox(height: 12),
        if (blocks.isEmpty)
          const BloquesEmptyState(
            icon: Icons.all_inbox_outlined,
            title: 'Sin bloques pendientes',
            message: 'No hay bloques en gestion para este centro.',
          )
        else
          ...blocks.map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BloquesPendingBlockTile(
                block: block,
                busy: controller.busyRemote,
                onValidate: () {
                  runAction(() => controller.validateBlockManagement(block));
                },
                onAssign: () {
                  runAction(() => controller.assignBlock(block));
                },
              ),
            ),
          ),
      ],
    );
  }
}
