import 'package:flutter/material.dart';

import '../../models/bloques_models.dart';
import '../controllers/bloques_flow_controller.dart';
import '../widgets/bloques_widgets.dart';

class BloquesCourierView extends StatefulWidget {
  const BloquesCourierView({
    super.key,
    required this.controller,
    required this.runAction,
    required this.onScan,
    required this.onOpenDeliveries,
  });

  final BloquesFlowController controller;
  final Future<void> Function(Future<void> Function() action) runAction;
  final Future<YaapQrIdentity?> Function() onScan;
  final VoidCallback onOpenDeliveries;

  @override
  State<BloquesCourierView> createState() => _BloquesCourierViewState();
}

class _BloquesCourierViewState extends State<BloquesCourierView> {
  final _documentController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _documentController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courier = widget.controller.courier;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 96),
      children: [
        BloquesPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _documentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Documento mensajero',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Codigo OTP',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.controller.busyRemote
                          ? null
                          : _scanIdentity,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Escanear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.controller.busyRemote
                          ? null
                          : () => widget.runAction(_identify),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Validar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (courier == null)
          const BloquesEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'Sin mensajero validado',
            message: 'Escanea el QR o ingresa documento y OTP.',
          )
        else ...[
          BloquesCourierSummary(courier: courier),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onOpenDeliveries,
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text('Ver ${courier.guideNumbers.length} entregas'),
          ),
        ],
      ],
    );
  }

  Future<void> _scanIdentity() async {
    final identity = await widget.onScan();
    if (identity == null || !mounted) return;
    setState(() {
      _documentController.text = identity.document;
      _otpController.text = identity.otp;
    });
  }

  Future<void> _identify() {
    return widget.controller.identifyCourier(
      _documentController.text,
      _otpController.text,
    );
  }
}
