import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/anular_guia_models.dart';
import 'controllers/anular_guia_controller.dart';

const _surface = Color(0xFFFEFEFE);
const _border = Color(0xFFE0E0E0);
const _muted = Color(0xFF727272);
const _blue = Color(0xFF2569B3);
const _softBlue = Color(0xFFE8EFF7);

class AnularGuiaPage extends StatefulWidget {
  const AnularGuiaPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<AnularGuiaPage> createState() => _AnularGuiaPageState();
}

class _AnularGuiaPageState extends State<AnularGuiaPage> {
  late final AnularGuiaController _controller;
  String? _lastShownMessage;
  AnularGuideResult? _lastShownResult;

  @override
  void initState() {
    super.initState();
    _controller = AnularGuiaController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_handleControllerEvents);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerEvents)
      ..dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (_controller.step == AnularGuiaStep.informacion) {
      Navigator.of(context).maybePop();
      return;
    }
    _controller.back();
  }

  void _handleControllerEvents() {
    final result = _controller.cancellationResult;
    if (mounted && result != null && result != _lastShownResult) {
      _lastShownResult = result;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResultDialog());
    }

    final message = _controller.errorMessage ?? _controller.statusMessage;
    if (!mounted || message == null || message == _lastShownMessage) return;
    _lastShownMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isError = _controller.errorMessage == message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.red : AppColors.green,
          duration: Duration(seconds: isError ? 5 : 4),
        ),
      );
    });
  }

  Future<void> _showResultDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Anulación exitosa'),
        content: Text(
          _controller.cancellationResult?.mensaje.trim().isEmpty ?? true
              ? 'La guía fue anulada correctamente.'
              : _controller.cancellationResult!.mensaje.trim(),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).maybePop();
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        elevation: 0,
        leading: IconButton(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          tooltip: 'Atras',
        ),
        title: const Text(
          'Anular Guía',
          style: TextStyle(
            color: _blue,
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                child: _BodyForStep(controller: _controller),
              ),
              if (_controller.loading ||
                  _controller.sendingCode ||
                  _controller.cancelling)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BodyForStep extends StatelessWidget {
  const _BodyForStep({required this.controller});

  final AnularGuiaController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.step) {
      case AnularGuiaStep.informacion:
        return _InfoStep(controller: controller);
      case AnularGuiaStep.guia:
        return _GuideStep(controller: controller);
      case AnularGuiaStep.confirmarNumero:
        return _ConfirmPhoneStep(controller: controller);
      case AnularGuiaStep.cambiarNumero:
        return _ChangePhoneStep(controller: controller);
      case AnularGuiaStep.confirmarCodigo:
        return _OtpStep(controller: controller);
    }
  }
}

class _InfoStep extends StatelessWidget {
  const _InfoStep({required this.controller});

  final AnularGuiaController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          icon: Icons.info_outline,
          title: 'Antes de anular tenga en cuenta que:',
        ),
        const SizedBox(height: 14),
        const _InfoCard(
          children: [
            _BulletText('El envío debe pertenecer a su canal de venta.'),
            _BulletText(
              'Debe realizar la anulación durante el día de admisión.',
            ),
            _BulletText(
              'Esta acción no se podrá deshacer y tendrá una afectación de caja.',
            ),
          ],
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Continuar',
          icon: Icons.arrow_forward,
          onPressed: controller.continueFromInfo,
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          label: 'Cancelar',
          icon: Icons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.controller});

  final AnularGuiaController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(icon: Icons.cancel_outlined, title: 'Guía a anular'),
        const SizedBox(height: 14),
        TextField(
          controller: controller.guiaController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => controller.guideInputChanged(),
          decoration: InputDecoration(
            labelText: 'Número guía',
            suffixIcon: IconButton(
              onPressed: controller.canConsultGuide
                  ? controller.consultGuide
                  : null,
              icon: Icon(
                controller.guiaController.text.trim().isEmpty
                    ? Icons.qr_code_scanner
                    : Icons.search,
              ),
              tooltip: controller.guiaController.text.trim().isEmpty
                  ? 'Escanear'
                  : 'Buscar',
            ),
          ),
          onSubmitted: (_) => controller.consultGuide(),
        ),
        const SizedBox(height: 16),
        if (controller.guide != null) _GuideSummary(guide: controller.guide!),
        const SizedBox(height: 16),
        DropdownButtonFormField<AnulacionReason>(
          key: ValueKey(
            '${controller.guide?.numeroGuia ?? 0}-${controller.selectedReason?.id ?? 0}',
          ),
          initialValue: controller.selectedReason,
          items: controller.reasons
              .map(
                (reason) => DropdownMenuItem(
                  value: reason,
                  child: Text(reason.description),
                ),
              )
              .toList(growable: false),
          onChanged: controller.guide == null ? null : controller.selectReason,
          decoration: const InputDecoration(labelText: 'Motivo de anulación'),
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Continuar',
          icon: Icons.arrow_forward,
          onPressed: controller.canContinueGuide
              ? controller.continueFromGuide
              : null,
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          label: 'Cancelar',
          icon: Icons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _ConfirmPhoneStep extends StatelessWidget {
  const _ConfirmPhoneStep({required this.controller});

  final AnularGuiaController controller;

  @override
  Widget build(BuildContext context) {
    final phone = controller.representativePhone?.phone ?? '';
    final validation = controller.validateRegisteredPhone(phone);
    final helper = validation == true
        ? 'Se enviará un código de verificación a este número.'
        : validation == null
        ? 'No existe un número registrado.'
        : 'El número no corresponde a una línea celular.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(icon: Icons.phone_android, title: 'Confirmar número'),
        const SizedBox(height: 14),
        _InfoCard(
          children: [
            const Text(
              'Número registrado',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              phone.isEmpty ? 'Sin número' : phone,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              helper,
              style: TextStyle(
                color: validation == true ? _muted : AppColors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Continuar',
          icon: Icons.arrow_forward,
          onPressed: controller.canContinueRegisteredPhone
              ? controller.continueWithRegisteredPhone
              : null,
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          label: 'Cambiar número',
          icon: Icons.edit,
          onPressed: controller.goToChangePhone,
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          label: 'Cancelar',
          icon: Icons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _ChangePhoneStep extends StatelessWidget {
  const _ChangePhoneStep({required this.controller});

  final AnularGuiaController controller;

  @override
  Widget build(BuildContext context) {
    final isValid = controller.validateModifiedPhone(
      controller.nuevoNumeroController.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(icon: Icons.edit, title: 'Cambiar número'),
        const SizedBox(height: 14),
        TextField(
          controller: controller.nuevoNumeroController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (_) => controller.newPhoneInputChanged(),
          decoration: InputDecoration(
            labelText: 'Nuevo celular',
            errorText: controller.nuevoNumeroController.text.isEmpty || isValid
                ? null
                : 'Ingresa un celular válido.',
          ),
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: 'Continuar',
          icon: Icons.arrow_forward,
          onPressed: controller.canSaveModifiedPhone
              ? controller.saveModifiedPhone
              : null,
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          label: 'Cancelar',
          icon: Icons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({required this.controller});

  final AnularGuiaController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          icon: Icons.sms_outlined,
          title: 'Confirmar anulación',
        ),
        const SizedBox(height: 14),
        _InfoCard(
          children: [
            Text(
              controller.representativeLegal
                  ? 'Código enviado al representante legal'
                  : 'Código enviado al remitente',
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              controller.currentOtpPhone,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.codigoController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => controller.codeInputChanged(),
          decoration: const InputDecoration(labelText: 'Código'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: controller.resendRemainingSeconds == 0
              ? controller.resendCode
              : null,
          icon: const Icon(Icons.refresh),
          label: Text(
            controller.resendRemainingSeconds == 0
                ? 'Enviar nuevo código'
                : 'Nuevo código en ${_formatSeconds(controller.resendRemainingSeconds)}',
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          label: controller.cancelling ? 'Procesando' : 'Continuar',
          icon: Icons.check,
          onPressed: controller.canConfirmCode
              ? controller.confirmCodeAndCancel
              : null,
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          label: 'Cancelar',
          icon: Icons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _GuideSummary extends StatelessWidget {
  const _GuideSummary({required this.guide});

  final AnularGuide guide;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      children: [
        _LabeledValue(label: 'Guía', value: guide.numeroGuia.toString()),
        _LabeledValue(
          label: 'Remitente',
          value: guide.nombreCompletoRemitente.isEmpty
              ? 'Sin nombre'
              : guide.nombreCompletoRemitente,
        ),
        _LabeledValue(
          label: 'Destinatario',
          value: guide.nombreCompletoDestinatario.isEmpty
              ? 'Sin nombre'
              : guide.nombreCompletoDestinatario,
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _softBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 18, color: _blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

String _formatSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
