import 'package:flutter/material.dart';

import '../../impresion/impresion.dart';
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
    final state = controller.admissionSuccessState;
    if (state == null) {
      return const VenderEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Sin guia admitida',
        message: 'No hay una admision sincronizada para mostrar.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 74, color: Color(0xFF11A35C)),
        const SizedBox(height: 18),
        const Text(
          'Envio admitido con exito',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Text(
          state.message.trim().isEmpty
              ? 'La guia fue creada correctamente.'
              : state.message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF696F79),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 22),
        _GuideNumberBlock(number: state.supplyNumber),
        const SizedBox(height: 18),
        _SuccessInfoLine('Guia', state.guide.guideNumber),
        _SuccessInfoLine('Recogida', state.guide.idPickup.toString()),
        _SuccessInfoLine('Prefactura', state.guide.idPreInvoice.toString()),
        const SizedBox(height: 22),
        const Text(
          'Desea agregar un nuevo envio',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            const _SuccessAction(
              icon: Icons.add_box_outlined,
              label: 'Si, agregar',
              enabled: false,
            ),
            _SuccessAction(
              icon: Icons.print_outlined,
              label: 'Imprimir',
              enabled: true,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        VenderPrintPage(guideNumber: state.guide.guideNumber),
                  ),
                );
              },
            ),
            const _SuccessAction(
              icon: Icons.block_outlined,
              label: 'Anular',
              enabled: false,
            ),
            _SuccessAction(
              icon: Icons.receipt_long_outlined,
              label: 'No',
              enabled: true,
              onPressed: () =>
                  runAction(() async => controller.goToBillingSummary()),
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideNumberBlock extends StatelessWidget {
  const _GuideNumberBlock({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          children: [
            const Text(
              'Suministro usado',
              style: TextStyle(
                color: Color(0xFF696F79),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              number.trim().isEmpty ? '-' : number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessAction extends StatelessWidget {
  const _SuccessAction({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final background = enabled ? const Color(0xFF212529) : Colors.white;
    final foreground = enabled ? Colors.white : const Color(0xFF696F79);
    return SizedBox(
      width: 156,
      height: 62,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: enabled ? const Color(0xFF212529) : const Color(0xFFE1E6EF),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!enabled)
                        const Text(
                          'No disponible',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF9AA1AA),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessInfoLine extends StatelessWidget {
  const _SuccessInfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 112,
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
              value.trim().isEmpty || value == '0' ? '-' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
