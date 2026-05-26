import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/bloques_models.dart';
import '../controllers/bloques_flow_controller.dart';

const _warning = Color(0xFFD89A00);
const _softRed = Color(0xFFFFECEC);
const _softGreen = Color(0xFFE7F5EC);

class BloquesTopBar extends StatelessWidget {
  const BloquesTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onFilter,
    required this.filterActive,
    required this.showFilter,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onFilter;
  final bool filterActive;
  final bool showFilter;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.white),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Atras',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showFilter)
                IconButton(
                  tooltip: filterActive ? 'Ver pendientes' : 'Ver gestionados',
                  onPressed: onFilter,
                  color: filterActive ? AppColors.green : AppColors.accent,
                  icon: const Icon(Icons.filter_list),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class BloquesStatusBanner extends StatelessWidget {
  const BloquesStatusBanner({super.key, required this.controller});

  final BloquesFlowController controller;

  @override
  Widget build(BuildContext context) {
    final error = controller.errorMessage;
    final message = error ?? controller.statusMessage;
    if (message.trim().isEmpty && !controller.busyRemote) {
      return const SizedBox.shrink();
    }
    final success = error == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: success ? _softGreen : _softRed,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: success ? AppColors.green : AppColors.red),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (controller.busyRemote)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? AppColors.green : AppColors.red,
                size: 20,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: success ? AppColors.green : AppColors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BloquesCentralMessage extends StatelessWidget {
  const BloquesCentralMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Escanea el QR o ingresa el codigo para gestionar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gray700,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'tus entregas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gray700,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BloquesListHeader extends StatelessWidget {
  const BloquesListHeader({
    super.key,
    required this.title,
    required this.lastUpdateLabel,
  });

  final String title;
  final String lastUpdateLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lastUpdateLabel,
            style: const TextStyle(color: AppColors.gray700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class BloquesPendingBlockCard extends StatelessWidget {
  const BloquesPendingBlockCard({
    super.key,
    required this.block,
    required this.busy,
    required this.onTap,
  });

  final YaapPendingBlock block;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (tick) => tick),
      builder: (context, snapshot) {
        final presentation = _statusPresentation(block);
        final waiting = presentation.remaining > Duration.zero;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Material(
            color: waiting ? AppColors.gray100 : AppColors.white,
            elevation: presentation.elevated ? 5 : 0,
            shadowColor: AppColors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: busy ? null : onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: presentation.closed
                        ? AppColors.gray300
                        : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BloquesCourierAvatar(photoUrl: block.photoUrl, size: 72),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            block.courierName.isEmpty
                                ? 'Mensajero sin nombre'
                                : block.courierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _BlockTextLine(
                            label: 'Numero de bloque: ',
                            value: '# ${_blockGuide(block)}',
                          ),
                          const SizedBox(height: 3),
                          _BlockTextLine(
                            label: 'Documento: ',
                            value: block.courierDocument.isEmpty
                                ? 'Sin documento'
                                : block.courierDocument,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            presentation.label,
                            style: TextStyle(
                              color: presentation.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          if (waiting) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Se desbloquea en ${_formatRemaining(presentation.remaining)} minutos',
                              style: const TextStyle(
                                color: AppColors.gray700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BloquesBottomActionBar extends StatelessWidget {
  const BloquesBottomActionBar({
    super.key,
    required this.busy,
    required this.onManage,
  });

  final bool busy;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.12),
            offset: const Offset(0, -3),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: busy ? null : onManage,
              child: const Text(
                'Gestionar entrega',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BloquesSyncFab extends StatelessWidget {
  const BloquesSyncFab({
    super.key,
    required this.syncing,
    required this.onPressed,
  });

  final bool syncing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (syncing)
            const SizedBox(
              width: 62,
              height: 62,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: 'bloques-sync',
              elevation: 4,
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.accent,
              onPressed: syncing ? null : onPressed,
              child: const Icon(Icons.sync),
            ),
          ),
        ],
      ),
    );
  }
}

class BloquesMethodSheet extends StatelessWidget {
  const BloquesMethodSheet({
    super.key,
    required this.onClose,
    required this.onQr,
    required this.onCode,
  });

  final VoidCallback onClose;
  final VoidCallback onQr;
  final VoidCallback onCode;

  @override
  Widget build(BuildContext context) {
    return BloquesSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona el metodo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear QR'),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.white,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onCode,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Ingresar codigo',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class BloquesCodeSheet extends StatefulWidget {
  const BloquesCodeSheet({
    super.key,
    required this.onClose,
    required this.onQr,
    required this.onValidate,
  });

  final VoidCallback onClose;
  final VoidCallback onQr;
  final Future<bool> Function(String document, String code) onValidate;

  @override
  State<BloquesCodeSheet> createState() => _BloquesCodeSheetState();
}

class _BloquesCodeSheetState extends State<BloquesCodeSheet> {
  final _codeController = TextEditingController();
  final _documentController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _validating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController
      ..removeListener(_onCodeChanged)
      ..dispose();
    _documentController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BloquesSheetFrame(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Cerrar',
                onPressed: _validating ? null : widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ),
            const Text(
              'Ingresa el codigo del mensajero',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _codeFocusNode.requestFocus(),
              child: _PinBoxes(value: _codeController.text),
            ),
            SizedBox(
              height: 1,
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Numero de identificacion',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _documentController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'Documento'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _softRed,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.red),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'La validacion puede tardar unos segundos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray700, fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _validating ? null : _validate,
                child: _validating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Validar'),
              ),
            ),
            TextButton(
              onPressed: _validating ? null : widget.onQr,
              child: const Text('Cambiar a codigo QR'),
            ),
          ],
        ),
      ),
    );
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _validate() async {
    final code = _codeController.text.trim();
    final document = _documentController.text.trim();
    if (code.length < 4 || document.isEmpty) {
      setState(() {
        _error = 'Ingresa el codigo y el numero de identificacion.';
      });
      return;
    }
    setState(() {
      _validating = true;
      _error = null;
    });
    final validated = await widget.onValidate(document, code);
    if (!mounted) return;
    setState(() {
      _validating = false;
      _error = validated ? null : 'No fue posible validar la informacion.';
    });
  }
}

class BloquesValidationOverlay extends StatelessWidget {
  const BloquesValidationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.black.withValues(alpha: 0.35),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              elevation: 8,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(18, 20, 18, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.green, size: 56),
                    SizedBox(height: 12),
                    Text(
                      'Validacion exitosa',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ahora puedes continuar con la gestion de entregas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BloquesSheetFrame extends StatelessWidget {
  const BloquesSheetFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

class BloquesPanel extends StatelessWidget {
  const BloquesPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class BloquesEmptyState extends StatelessWidget {
  const BloquesEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return BloquesPanel(
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.gray700),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray700),
          ),
        ],
      ),
    );
  }
}

class BloquesCourierSummary extends StatelessWidget {
  const BloquesCourierSummary({super.key, required this.courier});

  final YaapCourier courier;

  @override
  Widget build(BuildContext context) {
    return BloquesPanel(
      child: Row(
        children: [
          BloquesCourierAvatar(photoUrl: courier.photoUrl, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courier.name.isEmpty ? 'Mensajero' : courier.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  courier.document,
                  style: const TextStyle(color: AppColors.gray700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.route_outlined,
                      label: courier.routeId.isEmpty
                          ? 'Sin ruta'
                          : courier.routeId,
                    ),
                    _InfoChip(
                      icon: Icons.local_shipping_outlined,
                      label: '${courier.guideNumbers.length} guias',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BloquesDeliveryTile extends StatelessWidget {
  const BloquesDeliveryTile({
    super.key,
    required this.delivery,
    required this.onToggleVerified,
  });

  final YaapDelivery delivery;
  final VoidCallback onToggleVerified;

  @override
  Widget build(BuildContext context) {
    return BloquesPanel(
      child: Row(
        children: [
          Checkbox(
            value: delivery.verified,
            onChanged: (_) => onToggleVerified(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.guideNumber,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  delivery.locationDetail.isEmpty
                      ? 'Ubicacion ${delivery.location}'
                      : delivery.locationDetail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.gray700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.scale_outlined,
                      label: '${delivery.weight.toStringAsFixed(1)} kg',
                    ),
                    _InfoChip(
                      icon: Icons.flag_outlined,
                      label: 'Estado ${delivery.stateId}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BloquesPendingBlockTile extends StatelessWidget {
  const BloquesPendingBlockTile({
    super.key,
    required this.block,
    required this.busy,
    required this.onValidate,
    required this.onAssign,
  });

  final YaapPendingBlock block;
  final bool busy;
  final VoidCallback onValidate;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return BloquesPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BloquesCourierAvatar(photoUrl: block.photoUrl, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '# ${_blockGuide(block)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      block.courierName.isEmpty
                          ? block.courierDocument
                          : block.courierName,
                      style: const TextStyle(color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.local_shipping_outlined,
                label: '${block.guideNumbers.length} guias',
              ),
              _InfoChip(
                icon: Icons.person_outline,
                label: block.assignedUser.isEmpty
                    ? 'Sin usuario'
                    : block.assignedUser,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onValidate,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Validar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onAssign,
                  icon: const Icon(Icons.assignment_ind_outlined),
                  label: const Text('Asignar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BloquesCourierAvatar extends StatelessWidget {
  const BloquesCourierAvatar({
    super.key,
    required this.photoUrl,
    required this.size,
  });

  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl.trim().isEmpty
            ? const ColoredBox(
                color: AppColors.gray200,
                child: Icon(Icons.person_outline),
              )
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.gray200,
                  child: Icon(Icons.person_outline),
                ),
              ),
      ),
    );
  }
}

class _PinBoxes extends StatelessWidget {
  const _PinBoxes({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final digit = index < value.length ? value[index] : '';
        return Container(
          width: 52,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: digit.isEmpty ? AppColors.gray300 : AppColors.accent,
              width: digit.isEmpty ? 1 : 2,
            ),
          ),
          child: Text(
            digit,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        );
      }),
    );
  }
}

class _BlockTextLine extends StatelessWidget {
  const _BlockTextLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(color: AppColors.black, fontSize: 12),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.blue8,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BlockStatusPresentation {
  const _BlockStatusPresentation({
    required this.label,
    required this.color,
    required this.remaining,
    required this.closed,
    required this.elevated,
  });

  final String label;
  final Color color;
  final Duration remaining;
  final bool closed;
  final bool elevated;
}

_BlockStatusPresentation _statusPresentation(YaapPendingBlock block) {
  final closed = _isClosed(block);
  final remaining = closed ? Duration.zero : _remainingWait(block);
  if (closed) {
    return const _BlockStatusPresentation(
      label: 'Cerrado',
      color: AppColors.green,
      remaining: Duration.zero,
      closed: true,
      elevated: false,
    );
  }
  if (remaining > Duration.zero) {
    return _BlockStatusPresentation(
      label: 'En espera',
      color: AppColors.accent,
      remaining: remaining,
      closed: false,
      elevated: false,
    );
  }
  return const _BlockStatusPresentation(
    label: 'Pendiente',
    color: _warning,
    remaining: Duration.zero,
    closed: false,
    elevated: true,
  );
}

Duration _remainingWait(YaapPendingBlock block) {
  final createdAt = block.createdAt;
  if (createdAt == null) return Duration.zero;
  final remaining = createdAt
      .add(const Duration(minutes: 5))
      .difference(DateTime.now());
  return remaining.isNegative ? Duration.zero : remaining;
}

bool _isClosed(YaapPendingBlock block) {
  if (block.endsAt != null) return true;
  final status = block.status.toLowerCase();
  return status.contains('cerrado') ||
      status.contains('closed') ||
      status.contains('gestionado');
}

String _formatRemaining(Duration remaining) {
  final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _blockGuide(YaapPendingBlock block) {
  if (block.motherGuideNumber.isNotEmpty) return block.motherGuideNumber;
  if (block.id > 0) return block.id.toString();
  return 'Sin numero';
}
