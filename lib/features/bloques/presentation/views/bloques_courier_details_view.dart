import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/bloques_models.dart';
import '../controllers/bloques_flow_controller.dart';
import '../widgets/bloques_widgets.dart';

class BloquesCourierDetailsView extends StatelessWidget {
  const BloquesCourierDetailsView({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onReject,
  });

  final BloquesFlowController controller;
  final VoidCallback onContinue;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final courier = controller.courier;
    if (courier == null) {
      return const BloquesEmptyState(
        icon: Icons.badge_outlined,
        title: 'Sin mensajero',
        message: 'Valida un QR para consultar los datos del domiciliario.',
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 84, 16, 24),
            children: [
              BloquesPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    BloquesCourierAvatar(photoUrl: courier.photoUrl, size: 104),
                    const SizedBox(height: 16),
                    Text(
                      courier.name.isEmpty ? 'Mensajero' : courier.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      courier.document.isEmpty
                          ? 'Documento no disponible'
                          : courier.document,
                      style: const TextStyle(
                        color: AppColors.gray700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.route_outlined,
                          label: courier.routeId.isEmpty
                              ? 'Ruta pendiente'
                              : 'Ruta ${courier.routeId}',
                        ),
                        _InfoPill(
                          icon: Icons.inventory_2_outlined,
                          label: '${courier.guideNumbers.length} guias',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BloquesPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guias del bloque',
                      style: TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (courier.guideNumbers.isEmpty)
                      const Text(
                        'No se recibieron guias para este mensajero.',
                        style: TextStyle(color: AppColors.gray700),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: courier.guideNumbers
                            .map((guide) => Chip(label: Text(guide)))
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.busyRemote ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.busyRemote ? null : onContinue,
                    icon: controller.busyRemote
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BloquesRejectCourierSheet extends StatefulWidget {
  const BloquesRejectCourierSheet({
    super.key,
    required this.controller,
    required this.runAction,
  });

  final BloquesFlowController controller;
  final Future<bool> Function(Future<void> Function() action) runAction;

  @override
  State<BloquesRejectCourierSheet> createState() =>
      _BloquesRejectCourierSheetState();
}

class _BloquesRejectCourierSheetState extends State<BloquesRejectCourierSheet> {
  YaapRejectionReason? _reason;
  final Set<String> _selectedGuides = <String>{};
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReasons());
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.controller.rejectionReasons;
    final courier = widget.controller.courier;
    final requiresGuides = _reason?.requiresGuideSelection ?? false;
    final busy = _submitting || widget.controller.busyRemote;
    return BloquesSheetFrame(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ),
              const Text(
                'Rechazar entrega',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              if (reasons.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<YaapRejectionReason>(
                  initialValue: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Causal de rechazo',
                    border: OutlineInputBorder(),
                  ),
                  items: reasons
                      .map(
                        (reason) => DropdownMenuItem<YaapRejectionReason>(
                          value: reason,
                          child: Text(
                            reason.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: busy
                      ? null
                      : (reason) => setState(() {
                          _reason = reason;
                          _error = null;
                          _selectedGuides.clear();
                        }),
                ),
              if (requiresGuides && courier != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Selecciona las guias que no se pueden transportar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...courier.guideNumbers.map(
                  (guide) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _selectedGuides.contains(guide),
                    onChanged: busy
                        ? null
                        : (checked) => setState(() {
                            if (checked ?? false) {
                              _selectedGuides.add(guide);
                            } else {
                              _selectedGuides.remove(guide);
                            }
                          }),
                    title: Text(guide),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: busy || reasons.isEmpty ? null : _reject,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.block),
                  label: const Text('Confirmar rechazo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadReasons() async {
    final loaded = await widget.runAction(
      widget.controller.loadRejectionReasons,
    );
    if (!mounted) return;
    if (loaded) {
      setState(() {});
    } else {
      setState(() => _error = 'No fue posible cargar las causales.');
    }
  }

  Future<void> _reject() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Selecciona una causal de rechazo.');
      return;
    }
    if (reason.requiresGuideSelection && _selectedGuides.isEmpty) {
      setState(() => _error = 'Selecciona al menos una guia.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final rejected = await widget.runAction(
      () => widget.controller.rejectCourier(
        reason: reason,
        guideNumbers: _selectedGuides.toList(growable: false),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!rejected) return;
    Navigator.of(context).pop(true);
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.gray700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
