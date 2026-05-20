import 'package:flutter/material.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../login/login.dart';
import 'controllers/vender_flow_controller.dart';
import 'views/vender_initial_view.dart';
import 'views/vender_person_view.dart';
import 'views/vender_payment_view.dart';
import 'views/vender_settlement_view.dart';
import 'views/vender_summary_view.dart';
import 'widgets/vender_form_widgets.dart';

class VenderPage extends StatefulWidget {
  const VenderPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<VenderPage> createState() => _VenderPageState();
}

class _VenderPageState extends State<VenderPage> {
  static const _steps = [
    VenderStepItem(Icons.inventory_2_outlined, 'Datos envio'),
    VenderStepItem(Icons.request_quote_outlined, 'Liquidacion'),
    VenderStepItem(Icons.person_outline, 'Remitente'),
    VenderStepItem(Icons.location_on_outlined, 'Destinatario'),
    VenderStepItem(Icons.fact_check_outlined, 'Resumen'),
    VenderStepItem(Icons.payments_outlined, 'Cobrar'),
  ];

  late final VenderFlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VenderFlowController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_onControllerChanged);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) {
      return const VenderPanel(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_controller.hasCatalogs) {
      return VenderPanel(
        child: VenderEmptyState(
          icon: Icons.storage_outlined,
          title: 'Vender sin catalogos',
          message:
              _controller.errorMessage ??
              'Ejecuta la sincronizacion inicial para cargar datos locales.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VenderStatus(controller: _controller),
        const SizedBox(height: 12),
        VenderStatusBanner(
          message: _controller.statusMessage,
          error: _controller.errorMessage,
          loading: _controller.busyRemote || _controller.saving,
        ),
        const SizedBox(height: 12),
        VenderStepRail(
          steps: _steps,
          currentStep: _controller.currentStep,
          highestStep: _controller.highestStep,
          onTap: _controller.setStep,
        ),
        const SizedBox(height: 12),
        VenderPanel(child: _bodyForStep()),
        const SizedBox(height: 12),
        _footer(),
      ],
    );
  }

  Widget _bodyForStep() {
    switch (_controller.currentStep) {
      case 0:
        return VenderInitialView(
          controller: _controller,
          runAction: _runAction,
        );
      case 1:
        return VenderSettlementView(
          controller: _controller,
          runAction: _runAction,
        );
      case 2:
        return VenderPersonView(
          controller: _controller,
          kind: VenderPersonKind.sender,
          runAction: _runAction,
        );
      case 3:
        return VenderPersonView(
          controller: _controller,
          kind: VenderPersonKind.recipient,
          runAction: _runAction,
        );
      case 4:
        return VenderSummaryView(
          controller: _controller,
          runAction: _runAction,
        );
      default:
        return VenderPaymentView(controller: _controller);
    }
  }

  Widget _footer() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _controller.currentStep == 0 || _controller.saving
                ? null
                : _controller.previousStep,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Atras'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _controller.saving
                ? null
                : () => _runAction(_controller.nextStep),
            icon: Icon(
              _controller.currentStep == 4
                  ? Icons.save_outlined
                  : _controller.currentStep == _steps.length - 1
                  ? _controller.collectionState?.confirmed == true
                        ? Icons.add
                        : Icons.payments_outlined
                  : Icons.arrow_forward,
            ),
            label: Text(_footerLabel()),
          ),
        ),
      ],
    );
  }

  String _footerLabel() {
    if (_controller.currentStep == 4) return 'Guardar admision';
    if (_controller.currentStep == _steps.length - 1) {
      if (_controller.collectionState?.confirmed == true) return 'Nueva venta';
      return _controller.collectionState?.actionLabel ?? 'Confirmar cobro';
    }
    return 'Siguiente';
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _VenderStatus extends StatelessWidget {
  const _VenderStatus({required this.controller});

  final VenderFlowController controller;

  @override
  Widget build(BuildContext context) {
    final catalogs = controller.catalogs;
    return VenderPanel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatusChip(
            icon: controller.offline ? Icons.wifi_off : Icons.wifi,
            label: controller.offline ? 'Offline' : 'Online',
          ),
          _StatusChip(
            icon: Icons.price_change_outlined,
            label:
                'Lista ${controller.priceListId == 0 ? '-' : controller.priceListId}',
          ),
          _StatusChip(
            icon: Icons.inventory_2_outlined,
            label: 'Suministros ${catalogs?.availableSupplies ?? 0}',
          ),
          _StatusChip(
            icon: Icons.pending_actions_outlined,
            label: 'Pendientes ${catalogs?.pendingOfflineAdmissions ?? 0}',
          ),
          _StatusChip(
            icon: Icons.location_city_outlined,
            label: controller.appInformation.nombreCentroServicio,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
