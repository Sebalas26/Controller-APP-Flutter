import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../anular_guia/anular_guia.dart';
import '../../impresion/impresion.dart';
import '../../models/vender_models.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

class VenderAdmissionSuccessView extends StatelessWidget {
  const VenderAdmissionSuccessView({
    super.key,
    required this.controller,
    required this.runAction,
  });

  final VenderFlowController controller;
  final Future<void> Function(Future<void> Function()) runAction;

  @override
  Widget build(BuildContext context) {
    final guides = controller.collectionState?.guides ?? const [];
    if (guides.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFFEFEFE),
        body: SafeArea(
          child: VenderEmptyState(
            icon: Icons.check_circle_outline,
            title: 'Sin guia admitida',
            message: 'No hay una admision sincronizada para mostrar.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final buttonGap = guides.length == 1
                ? (constraints.maxHeight - 376).clamp(24.0, 260.0).toDouble()
                : 24.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 52,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SuccessToast(),
                    const SizedBox(height: 24),
                    ...guides.map(
                      (guide) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AdmittedGuideCard(
                          controller: controller,
                          guide: guide,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(height: buttonGap),
                    _SuccessButton(
                      label: 'Continuar',
                      filled: true,
                      onPressed: () => runAction(
                        () async => controller.goToBillingSummary(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SuccessButton(
                      label: 'Agregar otro envío',
                      filled: false,
                      onPressed: () => runAction(
                        () async => controller.resetForAdditionalAdmission(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuccessToast extends StatelessWidget {
  const _SuccessToast();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          bottomLeft: Radius.circular(3),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: const Border(
          left: BorderSide(color: AppColors.green, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF575757).withValues(alpha: 0.15),
            offset: const Offset(-4, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  'Envío admitido con éxito.',
                  style: TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdmittedGuideCard extends StatelessWidget {
  const _AdmittedGuideCard({required this.controller, required this.guide});

  final VenderFlowController controller;
  final VenderCollectionGuide guide;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF575757).withValues(alpha: 0.15),
            offset: const Offset(-2, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    guide.guideNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyGuide(context, guide.guideNumber),
                  tooltip: 'Copiar guía',
                  icon: const Icon(
                    Icons.copy_outlined,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            VenderPrintPage(guideNumber: guide.guideNumber),
                      ),
                    );
                  },
                  tooltip: 'Imprimir',
                  icon: const Icon(
                    Icons.print_outlined,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _destinationTitle(guide),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF727272),
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _detailText(guide),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF727272),
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    guide.paymentMethodLabel.trim().isEmpty
                        ? 'Forma de pago'
                        : guide.paymentMethodLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF727272),
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  r'$',
                  style: TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                  ),
                ),
                Expanded(
                  child: Text(
                    _money(guide.shouldChargeNow ? guide.totalValue : 0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AnularGuiaPage(
                        appInformation: controller.appInformation,
                        apiConfig: controller.apiConfig,
                        offline: controller.offline,
                        initialGuideNumber: guide.guideNumber,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.accent,
                ),
                child: const Text(
                  'Anular guía',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _destinationTitle(VenderCollectionGuide guide) {
    final text = guide.destinationCity.trim();
    if (text.isNotEmpty) return text;
    return 'Guía admitida';
  }

  String _detailText(VenderCollectionGuide guide) {
    final address = guide.recipientAddress.trim();
    if (address.isNotEmpty) return address;
    final recipientName = guide.recipientName.trim();
    if (recipientName.isNotEmpty) return recipientName;
    return 'Destinatario sin nombre';
  }

  Future<void> _copyGuide(BuildContext context, String guideNumber) async {
    await Clipboard.setData(ClipboardData(text: guideNumber));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Guía $guideNumber copiada.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SuccessButton extends StatelessWidget {
  const _SuccessButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.black : const Color(0xFFFEFEFE),
      elevation: 8,
      shadowColor: const Color(0xFF575757).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: filled ? const Color(0xFFFEFEFE) : AppColors.black,
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
  return buffer.toString();
}
