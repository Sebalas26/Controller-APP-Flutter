import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/vender_models.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

const _surface = Color(0xFFFEFEFE);
const _border = Color(0xFFE0E0E0);
const _darkMuted = Color(0xFF575757);
const _softWarning = Color(0xFFFFF7E6);
const _warning = Color(0xFFE7A500);

class VenderPickupClosedView extends StatefulWidget {
  const VenderPickupClosedView({
    super.key,
    required this.controller,
    required this.onFinish,
  });

  final VenderFlowController controller;
  final VoidCallback onFinish;

  @override
  State<VenderPickupClosedView> createState() => _VenderPickupClosedViewState();
}

class _VenderPickupClosedViewState extends State<VenderPickupClosedView> {
  late final TextEditingController _phoneController;
  String? _warningMessage;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: _initialPhone());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _initialPhone() {
    final phone =
        widget.controller.collectionState?.guides.first.senderPhone ?? '';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.controller.collectionState;
    if (collection == null) {
      return const Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          child: VenderEmptyState(
            icon: Icons.check_circle_outline,
            title: 'Sin recogida cerrada',
            message: 'No hay un comprobante listo para mostrar.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SuccessIcon(),
                    const SizedBox(height: 24),
                    const Text(
                      'Se generó exitosamente el comprobante',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Compartir comprobante por WhatsApp',
                      style: TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _WhatsappInput(
                      controller: _phoneController,
                      loading: widget.controller.busyRemote,
                      onSend: _sendWhatsapp,
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: widget.controller.busyRemote
                            ? null
                            : _clearPhone,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.black,
                        ),
                        child: const Text(
                          'Enviar a otro celular',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ClosedTotals(collection: collection),
                    if ((_warningMessage ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _WarningBox(message: _warningMessage!),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: _FinishButton(onPressed: widget.onFinish),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsapp() async {
    FocusScope.of(context).unfocus();
    setState(() => _warningMessage = null);
    try {
      await widget.controller.shareInvoiceByWhatsapp(_phoneController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprobante listo para compartir por WhatsApp.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() => _warningMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _clearPhone() {
    _phoneController.clear();
    setState(() => _warningMessage = null);
  }
}

class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.green,
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 68,
          height: 68,
          child: Icon(Icons.check, color: _surface, size: 42),
        ),
      ),
    );
  }
}

class _WhatsappInput extends StatelessWidget {
  const _WhatsappInput({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.chat_outlined, color: AppColors.black),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: _border,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !loading,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      hintText: 'Celular',
                    ),
                    style: const TextStyle(
                      color: _darkMuted,
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: loading ? null : onSend,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 72,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.send_outlined,
                  color: loading ? AppColors.gray500 : AppColors.black,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  loading ? '...' : 'Enviar',
                  style: TextStyle(
                    color: loading ? AppColors.gray500 : AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _ClosedTotals extends StatelessWidget {
  const _ClosedTotals({required this.collection});

  final VenderCollectionState collection;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Envíos\nrecogidos',
            value: collection.guideCount.toString(),
          ),
        ),
        Expanded(
          child: _MetricTile(
            label: 'Valor\na cobrar',
            value: _money(collection.totalToCharge),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _softWarning,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _warning.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: _warning, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishButton extends StatelessWidget {
  const _FinishButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black,
      elevation: 8,
      shadowColor: _darkMuted.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          height: 48,
          child: Center(
            child: Text(
              'Finalizar',
              style: TextStyle(
                color: _surface,
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
  return '\$ ${buffer.toString()}';
}
